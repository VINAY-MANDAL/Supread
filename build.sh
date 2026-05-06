#!/bin/bash

# Set JAVA_HOME
export JAVA_HOME="C:/Program Files/Android/Android Studio/jbr"
export PATH="$JAVA_HOME/bin:$PATH"

# Set Gradle memory to prevent OOM/Daemon errors
export GRADLE_OPTS="-Xmx2048m -Dorg.gradle.jvmargs=-Xmx2048m"
export JAVA_OPTS="-Xmx2048m"

# Navigate to the directory where the script is located
cd "$(dirname "$0")"

echo "Running flutter clean..."
flutter clean || exit 1

echo "Killing background Java processes..."
pkill -f java || true
sleep 2

echo "Manually removing build and cache folders..."
rm -rf build
rm -rf android/.gradle
rm -rf .dart_tool

echo "Fetching dependencies..."
flutter pub get || exit 1

echo "Starting APK build (Release mode) with --no-daemon..."
# Using --no-daemon helps avoid file locking issues in some environments
if flutter build apk --release --no-daemon --verbose > build_log.txt 2>&1; then
    echo "Build successful!"
else
    echo "-----------------------------------------------------------------------"
    echo "BUILD FAILED! Printing last 20 lines of build_log.txt:"
    echo "-----------------------------------------------------------------------"
    tail -n 20 build_log.txt
    echo "-----------------------------------------------------------------------"
    echo "Full log saved to build_log.txt"
    exit 1
fi
