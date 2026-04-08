# Readora - Cross-Platform PDF Reader

A beautiful and modern PDF reader built with Flutter that works on multiple platforms.

## Supported Platforms

- 🌐 **Web** - Run in any modern web browser
- 📱 **Android** - Native Android app
- 🍎 **iOS** - Native iOS app
- 🖥️ **Windows** - Desktop application
- 🐧 **Linux** - Desktop application
- 🍎 **macOS** - Desktop application

## Features

- 📂 File picker integration for all platforms
- 📖 Modern PDF viewing with Syncfusion PDF Viewer
- 📱 Responsive design for mobile and desktop
- 🌙 Clean, intuitive user interface
- 💾 Recent files tracking
- 🔍 Page navigation and zoom controls

## Platform-Specific Notes

### Web Platform
- File picker works with drag & drop or click to select
- PDF viewing interface is currently under development
- Files are stored in browser local storage

### Desktop Platforms (Windows, Linux, macOS)
- Native file picker integration
- Full PDF viewing capabilities
- Local file system access

### Mobile Platforms (Android, iOS)
- Native file picker integration
- Optimized for touch interfaces
- Full PDF viewing capabilities

## Getting Started

### Prerequisites
- Flutter SDK (3.0.0 or higher)
- Dart SDK
- For mobile development: Android Studio / Xcode
- For web development: Any modern web browser

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd readora_flutter
```

2. Install dependencies:
```bash
flutter pub get
```

3. Enable platforms (if not already enabled):
```bash
flutter config --enable-web
flutter config --enable-windows-desktop
flutter config --enable-linux-desktop
flutter config --enable-macos-desktop
```

### Running the App

#### Web
```bash
flutter run -d web-server
# or
flutter run -d chrome
```

#### Android
```bash
flutter run -d android
```

#### iOS (macOS only)
```bash
flutter run -d ios
```

#### Windows
```bash
flutter run -d windows
```

#### Linux
```bash
flutter run -d linux
```

#### macOS
```bash
flutter run -d macos
```

## Building for Production

### Web
```bash
flutter build web
```

### Android APK
```bash
flutter build apk
```

### iOS
```bash
flutter build ios
```

### Desktop
```bash
flutter build windows
flutter build linux
flutter build macos
```

## Dependencies

- `file_picker`: Cross-platform file picking
- `syncfusion_flutter_pdfviewer`: PDF viewing (native platforms)
- `shared_preferences`: Local data storage
- `path_provider`: File system access
- `universal_io`: Cross-platform I/O operations

## Architecture

The app follows a clean architecture pattern:

- `lib/models/`: Data models
- `lib/services/`: Business logic and external services
- `lib/screens/`: UI screens and pages
- `lib/widgets/`: Reusable UI components

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on multiple platforms
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.