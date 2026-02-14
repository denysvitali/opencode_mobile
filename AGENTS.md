# AGENTS.md - Developer Guide for AI Agents

This file provides guidance for AI coding agents operating in this repository.

## Project Overview

OpenCode Mobile is a Flutter mobile client for the OpenCode AI assistant server. It connects to a running `opencode serve` instance and provides a mobile interface for chatting with the AI.

## Environment Setup

This project uses [devenv](https://devenv.sh/) for reproducible development environments.

```bash
# Check if in devenv shell
echo $IN_NIX_SHELL

# If not in devenv, prefix commands with:
devenv shell <command>
```

## Build, Lint & Test Commands

### Flutter Commands (use `devenv shell` if not in nix shell)

```bash
# Install dependencies
flutter pub get

# Run the app (requires connected device/emulator)
flutter run

# Run static analysis/linting
flutter analyze

# Run all tests
flutter test

# Run a single test file
flutter test test/models/session_test.dart

# Run a single test by name
flutter test test/models/session_test.dart --name "fromJson parses"

# Run specific test directories
flutter test test/models/      # Model unit tests
flutter test test/widgets/     # Widget tests
flutter test test/integration/ # Integration tests (requires mock server)

# Build Android APK
flutter build apk --release

# Build Android App Bundle
flutter build appbundle --release

# APK output location: build/app/outputs/flutter-apk/app-release.apk
```

### CI Test Command
```bash
flutter test --no-pub test/  # Run all tests without pub (used in CI)
```

## Code Style Guidelines

### General Conventions

- **Language**: Dart with Flutter
- **State Management**: Riverpod 3.x with Notifier pattern
- **Architecture**: Clean Architecture (UI → Providers → API → Models)
- **Target Platform**: Android (primary), iOS compatible

### Imports

```dart
// Order: package imports first, then relative imports
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/session.dart';      // Relative import from feature
import 'package:opencode_mobile/core/api/...'; // Package import for core
```

### Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| Files | snake_case | `session_provider.dart`, `message_bubble.dart` |
| Classes | PascalCase | `SessionsNotifier`, `MessageBubble` |
| Enums | PascalCase | `SessionStatus`, `MessageRole` |
| Enum values | camelCase | `SessionStatus.idle`, `MessageRole.assistant` |
| Constants | camelCase | `maxRetries`, `defaultTimeout` |
| Private members | _camelCase | `_sessions`, `_loadData()` |
| Providers | suffix with Provider/Notifier | `sessionsProvider`, `connectionNotifier` |

### Data Models

Models are located in `lib/core/models/` and follow this pattern:

```dart
class Session {
  final String id;
  final String? title;
  final SessionStatus status;

  Session({
    String? id,
    this.title,
    this.status = SessionStatus.idle,
  }) : id = id ?? const Uuid().v4();

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] as String?,
      status: _parseStatus(json['status'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'status': status.name,
    };
  }

  Session copyWith({String? title}) {
    return Session(
      id: id,
      title: title ?? this.title,
      status: status,
    );
  }
}
```

### Providers (Riverpod)

Providers are in `lib/core/providers/` and use the Notifier pattern:

```dart
class SessionsState {
  final List<Session> sessions;
  final bool isLoading;
  final String? error;

  SessionsState({
    this.sessions = const [],
    this.isLoading = false,
    this.error,
  });

  SessionsState copyWith({
    List<Session>? sessions,
    bool? isLoading,
    String? error,
  }) {
    return SessionsState(
      sessions: sessions ?? this.sessions,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class SessionsNotifier extends Notifier<SessionsState> {
  @override
  SessionsState build() {
    return SessionsState();
  }

  Future<void> loadSessions() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final sessions = await OpenCodeClient().listSessions();
      state = state.copyWith(sessions: sessions, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final sessionsProvider = NotifierProvider<SessionsNotifier, SessionsState>(() {
  return SessionsNotifier();
});
```

### Error Handling

- Use try-catch in async methods
- Store errors in state objects
- Display errors via SnackBar or error widgets
- Use custom exceptions for API errors:

```dart
class OpenCodeException implements Exception {
  final String message;
  final int? statusCode;
  OpenCodeException(this.message, [this.statusCode]);
  
  @override
  String toString() => 'OpenCodeException: $message (status: $statusCode)';
}
```

### Widgets

- Use `const` constructors when possible
- Extract complex widgets into separate files
- Follow Flutter's widget composition patterns
- Use ConsumerWidget/ConsumerStatefulWidget for Riverpod integration

```dart
class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});
  
  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sessionsProvider);
    // ...
  }
}
```

### Feature Structure

Features are organized in `lib/features/` by domain:
- `connection/` - Server connection UI
- `sessions/` - Session list and creation
- `chat/` - Chat interface
- `settings/` - App settings

Each feature contains:
- Main screen widget
- `widgets/` subdirectory for components

### Testing

Tests are in `test/`:
- `test/models/` - Model unit tests (42 tests)
- `test/widgets/` - Widget tests (29 tests)
- `test/integration/` - API integration tests
- `test/mock_opencode_server.ts` - Mock server for integration tests

Test naming: `<feature>_test.dart`

```dart
void main() {
  group('Session', () {
    test('fromJson parses basic session', () {
      final json = {'id': 'test', 'status': 'running'};
      final session = Session.fromJson(json);
      expect(session.id, 'test');
      expect(session.status, SessionStatus.running);
    });
  });
}
```

### Git Conventions

- Use meaningful commit messages
- Branch naming: `feature/description` or `fix/description`
- Run tests before committing
- CI runs: analyze, model-test, widget-test, integration-test, build-apk, build-aab

### Android-Specific Notes

- Cleartext traffic enabled in `AndroidManifest.xml` for HTTP development
- Network security config trusts system/user CA certificates
- Minimum SDK controlled by Flutter defaults
- Java 17 required for building
