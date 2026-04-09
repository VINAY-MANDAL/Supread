@echo off
setlocal enabledelayedexpansion

echo Setting up environment...
set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr
set PATH=%JAVA_HOME%\bin;%PATH%

echo JAVA_HOME: %JAVA_HOME%
java -version

echo.
echo Building APK...
cd /d E:\pdf_reader_flutter
call flutter build apk --release

echo.
echo Build complete! Check build\app\outputs\apk\release\ for the APK file.
pause
