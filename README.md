# OpenCode Mobile

A Flutter mobile client for [OpenCode](https://github.com/opencode-ai/opencode) AI assistant.

## Features

- Connect to OpenCode server (`opencode serve`)
- Browse and manage chat sessions
- Send messages and receive AI responses
- Real-time updates via Server-Sent Events
- View tool executions (bash, edit, read, write, etc.)
- Dark and light theme support

## Getting Started

### Prerequisites

- Flutter SDK >= 3.22.0
- Android SDK (for Android builds)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/denysvitali/opencode_mobile.git
   cd opencode_mobile
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

### Building APK

```bash
flutter build apk --release
```

The APK will be available at `build/app/outputs/flutter-apk/app-release.apk`.

## Usage

1. Start your OpenCode server:
   ```bash
   opencode serve
   ```

2. Open the app and enter the server URL (default: `http://localhost:4096`)

3. If your server has authentication enabled, enter your username and password

4. Tap "Connect" to establish the connection

5. Create a new session or select an existing one to start chatting

## Configuration

### Server Authentication

The app supports HTTP Basic Authentication. Configure your OpenCode server with:

```bash
export OPENCODE_SERVER_PASSWORD=your_password
opencode serve
```

Then use the same credentials in the app.

## Development

### Project Structure

```
lib/
├── main.dart                    # App entry point
├── core/
│   ├── api/                     # HTTP and SSE clients
│   ├── models/                  # Data models
│   ├── providers/               # Riverpod state providers
│   ├── services/                # Storage and utilities
│   └── utils/                   # Theme helpers
└── features/
    ├── connection/              # Server connection UI
    ├── sessions/                # Session list and management
    ├── chat/                    # Chat interface
    └── settings/                # App settings
```

### Running Tests

```bash
flutter test
```

### Code Analysis

```bash
flutter analyze
```

## License

MIT License
