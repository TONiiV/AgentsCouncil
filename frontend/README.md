# AgentsCouncil Frontend

Flutter app for the AgentsCouncil multi-AI debate platform.

## Setup

1. Install Flutter: https://docs.flutter.dev/get-started/install
2. Run setup:

   ```bash
   flutter pub get
   ```

3. Run on macOS:
   ```bash
   flutter run -d macos
   ```

## Requirements

- Flutter 3.2.0 or higher
- Dart SDK 3.2.0 or higher
- macOS 10.14 or higher (for macOS builds)

## Project Structure

```
lib/
├── main.dart              # App entry point
├── app/
│   ├── config.dart       # API configuration
│   └── theme.dart        # App theme
├── models/
│   └── models.dart       # Data models
├── services/
│   ├── api_service.dart  # REST API client
│   └── websocket_service.dart  # Real-time updates
└── features/
    ├── home/             # Home screen
    ├── council/          # Council setup
    └── debate/           # Debate view
```

## Platform Support

- ✅ macOS (primary)
- ⏳ Windows (Phase 2)
- ⏳ iOS (Phase 2)
- ⏳ Android (Phase 2)
