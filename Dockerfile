# Use an official Flutter runtime as a parent image
FROM ghcr.io/cirruslabs/flutter:3.7.8

# Update package lists
RUN apt-get update -y

# Install dependencies
RUN apt-get install -y curl git unzip xz-utils zip libglu1-mesa apache2

# Install Flutter
RUN git clone https://github.com/flutter/flutter.git /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:${PATH}"

# Run Flutter doctor to download required tools
RUN flutter doctor
