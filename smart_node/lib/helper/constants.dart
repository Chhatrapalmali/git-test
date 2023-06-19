import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:aws_common/aws_common.dart';
import 'package:aws_signature_v4/aws_signature_v4.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:smart_node/components/alert_dialog_sheet.dart';
import 'package:smart_node/configuration/http_config.dart';
import 'package:smart_node/configuration/http_handler.dart';
import 'package:smart_node/controllers/auth_controllers/authentication_controller.dart';
import 'package:smart_node/controllers/auth_controllers/otp_controller.dart';
import 'package:smart_node/controllers/home_controllers/floor_and_room_controller.dart';
import 'package:smart_node/controllers/main_navigation_controllers/main_navigation_controller.dart';
import 'package:smart_node/helper/box_names.dart';
import 'package:smart_node/helper/image_url.dart';
import 'package:smart_node/models/api_models/force_app_update_model.dart';
import 'package:smart_node/models/model_channels_16/model_set_top_box_channels.dart';
import 'package:smart_node/models/model_floor_2/model_floor.dart';
import 'package:smart_node/models/model_geo_fencing_17/model_geo_fencing.dart';
import 'package:smart_node/models/model_remotes_8/model_remotes.dart';
import 'package:smart_node/models/model_room_3/model_room.dart';
import 'package:smart_node/models/model_scenes_6/model_scenes.dart';
import 'package:smart_node/models/model_switches_5/model_switches.dart';
import 'package:smart_node/models/model_user_settings_21/model_user_settings.dart';
import 'package:smart_node/models/user_model/user_model.dart';
import 'package:smart_node/screens/authentication_screen/authentication_screen.dart';
import 'package:smart_node/screens/main_navigation_screen/main_navigation_screen.dart';
import 'package:smart_node/services/mqtt_service.dart';
import 'package:store_redirect/store_redirect.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import '../components/app_update_dialog.dart';
import '../configuration/shared_preference_manager.dart';
import '../models/model_device_4/model_device.dart';
import '../services/udp_service.dart';
import 'functions.dart';
import 'toast_messages.dart';

enum LastKnownState {
  inside,
  outside,
  dummy,
}

enum MessageType {
  user,
  bot,
}

class Constants {
  static String UDP_RECEIVE_CHANNEL = "udp_msg_receive";
  static String MQTT_RECEIVE_CHANNEL = "mqtt_msg_receive";
  static String CONNECTIVITY_RESULT = "connectivity_receive";
  static String TCP_RECEIVE_CHANNEL = "tcp_msg_receive";

  // maps
  static var arraySerialCache = <String, int>{}.obs;
  static var arrayIpCache = <String, String>{}.obs;
  static var arrayWifiVer = <String, String>{}.obs;
  static var receivedIp = <String, String>{}.obs;

  // static Map<String, List<String>> newDeviceCommands = new Map();
  static var newCacheMap = <String?, List<dynamic>>{}.obs;
  static var autoOffSwitchMap = <String?, List<int>>{}.obs;
  static Map<String, Socket> tcpSocketMap = {};

  // key = remoteId, value = position of state
  // static Map<String, String> acState = new Map();
  static var isRepeatFunction = false;

  // lists
  static var devicesInLocal = <String>[].obs;
  static var devicesWorking = <String>[].obs;
  static var deviceMainIdsList = <String>[].obs;
  static var deviceOpenIdsList = <String>[].obs;
  static var deviceNamesList = <String>[].obs;
  static var tokenInvalidDeviceList = <String>[].obs;

  static var featureCount = 0;
  static const NFC = 'NFC';
  static const LONG_PRESS = 'LONG_PRESS';
  static const CURTAIN_LONG_PRESS = 'CURTAIN_LONG_PRESS';
  static bool nfcTutorial = false;
  static bool longPressNotAddedDevices = false;
  static bool longPressCurtain = false;

  // list of commands
  static const MST = "MST";
  static const LIN = "LIN";
  static const STS = "STS";
  static const UPD = "UPD";
  static const UID = "UID";
  static const SET = "SET";
  static const SCH = "SCH";
  static const TL1 = "TL1";
  static const UL1 = "UL1";
  static const DM1 = "DM1";
  static const MRN = "MRN";
  static const ONL = "ONL";
  static const INVALID_TOKEN = "token_invalid";
  static const INTERNET = "INTERNET";
  static const NOT_CONNECTED = "0";
  static const CMD_MST = '{"cmd":"MST"}';
  static const PIN = "PIN";
  static const HWF = "HWF";
  static const DLY = "DLY";
  static const DMR = "DMR";
  static const INF = "INF";
  static const RST = "RST";
  static const BUZ = "BUZ";
  static const WFI = "WFI";
  static const SCENE = "000";
  static const SC1 = "SC1";
  static const IRD = "IRD";
  static const IRT = "IRT";
  static const SCA = "SCA";
  static const RGB = "RGB";
  static const TIM = "TIM";
  static const SRG = "SRG";
  static const AO1 = "AO1";
  static const CNF = "CNF";
  static const SCL = "SCL";
  static const CUS = "CUS";
  static const TUN = "TUN";

  static const TIME_UDP_RESEND_CHECK = 0.8;
  static const TIME_MQTT_RESEND_CHECK = 2.5;
  static const TIME_UDP_NORESPOND_CHECK = 2;
  static const TIME_MQTT_NORESPOND_CHECK = 7;
  static const DELAY_RESEND_CMD = 500;

  // static const PORT_TO_SEND_MESSAGE = 13001;
  // static const PORT_TO_RECEIVE_MESSAGE = 13000;
  static late MqttServerClient mqttClient;

  // static var mqttClient;
  static var isSubUser = false;
  static var floorIndex = 0.obs;
  static var isOfficeUser = false;
  static String? userId = '';
  static bool isChangePwdCmdSent = false;
  static bool isProfileTimeCmdSent = false;

  // static String appVersion = '';
  static String clientId = '';
  static var receivedMessage = ''.obs;
  static String defaultString = '!?@#\$%^&*;_-><?!';
  static String googleHomeDeepLink =
      'https://madeby.google.com/home-app/?deeplink=setup/ha_linking?agent_id=smartnode-187d3';
  static String sslCertificate =
      "MIIFNDCCBBygAwIBAgISBCcM7MGBNEQNumItxCceHm7rMA0GCSqGSIb3DQEBCwUAMDIxCzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1MZXQncyBFbmNyeXB0MQswCQYDVQQDEwJSMzAeFw0yMzAzMjkwMzI4MTJaFw0yMzA2MjcwMzI4MTFaMCIxIDAeBgNVBAMTF21xdHRicm9rZXIuc21hcnRub2RlLmluMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAyAaABLGyiEYijgxF91VXsCJuRFPGZEO5AnHrwA8ewA3aJkPftVVv7TSWbKuMoi9+PnCjkFuBZtS+BLnNRCZl0nNpKJdlYZnKOxCAmVR9iZN3UufRsyvoHzuAlQcNgNodCQyuqUbEH/UGajomhxqxfOP+7j9HfEcA065H2AQTSAbMwCVP/fAi/7IuxN8+s0o0comK2vT8Xu0d0+HPpqOM15Zak+XwbpScOVNx7O/28lqZCYxFbMxlSyuh0x7twfxNFhcFq1WbCRApg3WDiByEdEJ6LTDBF0k4hGlN5V2ExFvbaX5nkJdrb92iT/KmWssm5Z6CceZDIfY5e8f91BXPOQIDAQABo4ICUjCCAk4wDgYDVR0PAQH/BAQDAgWgMB0GA1UdJQQWMBQGCCsGAQUFBwMBBggrBgEFBQcDAjAMBgNVHRMBAf8EAjAAMB0GA1UdDgQWBBQS0+abAI+IHlo7+p7eyo3eP8N2OTAfBgNVHSMEGDAWgBQULrMXt1hWy65QCUDmH6+dixTCxjBVBggrBgEFBQcBAQRJMEcwIQYIKwYBBQUHMAGGFWh0dHA6Ly9yMy5vLmxlbmNyLm9yZzAiBggrBgEFBQcwAoYWaHR0cDovL3IzLmkubGVuY3Iub3JnLzAiBgNVHREEGzAZghdtcXR0YnJva2VyLnNtYXJ0bm9kZS5pbjBMBgNVHSAERTBDMAgGBmeBDAECATA3BgsrBgEEAYLfEwEBATAoMCYGCCsGAQUFBwIBFhpodHRwOi8vY3BzLmxldHNlbmNyeXB0Lm9yZzCCAQQGCisGAQQB1nkCBAIEgfUEgfIA8AB1ALc++yTfnE26dfI5xbpY9Gxd/ELPep81xJ4dCYEl7bSZAAABhyufmacAAAQDAEYwRAIgN1iGt6FJoNLQTxlo4w1+whzcz1c4dwS5EkgKKX9AdcECIEogvmjJLrp4SHoqf9SC6wSw4VpL7eD+c5Ju8ym6UPusAHcArfe++nz/EMiLnT2cHj4YarRnKV3PsQwkyoWGNOvcgooAAAGHK5+Z1gAABAMASDBGAiEAnOJkQZiePbzQSGKwopzM9SL6bwI6KCCP6NL5/oHBZPMCIQCNrjHhtS3KSr7R5j3OH4XiiIw6sZGM/1b1qw+zMov5DDANBgkqhkiG9w0BAQsFAAOCAQEABh1pHy4l6+nFeLcJLb2U9QgQFv2ncOG1neBrTvrAoyTTZm2RFBeut70y2NGqT4a75H+SB98dT8y2LVlA/6NvqEBsf6uUx1lJqSUOKFauXmqLVqGPigvmFL15Wl9uxFrfQglZxCz33KmzYjdUVTwwH/Xu/T/HzlsbaKz351+95pPGiHNTyjUlwRY66wzlyi0HmUc19DS1iLshbktrAclZnTORXSwK4w5BG8/H8KgtEHITkqL3eqBHTtdFFhd8NR2ZK715SXBDvr0BD/MHN8ujJ/qh8CTvjBIO97qS6bzzR/RflWqClTYDVpXzeDTuXu6YToEvsZSdEzEifUb5qnVPxQ==";

  //8.1.3 & 4.1.2 Dimmer Value for 5 step
  static const step_0 = 0;
  static const step_1 = 39;
  static const step_2 = 45;
  static const step_3 = 55;
  static const step_4 = 60;

  // 8.2.0 & 4.2.0 Dimmer Value for 5 step
  static const new_step_1 = 20;
  static const new_step_2 = 40;
  static const new_step_3 = 60;
  static const new_step_4 = 80;
  static const step_5 = 100;

  static const tcpVersion = 8;
  static const timerStop = 20;
  static var hwVer_below_2k20 = ['8.1.3', '4.1.2'];
  static var hwVer_2k21 = ['8.2.0', '4.2.0', '2.2.0', '4.S.0', '10.0.0'];

  static var smallAlphabetArray = [
    "dummy",
    "a",
    "b",
    "c",
    "d",
    "e",
    "f",
    "g",
    "h",
    "i",
    "j",
    "k",
    "l",
    "m",
    "n",
    "o",
    "p",
    "q",
    "r",
    "s",
    "t",
    "u",
    "v",
    "w",
    "x",
    "y"
  ];

  static var dimmerArray = [
    "dummy",
    "aa",
    "ab",
    "ac",
    "ad",
    "ae",
    "af",
    "ag",
    "ah",
    "ai",
    "aj",
    "ak",
    "al",
    "am",
    "an",
    "ao",
    "ap",
    "aq",
    "ar",
    "as",
    "at",
    "au",
    "av",
    "aw",
    "ax",
    "ay",
    "az",
    "ba",
    "bb",
    "bc",
    "bd",
    "be",
    "bf",
    "bg",
    "bh",
    "bi",
    "bj",
    "bk",
    "bl",
    "bm",
    "bn",
    "bo",
    "bp",
    "bq",
    "br",
    "bs",
    "bt",
    "bu",
    "bv",
    "bw",
    "bx",
    "by",
    "bz",
    "ca",
    "cb",
    "cc",
    "cd",
    "ce",
    "cf",
    "cg",
    "ch",
    "ci",
    "cj",
    "ck",
    "cl",
    "cm",
    "cn",
    "co",
    "cp",
    "cq",
    "cr",
    "cs",
    "ct",
    "cu",
    "cv",
    "cw",
    "cx",
    "cy",
    "cz",
    "da",
    "db",
    "dc",
    "dd",
    "de",
    "df",
    "dg",
    "dh",
    "di",
    "dj",
    "dk",
    "dl",
    "dm",
    "dn",
    "do",
    "dp",
    "dq",
    "dr",
    "ds",
    "dt",
    "du",
    "dv",
  ];

