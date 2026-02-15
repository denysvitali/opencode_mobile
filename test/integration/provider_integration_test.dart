import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/http/http_client.dart';
import 'package:opencode_mobile/core/models/config.dart';
import 'package:opencode_mobile/core/models/message.dart';
import 'package:opencode_mobile/core/models/session.dart';
import 'package:opencode_mobile/core/providers/chat_provider.dart';
import 'package:opencode_mobile/core/providers/model_selection_provider.dart';
import 'package:opencode_mobile/core/providers/project_provider.dart';
import 'package:opencode_mobile/core/providers/sessions_provider.dart';
import 'package:opencode_mobile/core/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const serverUrl = String.fromEnvironment('SERVER_URL');

  late OpenCodeClient client;

  setUpAll(() async {
    if (serverUrl.isEmpty) {
      fail('SERVER_URL must be provided via --dart-define=SERVER_URL=<url>');
    }

    await platformHttpClient.initialize();

    client = OpenCodeClient();
    await client.initialize(config: ServerConfig(url: serverUrl));

    // StorageService is needed by ModelSelectionNotifier
    try {
      await StorageService().initialize();
    } catch (_) {
      // SharedPreferences may not initialize in pure test environments
    }
  });

  tearDownAll(() {
    platformHttpClient.close();
  });

  group('SessionsProvider', () {
    testWidgets('loadSessions populates state', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initial state
      final initial = container.read(sessionsProvider);
      expect(initial.isLoading, isFalse);
      expect(initial.sessions, isEmpty);
      expect(initial.error, isNull);

      // Load sessions
      await container.read(sessionsProvider.notifier).loadSessions();

      final loaded = container.read(sessionsProvider);
      expect(loaded.sessions, isList);
      expect(loaded.error, isNull);
      expect(loaded.isLoading, isFalse);

      // Verify sorted by createdAt desc
      if (loaded.sessions.length >= 2) {
        for (var i = 0; i < loaded.sessions.length - 1; i++) {
          expect(
            loaded.sessions[i].createdAt.isAfter(loaded.sessions[i + 1].createdAt) ||
                loaded.sessions[i].createdAt.isAtSameMomentAs(loaded.sessions[i + 1].createdAt),
            isTrue,
            reason: 'Sessions should be sorted by createdAt descending',
          );
        }
      }
    });

    testWidgets('createSession adds to state', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final session = await container
          .read(sessionsProvider.notifier)
          .createSession(title: 'Provider Create Test');

      try {
        expect(session, isNotNull);
        expect(session!.id, isNotEmpty);

        final state = container.read(sessionsProvider);
        expect(
          state.sessions.any((s) => s.id == session.id),
          isTrue,
          reason: 'New session should be in state',
        );

        // Should be at the front
        expect(state.sessions.first.id, equals(session.id));
      } finally {
        if (session != null) {
          try {
            await client.deleteSession(session.id);
          } catch (_) {}
        }
      }
    });

    testWidgets('deleteSession removes from state', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final session = await container
          .read(sessionsProvider.notifier)
          .createSession(title: 'Provider Delete Test');
      expect(session, isNotNull);

      await container
          .read(sessionsProvider.notifier)
          .deleteSession(session!.id);

      final state = container.read(sessionsProvider);
      expect(
        state.sessions.any((s) => s.id == session.id),
        isFalse,
        reason: 'Deleted session should not be in state',
      );
    });
  });

  group('ChatProvider', () {
    testWidgets('loadMessages populates state', (tester) async {
      // Create session and send message via direct client
      final session = await client.createSession(
        input: SessionCreateInput(title: 'Chat Provider Test'),
      );

      try {
        await client.sendPrompt(session.id, text: 'Say "chat provider test"');

        // Poll until assistant responds
        for (var i = 0; i < 30; i++) {
          await Future.delayed(const Duration(seconds: 2));
          final msgs = await client.getMessages(session.id);
          if (msgs.any((m) => m.role == MessageRole.assistant)) break;
        }

        // Now test the provider
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await container
            .read(chatProvider.notifier)
            .loadMessages(session.id);

        final state = container.read(chatProvider);
        expect(state.messages, isNotEmpty);
        expect(state.isLoading, isFalse);

        for (final msg in state.messages) {
          if (msg.sessionId.isNotEmpty) {
            expect(msg.sessionId, equals(session.id));
          }
        }
      } finally {
        try {
          await client.deleteSession(session.id);
        } catch (_) {}
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('clearError resets error state', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Force an error by loading messages for a non-existent session
      await container
          .read(chatProvider.notifier)
          .loadMessages('nonexistent-session-id-12345');

      final errorState = container.read(chatProvider);
      expect(errorState.error, isNotNull);

      // Clear error
      container.read(chatProvider.notifier).clearError();

      final clearedState = container.read(chatProvider);
      expect(clearedState.error, isNull);
    });
  });

  group('ProjectsProvider', () {
    testWidgets('loadProjects populates state', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(projectsProvider.notifier).loadProjects();

      final state = container.read(projectsProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.projects, isList);

      // projectMap should match
      expect(state.projectMap.length, equals(state.projects.length));
    });
  });

  group('ProvidersProvider', () {
    testWidgets('fetch loads providers', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(providersProvider.notifier).fetch();

      final state = container.read(providersProvider);
      expect(state.isLoading, isFalse);
      expect(state.providers, isNotEmpty);

      for (final provider in state.providers) {
        expect(provider.id, isNotEmpty);
        expect(provider.name, isNotEmpty);
      }
    });

    testWidgets('clear resets state', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(providersProvider.notifier).fetch();
      expect(container.read(providersProvider).providers, isNotEmpty);

      container.read(providersProvider.notifier).clear();

      final state = container.read(providersProvider);
      expect(state.providers, isEmpty);
      expect(state.isLoading, isFalse);
    });
  });
}
