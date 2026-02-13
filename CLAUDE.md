# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OpenCode Mobile is a Flutter mobile client for the [OpenCode](https://github.com/opencode-ai/opencode) AI assistant server. It connects to a running `opencode serve` instance and provides a mobile interface for chatting with the AI, viewing tool executions, and managing sessions.

## Devenv Environment

This project uses [devenv](https://devenv.sh/) for reproducible development environments. Before running any Flutter commands, check if you're in a devenv shell:

- If the environment variable `IN_NIX_SHELL` is set, you're in a devenv shell
- If not, prefix all commands with `devenv shell`:
  ```bash
  devenv shell flutter pub get
  devenv shell flutter run
  ```

## Commands

### Development
```bash
flutter pub get          # Install dependencies
flutter run              # Run the app (requires connected device/emulator)
flutter analyze          # Run static analysis/linting
flutter test             # Run tests
```

### Building
```bash
flutter build apk --release              # Build Android APK
flutter build appbundle --release        # Build Android App Bundle
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`

## Architecture

### State Management
- **Riverpod 3.x** with Notifier pattern for all providers
- Providers are in `lib/core/providers/`
- Provider families used for parameterized providers (e.g., session-specific state)

### Routing
- **GoRouter** for declarative routing
- Routes defined in `main.dart`:
  - `/` - Redirects to sessions list
  - `/sessions` - Session list screen
  - `/chat/:sessionId` - Chat screen for a specific session
  - `/settings` - App settings

### HTTP Client
- Uses **Cronet HTTP** on Android to honor user-installed CA certificates (important for self-signed certs in development)
- Falls back to standard HTTP client if Cronet fails
- HTTP client wrapper in `lib/core/http/http_client.dart`

### API Layer
- `OpenCodeClient` (`lib/core/api/opencode_client.dart`): REST API client for server communication
- `SSEClient` (`lib/core/api/sse_client.dart`): WebSocket-based Server-Sent Events for real-time message streaming

### Data Models
- Located in `lib/core/models/`
- Use `fromJson`/`toJson` serialization
- Key models: `Session`, `Message`, `Config`, `Permission`, `Project`

### Storage
- `SharedPreferences`: Server URL, username, theme preference
- `FlutterSecureStorage`: Passwords (encrypted on device)

## Feature Structure

Features are organized in `lib/features/` by domain:
- `connection/`: Server connection UI and configuration
- `sessions/`: Session list and creation dialog
- `chat/`: Chat interface with message bubbles and tool cards
- `settings/`: App settings screen

Each feature typically contains:
- A main screen/widget
- A `widgets/` subdirectory for composed components

## Server Connection

The app connects to an OpenCode server running `opencode serve`. Default URL is `http://localhost:4096`. The server may have HTTP Basic Authentication enabled via `OPENCODE_SERVER_PASSWORD` environment variable.

## Android-Specific Notes

- Cleartext traffic is enabled in `AndroidManifest.xml` for HTTP development
- Network security config trusts system and user CA certificates
- Minimum SDK version is controlled by Flutter's default
- Java 17 is required for building

## CI/CD

GitHub Actions workflow at `.github/workflows/build.yml`:
1. Runs `flutter analyze`
2. Runs `flutter test --no-pub`
3. Builds APK and App Bundle