  static List<String> oldIrVersion = ['I.0.0', 'I.2.0'];
  static String imageToBase64(Uint8List data) => base64Encode(data);
  static Image imageFromBase64(String base) {
    debugPrint('base $base');
    if (base.length % 4 > 0) {
      base += '=' * (4 - base.length % 4);
    }
    return Image.memory(
      base64Decode(base),
    );
  }

  String privacyPolicyUrl() => 'https://smartnode.in/privacy-policy/';





  Future<bool> checkTutorialStatus({required String checkString}) async {
    bool isCompleteTutorial = false;

    List<String> tutorialList = SharedPreferenceManager.getTutorialList();
    if (tutorialList.contains(checkString)) {
      isCompleteTutorial = true;
    } else {
      tutorialList.add(checkString);
      SharedPreferenceManager.setTutorialList(tutorialList);
      isCompleteTutorial = false;
    }
    return isCompleteTutorial;
  }

  TargetFocus createTutorialFocus(
      {required GlobalKey key,
      ContentAlign? alignment,
      ShapeLightFocus? shape,
      bool? dismiss,
      String? title,
      String? description}) {
    return TargetFocus(
      keyTarget: key,
      color: Colors.teal,
      enableTargetTab: true,
      enableOverlayTab: dismiss ?? true,
      shape: shape ?? ShapeLightFocus.Circle,
      radius: 60,
      contents: [
        TargetContent(
          align: alignment ?? ContentAlign.bottom,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              title != null
                  ? Text(
                      title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 20.0),
                    )
                  : Container(),
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: description != null
                    ? Text(
                        description,
                        style: const TextStyle(color: Colors.white),
                      )
                    : Container(),
              )
            ],
          ),
        ),
      ],
    );
  }

  static bool isConnectedToBroker() {
    bool isConnected = false;
    if (mqttClient.connectionStatus != null) {
      isConnected =
          mqttClient.connectionStatus!.state == MqttConnectionState.connected;
    }
    return isConnected;
  }

  static Future<bool> isConnected() async {
    bool isConnected;
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      isConnected = false;
    } else {
      isConnected = true;
    }

    return isConnected;
  }

  static sendSTSAndRgbCommandToAllDevice() async {
    var deviceBox = Hive.box<ModelDevice>(devices);
    Box<UserModel> userBox = Hive.box(userTable);
    for (int i = 0; i < deviceBox.length; i++) {
      Map<String, dynamic> cmdToSend = {};
      if (deviceBox.getAt(i)!.hardwareType!.startsWith('rgb')) {
        cmdToSend['cmd'] = Constants.RGB;
      } else {
        cmdToSend['cmd'] = Constants.STS;
      }

      cmdToSend['slave'] = deviceBox.getAt(i)!.mainId;
      cmdToSend['token'] = deviceBox.getAt(i)!.token;
      String byUser =  'M_${userBox.getAt(0)!.firstName} ${userBox.getAt(0)!.lastName}';
      cmdToSend['by'] = byUser;
      String cmd = jsonEncode(cmdToSend);

      UDPService().sendUDPMessage(ip: 'BroadcastIP', message: cmd);
      MQTTService()
          .publish(deviceMainId: deviceBox.getAt(i)!.mainId!, message: cmd);
    }
  }

  static setAllDeviceOffline() {
    devicesInLocal.clear();
    devicesWorking.clear();
    newCacheMap.clear();
    arraySerialCache.clear();
    arrayIpCache.clear();
    newCacheMap.refresh();
  }

  // static Future<bool> isInternetConnection() async {
  //   bool result = await InternetConnectionChecker().hasConnection;
  //   debugPrint('isWifiHasInternetConnection: $result');
  //   return result;
  // }

  static Future<bool> isWifiHasInternet() async {
    bool isConnected = false;
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        debugPrint('connected: $result');
        isConnected = true;
      }
    } on SocketException catch (_) {
      isConnected = false;
    }

    return isConnected;
  }

  static dm1Received(Map<String, dynamic> jsonResponse) {
    Box<ModelDevice> deviceBox = Hive.box(devices);
    Box<ModelSwitches> switchesBox = Hive.box(switches);

    String? deviceMainId = jsonResponse['slave'];
    String? status = jsonResponse['status'];

    if (status == 'success') {
      debugPrint('DM1Response: $jsonResponse');
      String? data = jsonResponse['data'];
      List<dynamic>? oneDeviceSwitchData = newCacheMap[deviceMainId];
      if (oneDeviceSwitchData != null && oneDeviceSwitchData.isNotEmpty) {
        int indexOfOperation = int.parse(data!.substring(0, 2)) - 1;
        Map<String, dynamic> targetedSwitchMap =
            oneDeviceSwitchData[indexOfOperation];
        String dimValue;
        var deviceId = '', hardwareVersion = '';
        deviceBox.values
            .where((element) => element.mainId == deviceMainId)
            .forEach((element) {
          deviceId = element.deviceId!;
          hardwareVersion = element.hardwareVersion!;
        });
        //data = 01Y
        if (data.substring(2) == 'N') {
          // switch is not dimmer
          dimValue = "XX";
        } else {
          // switch is light dimmer or fan dimmer
          // dimmer data can be F or Y for 2k21 hardware list (Y= light dimmer, F= fan dimmer)
          if (hwVer_below_2k20.contains(hardwareVersion)) {
            dimValue = "ay";
          } else if (hwVer_2k21.contains(hardwareVersion)) {
            dimValue = "dv";
          } else {
            dimValue = "ae";
          }
        }

        // 01ANNbmXXXXXX
        targetedSwitchMap['dimmer'] = dimValue;

        //-----------
        // Update Scene lighting switches
        //-----------
        String btnNumber = data.substring(0, 2);
        String dimmerStatus = data.substring(2);
        //update newSwitchList data cache
        for (int i = 0; i < switchesBox.length; i++) {
          ModelSwitches modelSwitches = switchesBox.getAt(i)!;
          if (modelSwitches.deviceMainId == deviceId &&
              modelSwitches.buttonNumber == btnNumber) {
            if (hwVer_below_2k20.contains(hardwareVersion)) {
              if (modelSwitches.buttonNumber == '01') {
                // 8.1.3 or 4.1.2
                if (dimmerStatus == 'Y') {
                  modelSwitches.switchType = 'ae';
                  modelSwitches.dimmerType = 'F';
                } else {
                  modelSwitches.switchType = 'XX';
                  modelSwitches.dimmerType = 'N';
                }
              } else {
                // 8.1.3 or 4.1.2
                if (dimmerStatus == 'Y') {
                  modelSwitches.switchType = 'ay';
                  modelSwitches.dimmerType = 'L';
                } else {
                  modelSwitches.switchType = 'XX';
                  modelSwitches.dimmerType = 'N';
                }
              }
              // 8.1.3 or 4.1.2
              // if (dimmerStatus == 'Y') {
              //   modelSwitches.switchType = 'ay';
              //   modelSwitches.dimmerType = 'L';
              // } else {
              //   modelSwitches.switchType = 'XX';
              //   modelSwitches.dimmerType = 'N';
              // }
            } else if (hwVer_2k21.contains(hardwareVersion)) {
              if (dimmerStatus == 'Y') {
                // light
                modelSwitches.switchType = 'dv';
                modelSwitches.dimmerType = 'L';
              } else if (dimmerStatus == 'F') {
                // fan
                modelSwitches.switchType = 'ae';
                modelSwitches.dimmerType = 'F';
              } else {
                modelSwitches.switchType = 'XX';
                modelSwitches.dimmerType = 'N';
              }
            } else {
              if (dimmerStatus == 'Y') {
                // fan
                modelSwitches.switchType = 'ae';
                modelSwitches.dimmerType = 'F';
              } else {
                modelSwitches.switchType = 'XX';
                modelSwitches.dimmerType = 'N';
              }
            }
            switchesBox.putAt(i, modelSwitches);
            // updateDimmerTypeAPI(modelSwitches);
          }
        }

        //-----------END-----------
      }
    }
  }

  static schReceived(Map<String, dynamic> jsonResponse) {
    String? deviceMainId = jsonResponse['slave']; // slave = 2018010915202508
    var schReturnData = jsonResponse['data'];
    // data = I-24-18:25-NNNNYNN-N-5-1-02 get this response when we create schedule
    var schItems;
    //schItems: [I, 24, 18:25, NNNNYNN, N, 5, 1, 02]

    Box<ModelDevice> deviceBox = Hive.box(devices);
    String hardwareType = deviceBox.values
            .where((element) => element.mainId == deviceMainId)
            .first
            .hardwareType ??
        '';
    String hardwareVersion = deviceBox.values
            .where((element) => element.mainId == deviceMainId)
            .first
            .hardwareVersion ??
        '';
    // this cmd is not for ir so not included
    if (!hardwareVersion.startsWith('R.1')) {
      schItems = schReturnData.split("-");
    }
    if (hardwareVersion.startsWith('R.1')) {
      if (jsonResponse["sub_cmd"] == RGB) {
        List<dynamic>? oneDeviceSwitchData = newCacheMap[deviceMainId];
        if (oneDeviceSwitchData != null && oneDeviceSwitchData.isNotEmpty) {
          var schedules = jsonResponse['schedules'];
          Map<String, dynamic> rgbMap = oneDeviceSwitchData[0];
          if (schedules > 0) {
            rgbMap['schedule'] = 'Y';
          } else {
            rgbMap['schedule'] = 'N';
          }
        }
      }
    } else if ((hardwareType == 'standalone') ||
        (hardwareType == 'curtain') ||
        (hardwareType == 'doorLock')) {
      //noinspection StatementWithEmptyBody
      if (schItems[0] == 'ERR') {
      } else if (schItems[2] == 'EMPTY') {
        // new_logic
        List<dynamic>? oneDeviceSwitchData = newCacheMap[deviceMainId];
        if (oneDeviceSwitchData != null && oneDeviceSwitchData.isNotEmpty) {
          String schInfo = jsonResponse['schedule_info'];
          int j = 0;
          for (int i = 0; i < (schInfo.length / 2); i++) {
            Map<String, dynamic> targetedSwitchMap = oneDeviceSwitchData[i];

            if (int.parse(schInfo.substring(j).toString() +
                    schInfo.substring(j + 1)) >
                0) {
              // 01ANNbmXXXXXX
              targetedSwitchMap['schedule'] = 'Y';
              j += 2;
            } else {
              targetedSwitchMap['schedule'] = 'N';
              j += 2;
            }
            debugPrint('after_delete_schedule: $targetedSwitchMap');
          }
        }
      } else if (schItems[0] == 'I') {
        // new_logic
        List<dynamic>? oneDeviceSwitchData = newCacheMap[deviceMainId];
        if (oneDeviceSwitchData != null && oneDeviceSwitchData.isNotEmpty) {
          String schButton = schItems[7];
          int indexOfOperation = int.parse(schButton) - 1;
          Map<String, dynamic> targetedSwitchMap =
              oneDeviceSwitchData[indexOfOperation];
          targetedSwitchMap['schedule'] = 'Y';
        }
      }
    } else {
      // RGB schedule
      //noinspection StatementWithEmptyBody.....
      if (schItems[0] == 'ERR') {
      } else if (schItems[2] == 'EMPTY') {
        List<dynamic>? oneDeviceSwitchData = newCacheMap[deviceMainId];

        // new_logic
        if (oneDeviceSwitchData != null && oneDeviceSwitchData.isNotEmpty) {
          var schedules = jsonResponse['schedules'];

          Map<String, dynamic> rgbMap = oneDeviceSwitchData[0];
          if (schedules > 0) {
            rgbMap['schedule'] = 'Y';
          } else {
            rgbMap['schedule'] = 'N';
          }
        }
      } else if (schItems[0] == 'I') {
        List<dynamic>? oneDeviceSwitchData = newCacheMap[deviceMainId];
        // List<String> oneDeviceSwitchData = newDeviceCommands[deviceMainId];
        // if (oneDeviceSwitchData != null && oneDeviceSwitchData.isNotEmpty) {
        //   oneDeviceSwitchData[8] = 'Y';
        //   // newDeviceCommands.remove(deviceMainId);
        //   newDeviceCommands[deviceMainId] = oneDeviceSwitchData;
        // }
        if (oneDeviceSwitchData != null && oneDeviceSwitchData.isNotEmpty) {
          Map<String, dynamic> rgbMap = oneDeviceSwitchData[0];
          rgbMap['schedule'] = 'Y';
          // oneDeviceSwitchData[8] = 'Y';
          // newDeviceCommands.remove(deviceMainId);
          // newDeviceCommands[deviceMainId] = oneDeviceSwitchData;
        }
      }
    }
  }

  static tlReceived(Map<String, dynamic> jsonResponse) {
    // touch lock received
    String? deviceMainId = jsonResponse['slave'];
    String? status = jsonResponse['status'];

    if (status == 'success') {
      String? data = jsonResponse['data'];
      List<dynamic>? oneDeviceSwitchData = newCacheMap[deviceMainId];
      debugPrint('TL1_cache_data: $oneDeviceSwitchData');

      if (oneDeviceSwitchData != null && oneDeviceSwitchData.isNotEmpty) {
        String buttonNumber = data!.substring(0, 2);
        int indexOfOperation = int.parse(buttonNumber) - 1;
        Map<String, dynamic> targetedSwitchMap =
            oneDeviceSwitchData[indexOfOperation];
        targetedSwitchMap['touchLock'] = data.substring(2);
      } else {
        //send sts
        sendSTSCommand(deviceMainId);
      }
    }
  }

  static sendSTSCommand(String? deviceMainId) async {
    Box<ModelDevice> deviceBox = Hive.box(devices);
    Box<UserModel> userBox = Hive.box(userTable);
    if (deviceBox.length != 0) {
      deviceBox.values
          .where((element) => element.mainId == deviceMainId)
          .forEach((element) {
        // var command = element.hardwareType!.startsWith('rgb') ? RGB : STS;
        String byUser =  'M_${userBox.getAt(0)!.firstName} ${userBox.getAt(0)!.lastName}';
        var cmdToSend = {
          'cmd': STS,
          'slave': element.mainId,
          'token': element.token,
          'by': byUser
        };
        String cmd = jsonEncode(cmdToSend);
        UDPService().sendUDPMessage(ip: 'BroadcastIP', message: cmd);
        MQTTService().publish(deviceMainId: deviceMainId!, message: cmd);
      });
    }
  }

  static setReceived(Map<String, dynamic> jsonResponse) {
    String? deviceMainId = jsonResponse['slave'];
    String? button = jsonResponse['button']; //00 - 07
    String? fromDeviceSwitchV = jsonResponse['val']; // Y or N
    List<dynamic>? oneDeviceSwitchData = newCacheMap[deviceMainId];

    Box<ModelDevice> deviceBox = Hive.box(devices);
    String? hardwareType, hardwareVersion;
    deviceBox.values
        .where((element) => element.mainId == deviceMainId)
        .forEach((element) {
      hardwareType = element.hardwareType;
      hardwareVersion = element.hardwareVersion;
    });
    // one device switch data = 0-7 switches data {00AXNNN,.... }
    String? valueToBeReplaced;
    if (oneDeviceSwitchData != null) {
      if (hardwareType == 'standalone') {
        // Integer.parseInt(button) = 1 - 8 , button value from SET= 01 - 08
        int indexOfOperation = int.parse(button!) - 1;
        // Ex. button value from SET = 01, Integer.parseInt(button) = 1, op = 1 - 1 = 0
        //index of operation = 2 - 1 = 1,
        debugPrint('oneDeviceSwitchData: $oneDeviceSwitchData');
        Map<String, dynamic> targetedSwitchMap =
            oneDeviceSwitchData[indexOfOperation];
        bool isDimmerPresent = jsonResponse.containsKey('dimmer');

        if (!isDimmerPresent) {
          String? dimmerVal = jsonResponse['dval'];
          if (dimmerVal == 'X') {
            valueToBeReplaced = 'XX';
          } else if (dimmerVal == '0') {
            valueToBeReplaced = '00';
          } else {
            valueToBeReplaced = dimmerArray[int.parse(dimmerVal!)];
          }
        } else {
          //lighting dimmer value 0-100
          int? dimmer = jsonResponse['dimmer'];
          if (hwVer_below_2k20.contains(hardwareVersion)) {
            int multipleOf4 = dimmer! ~/ 4;
            if (multipleOf4 == 0) {
              valueToBeReplaced = "00";
            } else if (multipleOf4 > 25) {
              valueToBeReplaced = "XX";
            } else {
              valueToBeReplaced = dimmerArray[multipleOf4];
            }
          } else if (hwVer_2k21.contains(hardwareVersion)) {
            // int multipleOf4 = dimmer ~/ 4;
            if (dimmer == 0) {
              valueToBeReplaced = "00";
            } else if (dimmer == 255) {
              valueToBeReplaced = "XX";
            } else {
              valueToBeReplaced = dimmerArray[dimmer!];
            }
          } else {
            int multipleOf4 = dimmer! ~/ 4;
            if (multipleOf4 == 0) {
              valueToBeReplaced = "00";
            } else if (multipleOf4 > 25) {
              valueToBeReplaced = "XX";
            } else {
              valueToBeReplaced = dimmerArray[multipleOf4];
            }
          }
        }

        // 01ANNbmXXXXXX
        targetedSwitchMap['switchState'] = fromDeviceSwitchV![0];
        targetedSwitchMap['dimmer'] = valueToBeReplaced;
      } else if (hardwareType == 'curtain') {
        // pause - 03A, close - 01A, open - 02A
        int defaultCurtain = 3;
        int indexOfOperation = int.parse(button!) - 1;
        int result = (indexOfOperation ~/ defaultCurtain) * defaultCurtain;
        for (int i = result; i < (result + defaultCurtain); i++) {
          if (button == oneDeviceSwitchData[i]['buttonNo']) {
            oneDeviceSwitchData[i]['switchState'] = 'A';
          } else {
            oneDeviceSwitchData[i]['switchState'] = '0';
          }
        }
      } else if (hardwareType == 'doorLock') {
        // Integer.parseInt(button) = 1 - 8 , button value from SET= 01 - 08
        int indexOfOperation = int.parse(button!) - 1;
        // Ex. button value from SET = 01, Integer.parseInt(button) = 1, op = 1 - 1 = 0
        //index of operation = 2 - 1 = 1,
        Map<String, dynamic> targetedSwitchMap =
            oneDeviceSwitchData[indexOfOperation];
        targetedSwitchMap['switchState'] = fromDeviceSwitchV![0];
      }
    }
  }

  static stsReceived(Map<String, dynamic> jsonResponse) {
    String? deviceMainId = jsonResponse['slave'];
    if (!jsonResponse.containsKey('status')) {
      String hardwareVersion = jsonResponse['hw_ver'];
      checkForDeviceRename(jsonResponse);

      if (hardwareVersion.startsWith('I')) {
        // if IR then add default data in cache
        List<dynamic>? oneDeviceSwitchData = newCacheMap[deviceMainId];
        if (oneDeviceSwitchData == null) {
          oneDeviceSwitchData = [];
        } else {
          oneDeviceSwitchData.clear();
        }
        Map<String, String> singleSwitchMap = {};
        singleSwitchMap['buttonNo'] = '01';
        singleSwitchMap['switchState'] = 'X';
        singleSwitchMap['touchLock'] = 'X';
        singleSwitchMap['schedule'] = 'X';
        singleSwitchMap['dimmer'] = 'XX';
        singleSwitchMap['type'] = 'X';
        singleSwitchMap['nodeType'] = 'X';
        singleSwitchMap['humanCentric'] = 'X';
        singleSwitchMap['driverType'] = 'X';
        singleSwitchMap['universal'] = 'X';
        singleSwitchMap['manual'] = 'X';

        oneDeviceSwitchData.add(singleSwitchMap);

        if (oneDeviceSwitchData.isNotEmpty) {
          newCacheMap.remove(deviceMainId);
          newCacheMap[deviceMainId] = oneDeviceSwitchData;
        } else {
          newCacheMap[deviceMainId] = oneDeviceSwitchData;
        }
      } else {
        String? fromDeviceSwitchV = jsonResponse["val"];
        String? fromDeviceSwitchTL = jsonResponse["touch_lock"];
        String? fromDeviceSwitchS = jsonResponse["schedule_info"];
        bool isDimmerPresent = jsonResponse.containsKey("dimmer");
        bool isArmVersion = jsonResponse.containsKey('arm_ver');
        String? hardwareType;
        Box<ModelDevice> deviceBox = Hive.box(devices);
        var deviceId = '';

        deviceBox.toMap().forEach((key, value) {
          if (value.mainId == deviceMainId) {
            deviceId = value.deviceId!;
            hardwareType = value.hardwareType;
            if (isArmVersion) {
              if (value.armVersion != jsonResponse['arm_ver']) {
                if (value.operation != 'A') {
                  value.operation = 'U';
                }
                value.armVersion = jsonResponse['arm_ver'];
                deviceBox.put(key, value);
                // API call to update arm version in device table
                Constants().updateDeviceAPI(value);
              }
            } else {
              if (value.armVersion == null || value.armVersion!.isEmpty) {
                if (value.operation != 'A') {
                  value.operation = 'U';
                }
                value.armVersion = '1.0.0.0';
                deviceBox.put(key, value);
                // API call to update arm version in device table
                Constants().updateDeviceAPI(value);
              }
            }
          }
        });

        if (!hardwareType!.startsWith('rgb')) {
          List<dynamic> oneDeviceSwitchData = [];
          if (newCacheMap.containsKey(deviceMainId)) {
            oneDeviceSwitchData = newCacheMap[deviceMainId]!;
            oneDeviceSwitchData.clear();
          }

          // if (oneDeviceSwitchData == null) {
          //   oneDeviceSwitchData = [];
          // } else {
          //   oneDeviceSwitchData.clear();
          // }
          List<int> autoOffSwitchData = [];
          if (autoOffSwitchMap.containsKey(deviceMainId)) {
            autoOffSwitchData = autoOffSwitchMap[deviceMainId]!;
            autoOffSwitchData.clear();
          }
          // if (autoOffSwitchData == null) {
          //   autoOffSwitchData = [];
          // } else {
          //   autoOffSwitchData.clear();
          // }

          int j = 0;
          for (int i = 0; i < fromDeviceSwitchV!.length; i++) {
            Map<String, String?> singleSwitchMap = {};
            if ((i + 1) < 10) {
              singleSwitchMap['buttonNo'] = '0${(i + 1).toString()}';
              // single switch = " "+ "0" + (0-7) ans single switch = 00 - 07 i.e. 01
            } else {
              singleSwitchMap['buttonNo'] = (i + 1).toString();
            }

            singleSwitchMap['switchState'] = fromDeviceSwitchV[i];
            singleSwitchMap['touchLock'] = fromDeviceSwitchTL![i];
            if (int.parse(fromDeviceSwitchS![j].toString() +
                    fromDeviceSwitchS[j + 1]) >
                0) {
              singleSwitchMap['schedule'] = 'Y';
              j = j + 2;
            } else {
              singleSwitchMap['schedule'] = 'N';
              j = j + 2;
            }

            if (!isDimmerPresent) {
              // old hardware has 5 step dimmer so d_val is 0-5
              String fromDeviceSwitchDV = jsonResponse['dval'];
              if (fromDeviceSwitchDV[i] == 'X') {
                singleSwitchMap['dimmer'] = 'XX';
              } else if (fromDeviceSwitchDV[i] == '0') {
                singleSwitchMap['dimmer'] = '00';
              } else {
                singleSwitchMap['dimmer'] =
                    dimmerArray[int.parse(fromDeviceSwitchDV[i])];
              }
            } else {
              //lighting dimmer value 0-100
              var dimmer = jsonResponse['dimmer'];
              if (hwVer_below_2k20.contains(hardwareVersion)) {
                double? multipleOf4 = dimmer[i] / 4;
                String? valueToBeReplaced;
                if (multipleOf4 == 0) {
                  valueToBeReplaced = "00";
                } else if (multipleOf4! > 25) {
                  valueToBeReplaced = "XX";
                } else {
                  valueToBeReplaced = dimmerArray[multipleOf4.toInt()];
                }
                singleSwitchMap['dimmer'] = valueToBeReplaced;
              } else if (hwVer_2k21.contains(hardwareVersion)) {
                String? valueToBeReplaced;
                if (dimmer[i] == 0) {
                  valueToBeReplaced = "00";
                } else if (dimmer[i] == 255) {
                  valueToBeReplaced = "XX";
                } else {
                  valueToBeReplaced = dimmerArray[dimmer[i]];
                }
                singleSwitchMap['dimmer'] = valueToBeReplaced;
              } else {
                // if its 2 node device with dimmer tag then below code executes
                String? valueToBeReplaced;
                if (dimmer[i] == 0) {
                  valueToBeReplaced = "00";
                } else if (dimmer[i] == 255) {
                  valueToBeReplaced = "XX";
                } else {
                  valueToBeReplaced = dimmerArray[dimmer[i]];
                }

                singleSwitchMap['dimmer'] = valueToBeReplaced;
              }
            }

            // this keyword only available in new hardware 8.2.0, 4.2.0 etc.
            bool isCustomizedAvailable = jsonResponse.containsKey('customized');
            bool isDimmerTypeAvailable =
                jsonResponse.containsKey('dimmer_type');
            Box<ModelSwitches> switchesBox = Hive.box(switches);

            // NOTE: dimmer_type and customized tag are only available in 2021 hardware
            // we need to update dimmer type according to its value
            if (isCustomizedAvailable) {
              // new device
              // customized: [0, 0, 17327104, 16908560, 0, 0, 0, 0]
              List<dynamic> customizedList = jsonResponse['customized'];
              if (customizedList[i] == 0) {
                // there are no customized data
                singleSwitchMap['type'] = 'X';
                singleSwitchMap['nodeType'] = 'X';
                singleSwitchMap['humanCentric'] = 'X';
                singleSwitchMap['driverType'] = 'X';
                singleSwitchMap['universal'] = 'X';
                singleSwitchMap['manual'] = 'X';

                // update dimmerType
                if (switchesBox.length != 0) {
                  for (int k = 0; k < switchesBox.length; k++) {
                    if (switchesBox.getAt(k)!.deviceMainId == deviceId &&
                        int.parse(switchesBox.getAt(k)!.buttonNumber!) ==
                            (i + 1)) {
                      if (isDimmerTypeAvailable) {
                        String dimmerTypeInCmd = jsonResponse['dimmer_type'];
                        if (dimmerTypeInCmd[i] == 'F') {
                          // fan dimmer
                          switchesBox.getAt(k)!.dimmerType = 'F';
                        } else if (dimmerTypeInCmd[i] == 'Y') {
                          // light dimmer
                          switchesBox.getAt(k)!.dimmerType = 'L';
                        } else {
                          // switch
                          switchesBox.getAt(k)!.dimmerType = 'N';
                        }
                      } else {
                        // if dimmer_type not in json then put default dimmer type to light dimmer
                        switchesBox.getAt(k)!.dimmerType = 'L';
                      }
                      switchesBox.putAt(k, switchesBox.getAt(k)!);

                      // incomplete task to update dimmer type in server
                      // updateDimmerTypeAPI(switchesBox.getAt(k)!);
                    }
                  }
                }
              } else {
                // if its NOT 0 then it is customized so get data accordingly.
                Map<String, dynamic> customizedMap = getData(customizedList[i]);
                singleSwitchMap['type'] = customizedMap['type'];
                singleSwitchMap['nodeType'] = customizedMap['nodeType'];
                singleSwitchMap['humanCentric'] = customizedMap['humanCentric'];

                // String universal, manual, driverType;
                if (customizedMap['nodeType'] == 'C') {
                  Map<String, dynamic> map = getData(customizedList[i - 1]);

                  singleSwitchMap['driverType'] = map['driverType'];
                  singleSwitchMap['universal'] = map['universal'];
                  singleSwitchMap['manual'] = map['manual'];
                } else {
                  singleSwitchMap['driverType'] = customizedMap['driverType'];
                  singleSwitchMap['universal'] = customizedMap['universal'];
                  singleSwitchMap['manual'] = customizedMap['manual'];
                }

                // update dimmer type in db
                if (switchesBox.length != 0) {
                  for (int k = 0; k < switchesBox.length; k++) {
                    if (switchesBox.getAt(k)!.deviceMainId == deviceId &&
                        int.parse(switchesBox.getAt(k)!.buttonNumber!) ==
                            (i + 1)) {
                      String? driverType = singleSwitchMap['driverType'];
                      if (driverType == '1') {
                        switchesBox.getAt(k)!.dimmerType = 'T';
                      } else if (driverType == '0') {
                        // driver type 0 which means
                        switchesBox.getAt(k)!.dimmerType = 'T2';
                      }
                      switchesBox.putAt(k, switchesBox.getAt(k)!);
                      // incomplete task to update dimmer type in server
                      // updateDimmerTypeAPI(switchesBox.getAt(k)!);
                    }
                  }
                }
              }
            } else {
              // device who has below value of 1.0.0.6 arm version
              // if customized tag not in cmd
              singleSwitchMap['type'] = 'X';
              singleSwitchMap['nodeType'] = 'X';
              singleSwitchMap['humanCentric'] = 'X';
              singleSwitchMap['driverType'] = 'X';
              singleSwitchMap['universal'] = 'X';
              singleSwitchMap['manual'] = 'X';

              // update dimmer type in db
              if (switchesBox.length != 0) {
                for (int k = 0; k < switchesBox.length; k++) {
                  if (switchesBox.getAt(k)!.deviceMainId == deviceId &&
                      int.parse(switchesBox.getAt(k)!.buttonNumber!) ==
                          (i + 1)) {
                    if (isDimmerTypeAvailable) {
                      String dimmerTypeInCmd = jsonResponse['dimmer_type'];

                      if ((dimmerTypeInCmd !=
                              switchesBox.getAt(k)!.dimmerType) &&
                          (switchesBox.getAt(k)!.isDimmable != 'N')) {
                        if (dimmerTypeInCmd[i] == 'F') {
                          // fan dimmer
                          switchesBox.getAt(k)!.dimmerType = 'F';
                        } else if (dimmerTypeInCmd[i] == 'Y') {
                          // light dimmer
                          switchesBox.getAt(k)!.dimmerType = 'L';
                        } else {
                          // for switch its value is X in cmd
                          switchesBox.getAt(k)!.dimmerType = 'N';
                        }
                        switchesBox.putAt(k, switchesBox.getAt(k)!);
                        // incomplete task to update dimmer type in server
                        // updateDimmerTypeAPI(switchesBox.getAt(k)!);
                      }
                    } else {
                      // if dimmer_type not in json then put default dimmer type to fan dimmer
                      // or light dimmer according to button number
                      if (switchesBox.getAt(k)!.isDimmable != 'N') {
                        if (switchesBox.getAt(k)!.buttonNumber == '01') {
                          switchesBox.getAt(k)!.dimmerType = 'F';
                        } else {
                          switchesBox.getAt(k)!.dimmerType = 'L';
                        }
                        switchesBox.putAt(k, switchesBox.getAt(k)!);
                        // incomplete task to update dimmer type in server
                        // updateDimmerTypeAPI(switchesBox.getAt(k)!);
                      }
                    }
                  }
                }
              }
            }
            oneDeviceSwitchData.add(singleSwitchMap);
          }

          if (oneDeviceSwitchData.isNotEmpty) {
            newCacheMap.remove(deviceMainId);
            newCacheMap[deviceMainId] = oneDeviceSwitchData;
          } else {
            newCacheMap[deviceMainId] = oneDeviceSwitchData;
          }

          // auto off
          if (jsonResponse.containsKey('auto_off')) {
            List<dynamic> autoOffArray = jsonResponse['auto_off'];
            for (int i = 0; i < autoOffArray.length; i++) {
              autoOffSwitchData.add(autoOffArray[i]);
            }
          }

          if (autoOffSwitchData.isNotEmpty) {
            autoOffSwitchMap.remove(deviceMainId);
            autoOffSwitchMap[deviceMainId] = autoOffSwitchData;
          } else {
            autoOffSwitchMap[deviceMainId] = autoOffSwitchData;
          }
        }
      }
    }
  }

  static checkForDeviceRename(Map<String, dynamic> jsonResponse) {
    // device rename
    String? deviceMainId = jsonResponse['slave'];
    String? deviceName = jsonResponse['m_name'];
    var deviceBox = Hive.box<ModelDevice>(devices);
    deviceBox.toMap().forEach((key, value) {
      if ((value.mainId == deviceMainId) && (value.name != deviceName)) {
        // API call to update device name
        value.name = deviceName;
        value.operation = 'U';
        deviceBox.put(key, value);
      }
    });
    editDeviceAPI(deviceMainId);
  }

  static Future<void> editDeviceAPI(String? deviceMainId) async {
    Box<ModelDevice> deviceBox = Hive.box(devices);
    deviceBox.toMap().forEach((key, value) async {
      if ((value.mainId == deviceMainId) && (value.operation == 'U')) {
        var body = jsonEncode(value.toJson());
        var response = await http.put(
          Uri.parse(deviceDetailsUrl),
          headers: defaultHeader(),
          body: body,
        );
        debugPrint('editDeviceResponse: ${response.body}');
        if (successCodes.contains(response.statusCode)) {
          var object = jsonDecode(response.body);
          var status = object['status'];
          if (status == success) {
            if (value.operation != 'A') {
              value.operation = 'N';
            }
            deviceBox.put(key, value);
          }
        }
      }
    });
  }

  // static Future<void> renameDeviceAPI(
  //     String? deviceName, String? deviceMainId) async {
  //   Box<ModelDevice> deviceBox = Hive.box(devices);
  //   var deviceId = deviceBox.values
  //       .where((element) => element.mainId == deviceMainId)
  //       .first
  //       .deviceId;
  //   var body = jsonEncode({
  //     "deviceId": deviceId,
  //     "slaveId": deviceMainId,
  //     "name": deviceName,
  //   });
  //   debugPrint('renameDevice_body: $body');

  //   var response = await http.put(
  //     Uri.parse(deviceDetailsUrl),
  //     headers: defaultHeader(),
  //     body: body,
  //   );
  //   debugPrint('renameDeviceRes: ${response.body}');
  //   var object = jsonDecode(response.body);

  //   if (successCodes.contains(response.statusCode)) {
  //     String status = object['status'];
  //     if (status == success) {
  //       deviceBox.toMap().forEach((key, value) {
  //         if (value.deviceId == deviceId) {
  //           if (value.name != deviceName) {
  //             value.name = deviceName;
  //             deviceBox.put(key, value);
  //           }
  //           // deviceName = deviceName!;
  //         }
  //       });
  //     }
  //   }
  //   // else {
  //   //   httpErrorToast(statusCode: response.statusCode, toast: object['toast']);
  //   // }
  // }

  static void rgbReceived(Map<String, dynamic> jsonResponse) {
    String? deviceMainId = jsonResponse['slave'];

    if (!jsonResponse.containsKey('status')) {
      String red = jsonResponse['R'].toString();
      String green = jsonResponse['G'].toString();
      String blue = jsonResponse['B'].toString();
      String brightness = jsonResponse['brightness'].toString();
      String? value = jsonResponse['val'];
      String patternId = jsonResponse['pat_id'].toString();
      String patternColor = jsonResponse['pat_colour'].toString();
      String patternSpeed = jsonResponse['pat_speed'].toString();
      String scheduleInfo = jsonResponse['schedule_info'].toString();

      List<dynamic>? oneDeviceSwitchData = newCacheMap[deviceMainId];

      if (oneDeviceSwitchData == null || oneDeviceSwitchData.isNotEmpty) {
        oneDeviceSwitchData = [];
      } else {
        oneDeviceSwitchData.clear();
      }

      String white =
          jsonResponse.containsKey('W') ? jsonResponse['W'].toString() : '0';
      Map<String, String?> rgbMap = {};
      rgbMap['red'] = red;
      rgbMap['green'] = green;
      rgbMap['blue'] = blue;
      rgbMap['white'] = white;
      rgbMap['brightness'] = brightness;
      rgbMap['switchState'] = value;
      rgbMap['patternId'] = patternId;
      rgbMap['patternColor'] = patternColor;
      rgbMap['patternSpeed'] = patternSpeed;

      if (int.parse(scheduleInfo) > 0) {
        rgbMap['schedule'] = 'Y';
      } else {
        rgbMap['schedule'] = 'N';
      }

      oneDeviceSwitchData.add(rgbMap);

      if (oneDeviceSwitchData.isNotEmpty) {
        newCacheMap.remove(deviceMainId);
        newCacheMap[deviceMainId] = oneDeviceSwitchData;
      } else {
        newCacheMap[deviceMainId] = oneDeviceSwitchData;
      }
    }
  }

  static Map<String, dynamic> getData(value) {
    int? p = value >> 24 & 0xff;
    int q = value >> 16 & 0xff;
    int? r = value >> 8 & 0xff;
    int s = value & 0xff;

    // int x = q ~/ 16;
    int y = q % 16;

    int a = s ~/ 16; // manual
    int b = s % 16; // universal
    String nodeType = '', humanCentric = '';
    // debugPrint("\na: $a, b: $b");

    if (p == 1) {
      // debugPrint('\nconfig type is tunable');
      // debugPrint('tunable slot is $x');
      if (y == 8 || y == 4) {
        if (y == 8) {
          // debugPrint('cool node and HCL is enable');
          humanCentric = 'Y';
        } else if (y == 4) {
          // debugPrint('cool node and HCL is disable');
          humanCentric = 'N';
        }
        nodeType = 'C'; // COOL
        // debugPrint('max cool is $r, min cool is $s');
      }

      if (y == 2 || y == 1) {
        if (y == 2) {
          humanCentric = 'Y';
          // debugPrint('warm node and HCL is enable');
        } else if (y == 1) {
          humanCentric = 'N';
          // debugPrint('warm node and HCL is disable');
        }
        nodeType = 'W'; // WARM
        // debugPrint('driver type is $r, universal is $b, manual: $a');
      }
    } else {
      // debugPrint('config type unknown');
    }
    Map<String, dynamic> map = {};
    map['type'] = p.toString();
    map['nodeType'] = nodeType;
    map['humanCentric'] = humanCentric;
    if (nodeType == 'C') {
      map['driverType'] = 'X';
      map['universal'] = 'X';
      map['manual'] = 'X';
    } else {
      map['driverType'] = r.toString();
      String universal, manual;
      if (b == 1) {
        universal = 'Y';
      } else {
        universal = 'N';
      }
      map['universal'] = universal;

      if (a == 1) {
        manual = 'Y';
      } else {
        manual = 'N';
      }
      map['manual'] = manual;
    }
    return map;
  }

  static Future<void> cusReceived(Map<String, dynamic> jsonResponse) async {
    String? deviceMainId = jsonResponse['slave'];
    String? subCmd = jsonResponse['sub_cmd'];

    if (subCmd == TUN) {
      int? operation = jsonResponse['operation'];

      if (operation == 1) {
        // response of save tunable
        List<dynamic>? oneDeviceSwitchData = newCacheMap[deviceMainId];

        List<dynamic> data = jsonResponse['data'];
        for (int i = 0; i < data.length; i++) {
          List<dynamic> tunableData = data[i];
          // int slotNo = tunableData[0];
          // int minCool = tunableData[1];
          // int maxCool = tunableData[2];
          int coolSwitch = tunableData[3];
          int warmSwitch = tunableData[4];
          int hclEnable = tunableData[5];
          int manualDisable = tunableData[6];
          int onOff = tunableData[7];
          int tuning = tunableData[8];
          int brightness = tunableData[9];
          // int coolWhitePercentage = tunableData[10];
          // int warmWhitePercentage = tunableData[11];
          int driverType = tunableData[12];
          int universal = tunableData[13];

          // only cache update
          // if slot 0 then sw 1 and 2, slot 1 then sw 3 and 4
          String tunable = '1';
          String isHclEnable = '';
          if (hclEnable == 1) {
            isHclEnable = 'Y';
          } else {
            isHclEnable = 'N';
          }

          String isUniversal = '';
          if (universal == 1) {
            isUniversal = 'Y';
          } else {
            isUniversal = 'N';
          }

          String isManual = '';
          if (manualDisable == 1) {
            isManual = 'Y';
          } else {
            isManual = 'N';
          }

          String onOffValue = onOff == 1 ? 'A' : '0';

          String? coolDimValue, warmDimValue;
          if (driverType == 0) {
            warmDimValue = brightness == 0 || brightness < 0
                ? '00'
                : dimmerArray[brightness];
            coolDimValue =
                tuning == 0 || tuning < 0 ? '00' : dimmerArray[tuning];
          } else if (driverType == 1) {
            int coolSwitchDimmer = (tuning * brightness) ~/ 100;
            int warmSwitchDimmer = brightness - coolSwitchDimmer;
            warmDimValue = warmSwitchDimmer == 0 || warmSwitchDimmer < 0
                ? '00'
                : dimmerArray[warmSwitchDimmer];
            coolDimValue = coolSwitchDimmer == 0 || coolSwitchDimmer < 0
                ? '00'
                : dimmerArray[coolSwitchDimmer];
          }

          debugPrint(
              'coolSwDim: $coolDimValue, warmSwDim: $warmDimValue, driverType: $driverType');
          Map<String, dynamic> coolSwitchMap = oneDeviceSwitchData![coolSwitch];
          coolSwitchMap['switchState'] = onOffValue;
          coolSwitchMap['dimmer'] = coolDimValue;
          coolSwitchMap['type'] = tunable;
          coolSwitchMap['nodeType'] = 'C';
          coolSwitchMap['humanCentric'] = isHclEnable;
          coolSwitchMap['driverType'] = driverType.toString();
          coolSwitchMap['universal'] = isUniversal;
          coolSwitchMap['manual'] = isManual;

          Map<String, dynamic> warmSwitchMap = oneDeviceSwitchData[warmSwitch];
          warmSwitchMap['switchState'] = onOffValue;
          warmSwitchMap['dimmer'] = warmDimValue;
          warmSwitchMap['type'] = tunable;
          warmSwitchMap['nodeType'] = 'W';
          warmSwitchMap['humanCentric'] = isHclEnable;
          warmSwitchMap['driverType'] = driverType.toString();
          warmSwitchMap['universal'] = isUniversal;
          warmSwitchMap['manual'] = isManual;

          debugPrint('updatedCache: ${newCacheMap[deviceMainId]}');
        }
      } else if (operation == 11) {
        List<dynamic> oneDeviceSwitchData = newCacheMap[deviceMainId] ?? [];
        List<dynamic> data = jsonResponse['data'];

        for (int i = 0; i < data.length; i++) {
          List<dynamic> tunableData = data[i];
          int slotNumber = tunableData[0];
          int onOff = tunableData[1];
          int tuning = tunableData[2];
          int brightness = tunableData[3];
          int manual = tunableData[4];

          String onOffValue = onOff == 1 ? 'A' : '0';

          // calculate cool and warm btn value from tuning and brightness
          // ---------start---------
          int cool = (tuning * brightness) ~/ 100;
          int warm = brightness - cool;
          String? warmDimValue =
              warm == 0 || warm < 0 ? '00' : dimmerArray[warm];
          String? coolDimValue =
              cool == 0 || cool < 0 ? '00' : dimmerArray[cool];
          // -------end------
          String manualValue = manual == 1 ? 'Y' : 'N';

          if (slotNumber == 0) {
            // 01,02 switches (0,1)
            Map<String, dynamic> warmSwitchMap = oneDeviceSwitchData[0];
            warmSwitchMap['switchState'] = onOffValue;
            if (warmSwitchMap['driverType'] == '0') {
              warmSwitchMap['dimmer'] =
                  brightness == 0 ? '00' : dimmerArray[brightness];
            } else if (warmSwitchMap['driverType'] == '1') {
              warmSwitchMap['dimmer'] = warmDimValue;
            }
            warmSwitchMap['manual'] = manualValue;

            Map<String, dynamic> coolSwitchMap = oneDeviceSwitchData[1];
            coolSwitchMap['switchState'] = onOffValue;
            if (coolSwitchMap['driverType'] == '0') {
              coolSwitchMap['dimmer'] =
                  tuning == 0 ? '00' : dimmerArray[tuning];
            } else if (coolSwitchMap['driverType'] == '1') {
              coolSwitchMap['dimmer'] = coolDimValue;
            }
            coolSwitchMap['manual'] = manualValue;
            // debugPrint('warmMap: ${warmSwitchMap}, coolMap: ${coolSwitchMap},'
            //     ' tuning: $tuning, brightness: $brightness}');
          } else if (slotNumber == 1) {
            // 03,04 switches (2,3)

            Map<String, dynamic> warmSwitchMap = oneDeviceSwitchData[2];
            // debugPrint('tun1 warm map before $oneDeviceSwitchData');
            warmSwitchMap['switchState'] = onOffValue;
            if (warmSwitchMap['driverType'] == '0') {
              warmSwitchMap['dimmer'] =
                  brightness == 0 ? '00' : dimmerArray[brightness];
            } else if (warmSwitchMap['driverType'] == '1') {
              warmSwitchMap['dimmer'] = warmDimValue;
            }
            // warmSwitchMap['dimmer'] = warmDimValue;
            warmSwitchMap['manual'] = manualValue;
            // debugPrint('tun1 warm map $oneDeviceSwitchData');

            Map<String, dynamic> coolSwitchMap = oneDeviceSwitchData[3];
            coolSwitchMap['switchState'] = onOffValue;
            if (coolSwitchMap['driverType'] == '0') {
              coolSwitchMap['dimmer'] =
                  tuning == 0 ? '00' : dimmerArray[tuning];
            } else if (coolSwitchMap['driverType'] == '1') {
              coolSwitchMap['dimmer'] = coolDimValue;
            }
            // coolSwitchMap['dimmer'] = coolDimValue;
            coolSwitchMap['manual'] = manualValue;
          }
        }
      } else if (operation == 7) {
        // delete response
        List<dynamic> data = jsonResponse['data'];
        // delete
        List<dynamic>? oneDeviceSwitchData = newCacheMap[deviceMainId];
        for (int i = 0; i < data.length; i++) {
          List<dynamic> dataList = data[i];
          int slotNumber = dataList[0];

          if (slotNumber == 0) {
            Map<String, dynamic> warmSwitchMap = oneDeviceSwitchData![0];
            warmSwitchMap['dimmer'] = 'dv';
            warmSwitchMap['type'] = 'X';
            warmSwitchMap['nodeType'] = 'X';
            warmSwitchMap['humanCentric'] = 'X';
            warmSwitchMap['driverType'] = 'X';
            warmSwitchMap['universal'] = 'X';
            warmSwitchMap['manual'] = 'X';

            Map<String, dynamic> coolSwitchMap = oneDeviceSwitchData[1];
            coolSwitchMap['dimmer'] = 'dv';
            coolSwitchMap['type'] = 'X';
            coolSwitchMap['nodeType'] = 'X';
            coolSwitchMap['humanCentric'] = 'X';
            coolSwitchMap['driverType'] = 'X';
            coolSwitchMap['universal'] = 'X';
            coolSwitchMap['manual'] = 'X';
          } else if (slotNumber == 1) {
            Map<String, dynamic> warmSwitchMap = oneDeviceSwitchData![2];
            warmSwitchMap['dimmer'] = 'dv';
            warmSwitchMap['type'] = 'X';
            warmSwitchMap['nodeType'] = 'X';
            warmSwitchMap['humanCentric'] = 'X';
            warmSwitchMap['driverType'] = 'X';
            warmSwitchMap['universal'] = 'X';
            warmSwitchMap['manual'] = 'X';

            Map<String, dynamic> coolSwitchMap = oneDeviceSwitchData[3];
            coolSwitchMap['dimmer'] = 'dv';
            coolSwitchMap['type'] = 'X';
            coolSwitchMap['nodeType'] = 'X';
            coolSwitchMap['humanCentric'] = 'X';
            coolSwitchMap['driverType'] = 'X';
            coolSwitchMap['universal'] = 'X';
            coolSwitchMap['manual'] = 'X';
          }
        }
      }
    }
  }

  static String getTimeZone() {
    int timeInMillis = DateTime.now().timeZoneOffset.inMilliseconds;
    int offSet = timeInMillis ~/ (60 * 1000);

    int hrs = offSet ~/ 60;
    int min = (offSet % 60).toInt();

    String currentTimeZone;

    if (hrs > 0) {
      currentTimeZone = "+$hrs:$min";
    } else {
      currentTimeZone = "$hrs:$min";
    }

    return currentTimeZone;
  }

  static void deleteSubUser(Map<String, dynamic> jsonResponse) {
    String? status = jsonResponse['status'];
    String? description;
    if (status == '100') {
      description = 'Your account has been deleted by Admin';
    } else if (status == '101') {
      description = 'Your session has been expired';
    } else if (status == '102') {
      description = 'Your account has been deleted';
    }

    Get.bottomSheet(
      AlertDialogSheet(
        title: "WARNING!",
        description: description,
        onNeutralBtnPress: () {
          signOutUser();
        },
      ),
      backgroundColor: Colors.transparent,
      isDismissible: false,
      isScrollControlled: true,
      enableDrag: false,
      elevation: 10,
    );
  }

  static void signOutUser() {
    Box<ModelRoom> roomBox = Hive.box(room);
    Box<ModelScenes> scenesBox = Hive.box(scenes);
    Box<UserModel> userBox = Hive.box(userTable);
    Box<ModelFloor> floorBox = Hive.box(floor);
    Box<ModelDevice> deviceBox = Hive.box(devices);
    Box<ModelSwitches> switchesBox = Hive.box(switches);
    Box<ModelRemotes> remotesBox = Hive.box(remotes);
    Box<ModelSetTopBoxChannels> channelBox = Hive.box(setTopBoxChannels);
    Box<ModelGeoFencing> geoFencingBox = Hive.box(geoFencing);

    //unsubscribe devices
    for (int i = 0; i < deviceBox.length; i++) {
      MQTTService().unsubscribeDevicesToMQTT(deviceBox.getAt(i)!.mainId!);
    }

    // unsubscribe user
    MQTTService().unsubscribeUserToMQTTServer(userBox.getAt(0)!.userId!);

    userBox.deleteAll(userBox.keys);
    deviceBox.deleteAll(deviceBox.keys);
    switchesBox.deleteAll(switchesBox.keys);
    roomBox.deleteAll(roomBox.keys);
    floorBox.deleteAll(floorBox.keys);
    scenesBox.deleteAll(scenesBox.keys);
    remotesBox.deleteAll(remotesBox.keys);
    channelBox.deleteAll(channelBox.keys);
    geoFencingBox.deleteAll(geoFencingBox.keys);

    // clear all variables
    devicesWorking.clear();
    devicesInLocal.clear();
    // deviceMainIdsList.clear();
    arrayIpCache.clear();
    receivedIp.clear();
    SharedPreferenceManager.removeValues();
    SharedPreferenceManager.setLoginStatus(false);
    Get.offAll(() => const AuthenticationScreen());
  }

  static Future<void> checkProfileTime() async {
    Box<UserModel> userBox = Hive.box(userTable);
    // String? updatedTime = userBox.getAt(0)!.profileUpdatedAt;
    String? jwtToken = userBox.getAt(0)!.jwtToken;

    Map<String, dynamic> map = {};
    map['profileTime'] = '';
    map['function'] = profileTimeFunction;
    map['token'] = jwtToken;
    map['clientId'] = clientId;
    String object = jsonEncode(map);

    debugPrint('sendProfileTimeData:-> $object');
    // MQTTService().publishToServer(message: object);
    // isProfileTimeCmdSent = true;
  }

  static bool isTunableSupport(String armVersion, int greaterThanNumber) {
    bool isTunableSupport = false;
    if (armVersion.isNotEmpty) {
      List<String> data = armVersion.split('.');
      debugPrint('armVersion: $data');
      if (int.parse(data[3]) >= greaterThanNumber) {
        isTunableSupport = true;
      }
    } else {
      isTunableSupport = false;
    }

    return isTunableSupport;
  }

  static bool isAutoOffSupport(String wifiVersion, int greaterThanNumber) {
    bool isAutoOffSupport = false;
    List<String> data = wifiVersion.split('.');
    if (int.parse(data[1]) > greaterThanNumber) {
      isAutoOffSupport = true;
    }
    return isAutoOffSupport;
  }

  static List<String?> isSceneHasSwitches({String? sceneId}) {
    List<String?> deviceIdList = [];
    Box<ModelScenes> sceneBox = Hive.box(scenes);
    sceneBox.values
        .where((element) => element.id == sceneId)
        .forEach((modelScenes) {
      // save lighting, curtain, rgb, doorlock deviceMainIds
      var switchCommand = modelScenes.commandArray ?? [];
      for (var element in switchCommand) {
        deviceIdList.add(element['slave']);
      }

      // save ir devices mainIds
      var irCommand = modelScenes.irCommandArray ?? [];
      for (var element in irCommand) {
        deviceIdList.add(element['slave']);
      }
    });
    return deviceIdList;
  }

  dynamic isSceneWithoutIr({String? sceneId}) {
    List<String?> deviceIdList = [];
    Box<ModelScenes> sceneBox = Hive.box(scenes);
    sceneBox.values
        .where((element) => element.id == sceneId)
        .forEach((modelScenes) {
      for (var element in modelScenes.commandArray!) {
        var mainId = element['slave'];
        deviceIdList.add(mainId);
      }
    });
    return deviceIdList;
  }

  static List<String> parseNewCompanyName(String companyName) {
    //return company name at 0th index and id at 1 index
    List<String> parsedNewCompanyName = List.filled(2, '');
    //uppercases character after space
    parsedNewCompanyName[0] = companyName.replaceAllMapped(
        RegExp(r'[ ][a-z]'), (match) => match[0]!.toUpperCase());
    //uppercases first character of string
    parsedNewCompanyName[0] =
        '${parsedNewCompanyName[0][0].toUpperCase()}${parsedNewCompanyName[0].substring(1)}';
    //removes all white spaces
    parsedNewCompanyName[1] = parsedNewCompanyName[0]
        .replaceAllMapped(RegExp(r'[ ]'), (match) => '')
        .toUpperCase();
    return parsedNewCompanyName;
  }

  bool isSpeechIntialized = false;

  String transposeString(String text) {
    String validatedString = Constants.defaultString;
    validatedString = text
        .toString()
        .trim()
        .toLowerCase()
        .replaceAllMapped(RegExp('[ ]'), (match) => '_');
    bool iterate = false;
    do {
      iterate = false;
      validatedString = validatedString
          .toString()
          .replaceAllMapped(RegExp('[_][_]'), (match) {
        iterate = true;
        return '_';
      });
    } while (iterate == true);
    debugPrint('vc1 changed $validatedString');
    return validatedString;
  }

  static Map<String, dynamic> _readAndroidBuildData(AndroidDeviceInfo build) {
    return <String, dynamic>{
      'brand': build.brand,
      'device': build.device,
      'manufacturer': build.manufacturer,
      'model': build.model,
      'product': build.product,
      'id':build.id
    };
  }

  static Map<String, dynamic> _readIosDeviceInfo(IosDeviceInfo data) {
    return <String, dynamic>{
      'name': data.name,
      'systemName': data.systemName,
      'systemVersion': data.systemVersion,
      'model': data.model,
      'id':data.identifierForVendor
    };
  }

  final String _chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890';
  final Random _rnd = Random();
  String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
        length,
        (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length)),
      ));

  static Future<void> updateDimmerTypeAPI(ModelSwitches modelSwitches) async {
    var body = jsonEncode({
      'switchId': modelSwitches.switchId,
      'dimmerType': modelSwitches.dimmerType
    });
    debugPrint('updateDimmer_body: $body');
    var response = await http.post(
      Uri.parse(switchConfigurationUrl),
      headers: defaultHeader(),
      body: body,
    );
    debugPrint('updateDimmer_res: ${response.statusCode} => ${response.body}');
    // if (successCodes.contains(response.statusCode)) {
    //   debugPrint('success: ${response.statusCode} => ${response.body}');
    // } else {
    //   debugPrint('error_response: ${response.body}');
    // }
  }

  String getUtcTime(String istTime) {
    var dateTime = DateFormat("HH:mm").parse(istTime, false);
    var dateLocal = dateTime.toUtc();

    var timeFormatter = DateFormat('HH:mm');
    String utcTime = timeFormatter.format(dateLocal);

    return utcTime;
  }

  String getUtcDateTime(String istDateTime) {
    var dateTime = DateFormat("dd-MM-yyyy HH:mm").parse(istDateTime, false);
    // var dateTimeUTC = dateTime.toUtc().toIso8601String();
    var dateTimeUTC = dateTime.toIso8601String();
    debugPrint('dateLocal: $dateTimeUTC');
    // var dateFormatter = new DateFormat('dd-MM-yyyy');
    // String utcDate = dateFormatter.format(dateLocal);

    return dateTimeUTC;
  }

  String getISTTime(String utcDate) {
    var dateTime = DateFormat("dd-MM-yyyy HH:mm").parse(utcDate, true);
    var dateLocal = dateTime.toLocal();

    var timeFormatter = DateFormat('hh:mm a');
    String time = timeFormatter.format(dateLocal);

    return time;
  }

  Future<void> saveUserLoginHistory() async {
    DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
    Map<String, dynamic> deviceData = <String, dynamic>{};
    String? modelName;
    String? deviceName;
    String? deviceId;

    try {
      if (!kIsWeb && Platform.isAndroid) {
        deviceData = _readAndroidBuildData(await deviceInfoPlugin.androidInfo);
        deviceName = deviceData['device'];
        deviceId = deviceData['id'];
      } else if (!kIsWeb && Platform.isIOS) {
        deviceData = _readIosDeviceInfo(await deviceInfoPlugin.iosInfo);
        deviceName = deviceData['name'].replaceAll('’', '\'');
        deviceId = deviceData['id'];
      }

      modelName = deviceData['model'];
    } on PlatformException {
      deviceData = <String, dynamic>{
        'Error:': 'Failed to get platform version.'
      };
    }

    var jwtToken = 'JWT ${Hive.box<UserModel>(userTable).getAt(0)!.jwtToken}';
    var header = {'Authorization': jwtToken};
    var body = {"deviceName": deviceName, "modelName": modelName, "deviceId":deviceId};
  //   {
  //     "deviceId":"nokia1",
  //   "deviceName":"nokia phone",
  //   "modelName":"nokiaaa"
  // }
    debugPrint('saveLoginHistory_body: $body, $header');
    var response = await http.post(
      Uri.parse(saveUserLoginDataUrl),
      headers: header,
      body: body,
    );
    debugPrint('saveLoginHistory_res: ${response.body}');
    if (successCodes.contains(response.statusCode)) {
      debugPrint('saved Login data');
    } else {
      debugPrint('${response.statusCode}, Error while saving login history');
    }
  }
  Future<void> updateUserLoginData() async {
    DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
    Map<String, dynamic> deviceData = <String, dynamic>{};
    String? deviceId;

    try {
      if (!kIsWeb && Platform.isAndroid) {
        deviceId = deviceData['id'];
      } else if (!kIsWeb && Platform.isIOS) {
        deviceData = _readIosDeviceInfo(await deviceInfoPlugin.iosInfo);
        deviceId = deviceData['id'];
      }

    } on PlatformException {
      deviceData = <String, dynamic>{
        'Error:': 'Failed to get platform version.'
      };
    }

    var jwtToken = 'JWT ${Hive.box<UserModel>(userTable).getAt(0)!.jwtToken}';
    var header = {'Authorization': jwtToken};
    var body = { "deviceId":deviceId};
  //   {
  //     "deviceId":"nokia1",
  //   "deviceName":"nokia phone",
  //   "modelName":"nokiaaa"
  // }
    debugPrint('saveLoginHistory_body: $body, $header');
    var response = await http.post(
      Uri.parse(updateUserLoginUrl),
      headers: header,
      body: body,
    );
    if (successCodes.contains(response.statusCode)) {
    } else {
    }
  }

  // Future<bool> checkAdminToken(bool isToastRequired) async {
  //   var isValidToken = false;
  //   if (Hive.box<UserModel>(userTable).getAt(0)!.adminToken == null ||
  //       Hive.box<UserModel>(userTable).getAt(0)!.adminToken == '') {
  //     noAdminAccessToast(null);
  //     isValidToken = false;
  //   } else {
  //     debugPrint('checkAdminToken_header: ${defaultHeader()}');
  //     var response = await http.get(
  //       Uri.parse(checkAdminTokenUrl),
  //       headers: defaultHeader(),
  //     );
  //     debugPrint('checkAdminToken_response: ${response.body}');
  //     if (response.statusCode == 401) {
  //       // unauthorized
  //       unAuthorizedUser();
  //       isValidToken = false;
  //     } else if (successCodes.contains(response.statusCode)) {
  //       isValidToken = true;
  //     } else {
  //       var object = jsonDecode(response.body);
  //       if (isToastRequired) {
  //         noAdminAccessToast(object['toast']);
  //       }

  //       isValidToken = false;
  //     }
  //   }
  //   debugPrint(isValidToken.toString());
  //   return isValidToken;
  // }

  unAuthorizedUser() {
    Get.bottomSheet(
      WillPopScope(
        onWillPop: () async => false,
        child: AlertDialogSheet(
          title: "Invalid Access",
          description: "Your password is invalid you've been logout",
          onNeutralBtnPress: () => signOutUser(),
        ),
      ),
    );
  }

  void userLoggedInProcess(UserModel userDataFromJson) {
    Box<UserModel> userBox = Hive.box(userTable);
    SharedPreferenceManager.setLoginStatus(true);
    // Constants().saveUserLoginHistory();
    userBox.delete(userBox.keys).then((value) {
      userBox.add(userDataFromJson).then((value) {
        if (Get.isRegistered<OtpController>()) {
          Get.delete<OtpController>();
        }
        if (Get.isRegistered<AuthenticationController>()) {
          Get.delete<AuthenticationController>();
        }

        fetchAllData();
        Timer.periodic(const Duration(seconds: 1), (timer) {
          // navigate to main screen
          Get.offAll(() => const MainNavigationScreen());
          timer.cancel();
        });
      });
    });
  }

  Future<void> fetchAllData() async {
    debugPrint('fetchAllDataHeader: ${defaultHeader()}');
    Box<ModelFloor> floorBox = Hive.box(floor);
    Box<ModelRoom> roomBox = Hive.box(room);
    Box<ModelDevice> deviceBox = Hive.box(devices);
    Box<ModelSwitches> switchBox = Hive.box(switches);
    Box<ModelScenes> sceneBox = Hive.box(scenes);
    Box<ModelUserSettings> userSettingBox = Hive.box(userSettings);
    Box<ModelRemotes> remoteBox = Hive.box(remotes);

    var response =
        await http.get(Uri.parse(fetchAllDataUrl), headers: defaultHeader());
    debugPrint('fetchAllDataRes: ${response.body}');

    if (successCodes.contains(response.statusCode)) {
      var object = json.decode(response.body);
      String status = object['status'];
      if (status == success) {
        List<dynamic> floorData = object['floorData'];
        List<dynamic> roomData = object['roomData'];
        List<dynamic> deviceData = object['deviceData'];
        List<dynamic> switchData = object['switchData'];
        List<dynamic> sceneData = object['sceneData'];
        List<dynamic> remoteData = object['remoteData'];
        debugPrint('voiceAssistantData: ${object['voiceAssitantData']}');
        var voiceAssitantData = object['voiceAssitantData'];

        // store floor data
        floorBox.clear().then((value) {
          for (var element in floorData) {
            debugPrint('floorData: $element');
            ModelFloor modelFloor = ModelFloor.fromJson(element);
            floorBox.add(modelFloor);
          }
        });

        // store room data
        roomBox.clear().then((value) {
          for (var element in roomData) {
            debugPrint('roomData: $element');
            ModelRoom modelRoom = ModelRoom.fromJson(element);
            roomBox.add(modelRoom);
          }
        });

        // this below line is used to reload room data when app is open
        Get.put(FloorAndRoomController()).getRoomData();

        // user setttings
        userSettingBox.clear().then((value) {
          ModelUserSettings modelUserSettings = ModelUserSettings(
              assistantVoiceType: voiceAssitantData['assistantVoiceType'],
              micEnable: voiceAssitantData['micEnable']);
          userSettingBox.add(modelUserSettings);
        });

        // store scene data
        sceneBox.clear().then((value) {
          for (var element in sceneData) {
            debugPrint('sceneData: $element');
            ModelScenes modelScenes = ModelScenes.fromJson(element);
            sceneBox.add(modelScenes);
          }
        });

        // save device data
        if (deviceBox.isNotEmpty) {
          saveDeviceAPI(false);
        }
        // store device data
        deviceBox.clear().then((value) {
          for (var element in deviceData) {
            ModelDevice modelDevice = ModelDevice.fromJson(element);
            MQTTService().subscribeDevicesToMQTT(modelDevice.mainId!);
            sendSTSCommand(modelDevice.mainId);
            deviceBox.add(modelDevice);
          }
        });

        sendSTSAndRGBCommand();

        // navigate to main screen
        // Get.off(() => MainNavigationScreen());

        // store switch data
        switchBox.clear().then((value) {
          for (var element in switchData) {
            ModelSwitches modelSwitches = ModelSwitches.fromJson(element);
            switchBox.add(modelSwitches);
          }
        });

        // store remote data with its switches
        remoteBox.clear().then((value) {
          for (var element in remoteData) {
            debugPrint('remoteData1111: $element');
            ModelRemotes modelRemotes = ModelRemotes.fromJson(element);
            remoteBox.add(modelRemotes);
          }
        });
      } else {
        httpErrorToast(statusCode: response.statusCode, toast: object['toast']);
      }
    } else if (response.statusCode == 401) {
      debugPrint('statusCode: ${response.statusCode}, body: ${response.body}');
      Fluttertoast.showToast(msg: 'Invalid Authentication Details');
    } else {
      var object = json.decode(response.body);
      httpErrorToast(
          statusCode: response.statusCode, toast: object['toast'] ?? '');
    }
  }

  void sendSTSAndRGBCommand() async {
    Box<ModelDevice> deviceBox = Hive.box(devices);
    Box<UserModel> userBox = Hive.box(userTable);
    for (int i = 0; i < deviceBox.length; i++) {
      Map<String, dynamic> cmdToSend = {};
      if (deviceBox.getAt(i)!.hardwareType!.startsWith('rgb')) {
        cmdToSend['cmd'] = Constants.RGB;
      } else {
        cmdToSend['cmd'] = Constants.STS;
      }

      cmdToSend['slave'] = deviceBox.getAt(i)!.mainId;
      cmdToSend['token'] = deviceBox.getAt(i)!.token;
      String byUser =  'M_${userBox.getAt(0)!.firstName} ${userBox.getAt(0)!.lastName}';
      cmdToSend['by'] = byUser;
      String cmd = jsonEncode(cmdToSend);
      var connectivityResult = await (Connectivity().checkConnectivity());

      // In general we are differentiating that wheather devices are in local or over internet
      // Here we don't have deviceLocal and Internet because we got fresh data from server and have to
      // check device status.
      // We assuming that if user is in wifi network then it might be in local network or over internet.
      // So, we are sending command to UDP as well as MQTT.
      if (connectivityResult == ConnectivityResult.wifi) {
        UDPService().sendUDPMessage(ip: 'BroadcastIP', message: cmd);

        Constants.isWifiHasInternet().then((value) {
          if (value) {
            MQTTService().publish(
                deviceMainId: deviceBox.getAt(i)!.mainId!, message: cmd);
          }
        });
      } else {
        MQTTService()
            .publish(deviceMainId: deviceBox.getAt(i)!.mainId!, message: cmd);
      }
    }
  }

  Future<bool> saveDeviceAPI(bool isToastRequired) async {
    debugPrint('saveDeviceAPI--------');
    bool isDeviceSaved = false;
    Box<ModelDevice> deviceBox = Hive.box(devices);
    Box<ModelSwitches> switchesBox = Hive.box(switches);
    var deviceArray = [];
    var switchArray = [];

    deviceBox.values
        .where((element) => element.operation == 'A')
        .forEach((element) {
      debugPrint('SaveDeviceApiCalledd: ${element.toJson()}');
      var deviceObject = {
        "deviceId": element.deviceId,
        "name": element.name,
        "slaveId": element.mainId,
        "openId": element.openId,
        "token": element.token,
        "encryptionKey": element.encryptionKey,
        "hardwareType": element.hardwareType,
        "totalSwitches": element.totalSwitches,
        "hardwareVersion": element.hardwareVersion,
        "wifiVersion": element.wifiVersion,
        "armVersion": element.armVersion
      };
      deviceArray.add(deviceObject);

      switchesBox.values
          .where((switches) => switches.deviceMainId == element.deviceId)
          .forEach((switches) {
        var switchObject = {
          'switchId': switches.switchId,
          'deviceId': switches.deviceMainId,
          'name': switches.name,
          'btnNum': switches.buttonNumber,
          'isFav': switches.isFav,
          'icon': switches.iconName,
          'notificationState': switches.notificationState,
          'isDimmable': switches.isDimmable,
          'dimmerType': switches.dimmerType,
          'position': switches.position,
          // 'voiceName': switches.voiceName,
          // 'roomId': switches.roomId,
          // 'sceneId': switches.sceneId,
        };
        switchArray.add(switchObject);
      });
    });

    if (deviceArray.isNotEmpty) {
      var body = jsonEncode({
        'deviceArray': deviceArray,
        'switchArray': switchArray,
      });
      debugPrint('header: ${defaultHeader()}');
      debugPrint('addDeviceSwitch_body: $body');
      debugPrint(
          'switchArray:length: ${switchArray.length}, {jsonEncode(switchArray)}');
      var response = await http.post(
        Uri.parse(deviceDetailsUrl),
        headers: defaultHeader(),
        body: body,
      );

      debugPrint(
          'addDeviceResponse: ${response.statusCode} => ${response.body}');
      var object = jsonDecode(response.body);

      if (successCodes.contains(response.statusCode)) {
        String status = object['status'];
        if (status == success) {
          if (isToastRequired) {
            Fluttertoast.showToast(msg: object['toast']);
          }
          for (var element in deviceArray) {
            String deviceId = element['deviceId'];
            deviceBox.toMap().forEach((key, value) {
              if (value.deviceId == deviceId) {
                value.operation = 'N';
                deviceBox.put(key, value);
              }
            });
          }
          if (Get.isBottomSheetOpen!) {
            isDeviceSaved = true;
            Get.back();
          }
        }
      } else {
        isDeviceSaved = false;
        if (isToastRequired) {
          Fluttertoast.showToast(msg: object['toast']);
        }
        // httpErrorToast(statusCode: response.statusCode, toast: object['toast']);
      }
    }
    return isDeviceSaved;
  }

  void loadRoomPrecacheImages(BuildContext context) {
    for (var element in groupImages) {
      precacheImage(element, context);
    }
  }

  Future<int> updateDeviceAPI(ModelDevice modelDevice) async {
    int count = 0;
    var deviceBox = Hive.box<ModelDevice>(devices);
    var body = jsonEncode({
      "deviceId": modelDevice.deviceId,
      "slaveId": modelDevice.mainId,
      "armVersion": modelDevice.armVersion
    });
    debugPrint('updateDeviceBody: $body');

    var response = await http.put(
      Uri.parse(deviceDetailsUrl),
      headers: defaultHeader(),
      body: body,
    );
    debugPrint('updateDeviceRes: ${response.body}');
    var object = jsonDecode(response.body);
    if (successCodes.contains(response.statusCode)) {
      var status = object['status'];
      if (status == success) {
        // update operation to N
        deviceBox.toMap().forEach((key, value) {
          if (value.deviceId == modelDevice.deviceId) {
            if (value.operation != 'A') {
              value.operation = 'N';
            }
            count++;
            deviceBox.put(key, value);
          }
        });
      }
    }
    return count;
  }

  void updateSceneID(String? id, ModelSwitches currentModelSwitch) {
    isWifiHasInternet().then((value) async {
      if (value) {
        // update sceneId
        var body = jsonEncode({
          "switchId": currentModelSwitch.switchId,
          "sceneId": id,
        });
        debugPrint('header-SceneController: ${defaultHeader()}');
        debugPrint('req-SceneController: $body');
        var response = await http.post(
          Uri.parse(assignSceneIdUrl),
          headers: defaultHeader(),
          body: body,
        );
        debugPrint('response-SceneController: ${response.body}');
      } else {
        // internet connection lost
      }
    });
  }

  Future<void> executeGlobalScene(ModelScenes? modelScenes) async {
    var command = modelScenes!.commandArray ?? [];
    var irCommand = modelScenes.irCommandArray ?? [];
    // debugPrint('commandLength:${command.length}');
    var deviceBox = Hive.box<ModelDevice>(devices);
    if (command.isNotEmpty) {
      for (var element in command) {
        var slave = element['slave'];

        String cmd = jsonEncode(element);
        var modelDevice =
            deviceBox.values.firstWhere((element) => element.mainId == slave);
        debugPrint('commandToSend: $cmd, modelDevice: ${modelDevice.toJson()}');

        if (Constants.devicesInLocal.contains(slave)) {
          String? receivedIP = Constants.arrayIpCache[slave];
          UDPService().sendUDPMessage(ip: receivedIP, message: cmd);
        } else if (Constants.devicesWorking.contains(slave)) {
          // mqtt
          MQTTService().publish(deviceMainId: slave, message: cmd);
        }
      }
    }

    if (irCommand.isNotEmpty) {
      int delayToSendCmd = 0;
      for (var element in irCommand) {
        var timeDelay = element['timeDelay'];
        var command = element['command'];
        var deviceMainId = command['slave'];

        delayToSendCmd = delayToSendCmd + int.parse(timeDelay!);

        Future.delayed(Duration(seconds: delayToSendCmd), () {
          String cmd = jsonEncode(command);

          if (Constants.devicesInLocal.contains(deviceMainId)) {
            String? receivedIP = Constants.arrayIpCache[deviceMainId];
            UDPService().sendUDPMessage(ip: receivedIP, message: cmd);
          } else if (Constants.devicesWorking.contains(deviceMainId)) {
            // mqtt
            MQTTService().publish(deviceMainId: deviceMainId, message: cmd);
          }
        });
      }
    }
  }

  Future<void> fetchSceneData() async {
    var response =
        await http.get(Uri.parse(sceneDetailsUrl), headers: defaultHeader());
    debugPrint('fetchSceneReq: ${defaultHeader()}');
    if (response.statusCode == 401) {
      unAuthorizedUser();
      return;
    }
    debugPrint('fetchSceneRes: ${response.body}');

    var object = jsonDecode(response.body);
    if (successCodes.contains(response.statusCode)) {
      var status = object['status'];
      var sceneData = object['sceneData'];
      if (status == success) {
        var sceneBox = Hive.box<ModelScenes>(scenes);
        for (var element in sceneData) {
          ModelScenes modelScenes = ModelScenes.fromJson(element);
          sceneBox.toMap().forEach((key, value) {
            if (value.id == modelScenes.id) {
              value.commandArray = modelScenes.commandArray;
              value.irCommandArray = modelScenes.irCommandArray;
              sceneBox.put(key, value);
            }
          });
        }
      }
    } else {
      debugPrint('error in fetch scene API');
    }
  }

  Future<void> changeFloorPositionAPI(bool isToastRequired) async {
    var allFloorData = [];
    var floorBox = Hive.box<ModelFloor>(floor);
    floorBox.toMap().forEach((key, value) {
      if (value.operation == 'U') {
        var floorObject = {"floorId": value.id, "position": value.position};
        allFloorData.add(floorObject);
      }
    });
    if (allFloorData.isNotEmpty) {
      var body = jsonEncode({'allFloorData': allFloorData});
      debugPrint('changePositon: headers: ${defaultHeader()}, body: $body');

      var response = await http.patch(
        Uri.parse(floorDetailsUrl),
        headers: defaultHeader(),
        body: body,
      );
      var object = jsonDecode(response.body);
      debugPrint('changePositionRes: $object');
      if (successCodes.contains(response.statusCode)) {
        for (var element in allFloorData) {
          floorBox.toMap().forEach((key, value) {
            if (value.id == element['floorId']) {
              value.operation = 'N';
              floorBox.put(key, value);
            }
          });
        }
        if (isToastRequired) {
          Fluttertoast.showToast(
              msg: object['toast'] ?? 'Positions changed successfully');
        }
      } else {
        httpErrorToast(statusCode: response.statusCode, toast: object['toast']);
      }
    }
  }

  Future<void> changeRoomPostionAPI(bool isToastRequired) async {
    var floorBox = Hive.box<ModelFloor>(floor);
    var roomBox = Hive.box<ModelRoom>(room);

    for (var element in floorBox.values) {
      var allRoomData = [];
      var roomJson = {};
      roomBox.toMap().forEach((key, value) {
        if (value.operation == 'U') {
          if (element.id == value.floorId) {
            allRoomData
                .add({"roomId": value.id, "roomPosition": value.position});
          }
        }
      });
      if (allRoomData.isNotEmpty) {
        roomJson['floorId'] = element.id;
        roomJson['allRoomData'] = allRoomData;
        var body = jsonEncode(roomJson);
        debugPrint('changePosition: headers: ${defaultHeader()}, body: $body');

        var response = await http.patch(
          Uri.parse(roomDetailsUrl),
          headers: defaultHeader(),
          body: body,
        );
        var object = jsonDecode(response.body);
        debugPrint('changePositionRes: $object');
        if (successCodes.contains(response.statusCode)) {
          var status = object['status'];
          if (status == success) {
            for (var element in allRoomData) {
              roomBox.toMap().forEach((key, value) {
                if (value.id == element['roomId']) {
                  value.operation = 'N';
                  roomBox.put(key, value);
                }
              });
            }
            if (isToastRequired) {
              Fluttertoast.showToast(
                  msg: object['toast'] ?? 'Positions changed successfully');
            }
          } else {
            debugPrint('statusFail: ${response.statusCode}');
          }
        } else {
          httpErrorToast(
              statusCode: response.statusCode, toast: object['toast']);
        }
      }
    }
  }

  Future<void> changeSwitchPostionAPI(bool isToastRequired) async {
    var roomBox = Hive.box<ModelRoom>(room);
    var switchesBox = Hive.box<ModelSwitches>(switches);

    for (var modelRoom in roomBox.values) {
      var allSwitchData = [];
      var switchJson = {};
      switchesBox.toMap().forEach((key, value) {
        if (value.operation == 'U') {
          if (modelRoom.id == value.roomId) {
            allSwitchData.add({
              'switchPosition': value.position,
              'switchId': value.switchId,
            });
          }
        }
      });
      if (allSwitchData.isNotEmpty) {
        switchJson['roomId'] = modelRoom.id;
        switchJson['allSwitchArray'] = allSwitchData;
        var body = jsonEncode(switchJson);
        debugPrint('changePosition: headers: ${defaultHeader()}, body: $body');

        var response = await http.patch(
          Uri.parse(editSwitchUrl),
          headers: defaultHeader(),
          body: body,
        );
        debugPrint(
            'response_body: code: ${response.statusCode}, ${response.body}');
        var object = jsonDecode(response.body);
        if (successCodes.contains(response.statusCode)) {
          String status = object['status'];
          if (status == success) {
            for (var element in allSwitchData) {
              switchesBox.toMap().forEach((key, value) {
                if (value.roomId == element['roomId']) {
                  value.operation = 'N';
                  switchesBox.put(key, value);
                }
              });
            }
            if (isToastRequired) {
              Fluttertoast.showToast(
                  msg: object['toast'] ?? 'Position changed successfully');
            }
          }
        } else {
          httpErrorToast(
              statusCode: response.statusCode, toast: object['toast']);
        }
      }
    }
  }

  Future<void> changeRemotePositionAPI(bool isToastRequired) async {
    // var allRemoteData = [];
    var roomBox = Hive.box<ModelRoom>(room);
    var remoteBox = Hive.box<ModelRemotes>(remotes);

    for (var modelRoom in roomBox.values) {
      var allRemoteData = [];
      var remoteJson = {};
      remoteBox.toMap().forEach((key, value) {
        if (value.operation == 'U') {
          if (modelRoom.id == value.roomId) {
            allRemoteData
                .add({'remotePosition': value.position, 'remoteId': value.id});
          }
        }
      });
      if (allRemoteData.isNotEmpty) {
        remoteJson['roomId'] = modelRoom.id;
        remoteJson['allRemoteArray'] = allRemoteData;
        var body = jsonEncode(remoteJson);
        debugPrint('changePosition: headers: ${defaultHeader()}, body: $body');

        var response = await http.put(
          Uri.parse(changeRemotePositionUrl),
          headers: defaultHeader(),
          body: body,
        );
        debugPrint(
            'changePosition:response: code: ${response.statusCode}, ${response.body}');
        var object = jsonDecode(response.body);
        if (successCodes.contains(response.statusCode)) {
          String status = object['status'];
          if (status == success) {
            for (var element in allRemoteData) {
              remoteBox.toMap().forEach((key, value) {
                if (value.roomId == element['roomId']) {
                  value.operation = 'N';
                  remoteBox.put(key, value);
                }
              });
            }
            if (isToastRequired) {
              Fluttertoast.showToast(
                  msg: object['toast'] ?? 'Position changed successfully');
            }
          }
        } else {
          httpErrorToast(
              statusCode: response.statusCode, toast: object['toast']);
        }
      }
    }
  }

  Future<void> changeScenePositionAPI(bool isToastRequired) async {
    var sceneBox = Hive.box<ModelScenes>(scenes);
    var allSceneData = [];

    sceneBox.toMap().forEach((key, value) {
      var floorObject = {
        "sceneId": value.id,
        "scenePosition": value.position.toString()
      };
      allSceneData.add(floorObject);
    });
    if (allSceneData.isNotEmpty) {
      var body = jsonEncode({'allSceneArray': allSceneData});
      debugPrint('changePositon: headers: ${defaultHeader()}, body: $body');

      var response = await http.patch(
        Uri.parse(sceneDetailsUrl),
        headers: defaultHeader(),
        body: body,
      );
      var object = jsonDecode(response.body);
      debugPrint('changePositionRes: $object');
      if (successCodes.contains(response.statusCode)) {
        if (isToastRequired) {
          Fluttertoast.showToast(
              msg: object['toast'] ?? 'Positions changed successfully');
        }
      } else {
        httpErrorToast(statusCode: response.statusCode, toast: object['toast']);
      }
    }
  }

  Future isMajorAppUpdate() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    debugPrint("package info ${packageInfo.version}");
    var body = {"appVersion": packageInfo.version};
    debugPrint("dataaaa${packageInfo.version}");
    var response = await http.post(
      Uri.parse(forceAppUpdateUrl),
      headers: defaultHeader(),
      body: json.encode(body),
    );
    var data = ForceAppUpdateModel.fromJson(json.decode(response.body));
    if (GetPlatform.isAndroid) {
      if (data.android?.majorUpdate != null) {
        return true;
      }else if(data.android?.minorUpdate != null){
        return false;
      }
    } else {
      if (data.ios!.majorUpdate != null) {
        return true;
      }else if(data.ios!.minorUpdate != null){
        return false;
      }
    }

    return 0;
  }

  Widget forceUpdateScreen() {
    var controller = Get.put(MainNavigationController());
    return WillPopScope(
      onWillPop: () async {
        Get.back();
        controller.isFAUDOpen.value = false;
        return false;
      },
      child: AppUpdateDialog(
        key: const Key("Force App Update"),
        title: "Update Available",
        description: 'To use this app download the latest version',
        negativeBtnName: '',
        onNegativeBtnPress: () {},
        positivieBtnName: 'Update',
        onPositiveBtnPress: () {
          StoreRedirect.redirect(
              androidAppId: "com.vdt.smartnode", iOSAppId: "1364981811");
          controller.isFAUDOpen.value = false;
          Get.back();
        },
      ),
    );
  }

