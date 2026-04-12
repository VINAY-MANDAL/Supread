#!/bin/bash

# Set JAVA_HOME
export JAVA_HOME="C:/Program Files/Android/Android Studio/jbr"
export PATH="$JAVA_HOME/bin:$PATH"

# Navigate to the directory where the script is located
cd "$(dirname "$0")"

echo "Starting APK build..."
flutter clean
flutter build apk --release --split-per-abi

if [ -f "build/app/outputs/apk/release/app-release.apk" ]; then
    echo "SUCCESS: APK built successfully!"
    ls -lh build/app/outputs/apk/release/app-release.apk
else
    echo "ERROR: APK not found. Build may have failed."
    exit 1
fi
