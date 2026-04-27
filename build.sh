#!/bin/bash

# Set JAVA_HOME
export JAVA_HOME="C:/Program Files/Android/Android Studio/jbr"
export PATH="$JAVA_HOME/bin:$PATH"

# Navigate to the directory where the script is located
cd "$(dirname "$0")"

echo "Starting APK build..."
flutter clean
flutter build apk --release --split-per-abi