// Future<void> getAppUpdate() async {
//   if (isMinorUpdate && !isUpdatePromptShown) {
//     isUpdatePopup = true;
//     showModalBottomSheet(
//       backgroundColor: Colors.transparent,
//       context: context,
//       elevation: 10,
//       builder: (buildContext) => AppUpdateDialog(
//         title: "Update Available",
//         description:
//         'You need to update ${Constants.appName} app to explore new feature.',
//         negativeBtnName: 'Cancel',
//         onNegativeBtnPress: () => Navigator.pop(buildContext),
//         positivieBtnName: 'Update',
//         onPositiveBtnPress: () {
//           StoreRedirect.redirect(
//               androidAppId: "com.vdt.smartnode", iOSAppId: "1364981811");
//           Navigator.pop(buildContext);
//         },
//       ),
//     ).then((value) => isUpdatePopup = true);
//     isUpdatePromptShown = true;
//   }
//
//   if (isForceUpdate) {
//     isUpdatePopup = true;
//
//     showModalBottomSheet(
//       backgroundColor: Colors.transparent,
//       context: context,
//       isDismissible: false,
//       isScrollControlled: true,
//       enableDrag: false,
//       elevation: 10,
//       builder: (buildContext) => forceUpdateScreen(),
//     ).then((value) => isUpdatePopup = false);
//   }
//   isUpdatePopup = false;
// }
//   Future _download(String url) async {
//     var awsAuth = {
//
//
//     };
//     final response = await http.get(Uri.parse(url),
//         headers: <String, String>{'authorization': basicAuth});
//
//     // Get the image name
//     final imageName = path.basename(url);
//     // Get the document directory path
//
//
//   }

   Future getAWSHeader(String url)  async{
    const String hostName = 'productionsmartnnode.s3.ap-south-1.amazonaws.com';
    const String region = 'ap-south-1';
    final serviceConfiguration = S3ServiceConfiguration();

    const signer = AWSSigV4Signer(
      credentialsProvider: AWSCredentialsProvider.environment(),
    );
    final scope = AWSCredentialScope(
      region: region,
      service: AWSService.s3,
    );
    final urlRequest = AWSHttpRequest.get(
      Uri.https(hostName, url.split("/").last),
      headers: const {
        AWSHeaders.host: hostName,
      },
    );
    final signedUrl = await signer.presign(
      urlRequest,
      credentialScope: scope,
      serviceConfiguration: serviceConfiguration,
      expiresIn: const Duration(seconds: 30),
    );
    return signedUrl;
  }
}
String baseUrl() => SharedPreferenceManager.isLocalUrl()  ? 'http://10.10.10.102:5000/api/${apiVersion[0]}': 'https://api.smartnode.in/api/${apiVersion[0]}';
 String v2BaseUrl() => SharedPreferenceManager.isLocalUrl()   ? 'http://10.10.10.102:5000/api/${apiVersion[1]}' : 'https://api.smartnode.in/api/${apiVersion[1]}';
//build_run_number=128
