@echo off
echo Readora - Cross-Platform PDF Reader
echo ===================================
echo.
echo Choose a platform to run:
echo 1. Web (Browser)
echo 2. Android
echo 3. iOS (macOS only)
echo 4. Windows
echo 5. Linux
echo 6. macOS
echo.
set /p choice="Enter your choice (1-6): "

if "%choice%"=="1" (
    echo Starting web version...
    flutter run -d web-server
) else if "%choice%"=="2" (
    echo Starting Android version...
    flutter run -d android
) else if "%choice%"=="3" (
    echo Starting iOS version...
    flutter run -d ios
) else if "%choice%"=="4" (
    echo Starting Windows version...
    flutter run -d windows
) else if "%choice%"=="5" (
    echo Starting Linux version...
    flutter run -d linux
) else if "%choice%"=="6" (
    echo Starting macOS version...
    flutter run -d macos
) else (
    echo Invalid choice. Please run again and select 1-6.
    pause
)