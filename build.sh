#!/bin/bash

# Set JAVA_HOME
export JAVA_HOME="C:\\Program Files\\Android\\Android Studio\\jbr"
export PATH="$JAVA_HOME/bin:$PATH"

cd E:/pdf_reader_flutter

echo "Starting APK build..."
flutter build apk --release --no-shrink

if [ -f "build/app/outputs/apk/release/app-release.apk" ]; then
    echo "SUCCESS: APK built successfully!"
    ls -lh build/app/outputs/apk/release/app-release.apk
else
    echo "ERROR: APK not found. Build may have failed."
    exit 1
fi
