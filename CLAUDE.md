# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OpenCode Mobile is a Flutter mobile client for the [OpenCode](https://github.com/opencode-ai/opencode) AI assistant server. The server code is located at `../opencode` relative to this repository. The app connects to a running `opencode serve` instance (default `http://localhost:4096`) and provides a mobile interface for chatting with the AI, viewing tool executions, managing sessions, and handling permission requests.

## Devenv Environment

This project uses [devenv](https://devenv.sh/) for reproducible development environments. Before running any Flutter commands, check if you're in a devenv shell:

- If the environment variable `IN_NIX_SHELL` is set, you're already in a devenv shell
- If not, prefix all commands with `devenv shell`:
  ```bash
  devenv shell flutter pub get
  devenv shell flutter run
  ```

## Testing

Testing is required. All changes must pass `flutter analyze` and `flutter test` before being considered complete. Do not skip these steps.

For UI and integration work, always build and test on a real Android device. The emulator does not reliably reproduce Cronet behavior, network security config, or real-world performance, so changes that only pass on the emulator are not considered tested.

When writing tests, write general-purpose solutions. Do not hard-code values or create solutions that only work for specific test inputs. If a test is incorrect or infeasible, flag it rather than working around it.

## Working with Code

Read the relevant source files before making changes. Do not speculate about code you have not opened. If a file is referenced, open it and verify its structure before editing.

When making changes, implement them directly rather than only suggesting them. Keep changes focused on what was requested — do not add features, refactor surrounding code, or introduce abstractions beyond what is needed.

If you create temporary files or scripts during development, clean them up before finishing.

## Commands

```bash
flutter pub get                          # Install dependencies
flutter analyze                          # Static analysis (CI uses --no-fatal-infos)
flutter test                             # Run all tests
flutter test test/integration/api_connection_test.dart  # Run a single test file
flutter run                              # Run on connected device (always prefer a real device)
flutter build apk --release              # Build Android APK -> build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle --release        # Build Android App Bundle
```

### Integration Tests

Integration tests live in `test/integration/` and require a running OpenCode server (start one with `cd ../opencode && go run ./cmd/opencode serve`). They are run as unit tests (not device tests) with `--dart-define`:

```bash
flutter test --dart-define=SERVER_URL=http://localhost:4096 test/integration/
```

## Architecture

### Data Flow

The app follows a unidirectional data flow: UI -> Provider (Notifier) -> API Client -> Server. Real-time updates flow back via Server -> SSE Client -> StreamProvider -> UI.

### Singleton Services

`OpenCodeClient`, `SSEClient`, `StorageService`, and `PlatformHttpClient` are all singletons (private constructor + factory). They are accessed directly (e.g., `OpenCodeClient()`) rather than through dependency injection.

### State Management (Riverpod)

All providers use `Notifier` + `NotifierProvider` pattern with immutable state classes using `copyWith`. Each state class (`ChatState`, `SessionsState`, `ConnectionState`, etc.) holds `isLoading`, `error`, and domain data.

Key providers in `lib/core/providers/`:
- `connectionProvider` — manages server connection lifecycle; `ConnectionGate` widget in `main.dart` gates all routes behind connection
- `chatProvider` — single global instance for current chat (messages loaded per sessionId via method calls, not provider families)
- `sessionsProvider` — session list with CRUD operations
- `projectsProvider` — project listing
- `permissionsProvider` — pending tool permission requests from the AI
- `modelSelectionProvider` — persisted provider/model selection

SSE streams are exposed as `StreamProvider`s (e.g., `sseMessageProvider`, `sseSessionUpdateProvider`, `ssePermissionProvider`) and consumed via `ref.listen` in screens.

### Real-Time Events (SSE)

`SSEClient` manages two types of SSE connections:
- Global (`/global/event`): installation updates, server lifecycle
- Per-project (`/event?directory=...`): message updates, session CRUD, permission requests, file edits

Events are dispatched to typed broadcast `StreamController`s. The client handles reconnection with exponential backoff (max 5 attempts).

### HTTP Client

`PlatformHttpClient` (`lib/core/http/http_client.dart`) uses Cronet on Android to honor user-installed CA certificates (critical for self-signed certs). Falls back to `dart:io` `http.Client` on other platforms or if Cronet fails. Both `OpenCodeClient` (REST) and `SSEClient` (streaming) use this shared client.

### Routing

GoRouter with a `ConnectionGate` wrapper widget — all routes redirect to `ConnectionScreen` when not connected:
- `/` and `/projects` — project list
- `/sessions?projectId=` — session list (filtered by project)
- `/chat/:sessionId` — chat interface
- `/settings` — app settings with theme control

### Message Model

Messages contain typed `MessagePart`s: `text`, `reasoning`, `tool` (with state machine: pending -> running -> completed/error), `file`, `stepStart`/`stepFinish`, `snapshot`, `patch`, `error`. The server uses camelCase JSON keys like `sessionID`, `parentID`, `providerID`.

## Android-Specific Notes

- Cleartext HTTP traffic enabled in `AndroidManifest.xml` for local development
- Network security config trusts both system and user CA certificates
- Java 17 required for building

## CI

GitHub Actions at `.github/workflows/ci.yml` runs: analyze -> unit tests -> build APK + AAB (parallel after tests pass). Artifacts uploaded with 30-day retention.
