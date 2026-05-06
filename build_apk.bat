@echo off
setlocal enabledelayedexpansion

echo Setting up environment...
:: Use quotes to handle spaces in the path
set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
set "PATH=%JAVA_HOME%\bin;%PATH%"

:: Set Gradle memory to prevent "Daemon compilation failed: null"
set "GRADLE_OPTS=-Xmx2048m -Dorg.gradle.jvmargs=-Xmx2048m"
set "JAVA_OPTS=-Xmx2048m"

echo JAVA_HOME: %JAVA_HOME%
java -version
if %ERRORLEVEL% NEQ 0 (
    echo Error: Java was not found. Please check your JAVA_HOME path.
    pause
    exit /b 1
)

echo.
cd /d "%~dp0"

echo Forcefully killing any hanging processes to release file locks...
:: This ensures no background process is locking the build folders
taskkill /f /fi "IMAGENAME eq java.exe" /t >nul 2>&1
taskkill /f /fi "IMAGENAME eq kotlinc.exe" /t >nul 2>&1
taskkill /f /fi "IMAGENAME eq gradle.exe" /t >nul 2>&1

:: Wait a second for processes to release handles
timeout /t 2 /nobreak >nul

:: Fix for PowerShell redirection encoding issues (removes null bytes)
set "BUILD_LOG=build_log.txt"
echo Stopping Gradle daemons...
if exist "android\gradlew.bat" (
    pushd android
    call gradlew.bat --stop
    popd
)

echo Cleaning project...
call flutter clean

echo Manually removing build and cache folders...
:: Using a loop to retry deletion if it's still locked
if exist "build" (
    rd /s /q "build" || (echo Waiting for build folder to unlock... && timeout /t 3 && rd /s /q "build")
)
if exist "android\.gradle" rd /s /q "android\.gradle"
if exist ".dart_tool" rd /s /q ".dart_tool"

echo Fetching project dependencies...
call flutter pub get
echo Building APK (Release mode) with --no-daemon...
:: Using --no-daemon to prevent Kotlin compiler from locking cache files
call flutter build apk --release --no-daemon --verbose > %BUILD_LOG% 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo -----------------------------------------------------------------------
    echo BUILD FAILED! Printing last 20 lines of build_log.txt:
    echo -----------------------------------------------------------------------
    powershell -Command "Get-Content build_log.txt -Tail 20"
    echo -----------------------------------------------------------------------
    echo Full log saved to build_log.txt
) else (
    echo.
    echo Build complete! Check build\app\outputs\apk\release\ for the APK file.
)
pause
