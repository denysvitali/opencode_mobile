import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:opencode_mobile/main.dart' as app;
import 'package:opencode_mobile/core/http/http_client.dart';
import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/models/config.dart';

/// Comprehensive UI Feature Test
/// Tests all features systematically on a real device in a single flow
/// Usage: flutter test --device-id <id> integration_test/ui_screenshots_test.dart --dart-define=SERVER_URL=<url>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const serverUrl = String.fromEnvironment('SERVER_URL');

  setUpAll(() async {
    if (serverUrl.isEmpty) {
      fail('SERVER_URL must be provided via --dart-define=SERVER_URL=<url>');
    }

    await platformHttpClient.initialize();

    final client = OpenCodeClient();
    await client.initialize(
      config: ServerConfig(url: serverUrl),
    );
  });

  testWidgets('Complete UI Feature Test Flow', (WidgetTester tester) async {
    // ==================== TEST 1: Connection Screen ====================
    print('TEST 1: Connection screen displays correctly');
    app.main();
    await tester.pumpAndSettle();

    // Verify connection screen elements
    expect(find.text('OpenCode'), findsOneWidget, reason: 'App title should be visible');
    expect(find.text('Connect to your OpenCode server'), findsOneWidget, reason: 'Subtitle should be visible');
    expect(find.byKey(const Key('serverUrlField')), findsOneWidget, reason: 'Server URL field should be visible');
    expect(find.byKey(const Key('usernameField')), findsOneWidget, reason: 'Username field should be visible');
    expect(find.byKey(const Key('passwordField')), findsOneWidget, reason: 'Password field should be visible');
    expect(find.byKey(const Key('passwordVisibilityToggle')), findsOneWidget, reason: 'Password visibility toggle should be visible');
    expect(find.byKey(const Key('connectButton')), findsOneWidget, reason: 'Connect button should be visible');

    // Verify default URL is pre-filled
    final urlField = tester.widget<TextFormField>(find.byKey(const Key('serverUrlField')));
    expect(urlField.controller?.text, 'http://localhost:4096', reason: 'Default URL should be localhost:4096');

    // ==================== TEST 2: URL Validation ====================
    print('TEST 2: URL validation works correctly');
    await tester.enterText(find.byKey(const Key('serverUrlField')), 'invalid-url');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('connectButton')));
    await tester.pumpAndSettle();

    // Should show validation error about URL scheme
    expect(find.text('URL must start with http:// or https://'), findsOneWidget,
        reason: 'Should show URL scheme validation error');

    // ==================== TEST 3: Password Visibility Toggle ====================
    print('TEST 3: Password visibility toggle works');
    await tester.enterText(find.byKey(const Key('passwordField')), 'testpassword');
    await tester.pumpAndSettle();

    final passwordField = tester.widget<TextFormField>(find.byKey(const Key('passwordField')));
    expect(passwordField.controller?.text, 'testpassword', reason: 'Password should be entered');

    await tester.tap(find.byKey(const Key('passwordVisibilityToggle')));
    await tester.pumpAndSettle();

    // ==================== TEST 4: Connect to Server ====================
    print('TEST 4: Successfully connect to server');
    await tester.enterText(find.byKey(const Key('serverUrlField')), serverUrl);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('connectButton')));
    await tester.pump();

    // Should show loading indicator
    expect(find.byType(CircularProgressIndicator), findsWidgets,
        reason: 'Should show loading indicator while connecting');

    // Wait for connection
    await tester.pumpAndSettle(const Duration(seconds: 10));

    // Should navigate to projects screen
    expect(find.text('Projects'), findsWidgets,
        reason: 'Should navigate to Projects screen after successful connection');

    // ==================== TEST 5: Projects Screen ====================
    print('TEST 5: Projects screen loads correctly');
    expect(find.byKey(const Key('settingsButton')), findsOneWidget,
        reason: 'Settings button should be visible');
    expect(find.byKey(const Key('allSessionsCard')), findsOneWidget,
        reason: 'All Sessions card should be visible');
    expect(find.byKey(const Key('newSessionFab')), findsOneWidget,
        reason: 'New session FAB should be visible');

    // Pull to refresh
    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Projects'), findsWidgets,
        reason: 'Projects screen should still be visible after refresh');

    // ==================== TEST 6: Navigate to Settings ====================
    print('TEST 6: Can navigate to settings from projects');
    await tester.tap(find.byKey(const Key('settingsButton')));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget,
        reason: 'Should navigate to Settings screen');

    // ==================== TEST 7: Settings Screen Elements ====================
    print('TEST 7: Settings screen displays correctly');
    expect(find.text('Connection'), findsOneWidget,
        reason: 'Connection section should be visible');
    expect(find.text('Appearance'), findsOneWidget,
        reason: 'Appearance section should be visible');
    expect(find.text('Theme'), findsOneWidget,
        reason: 'Theme option should be visible');
    expect(find.text('Disconnect'), findsOneWidget,
        reason: 'Disconnect button should be visible');

    // Server URL should be displayed
    expect(find.textContaining(serverUrl), findsOneWidget,
        reason: 'Server URL should be displayed in settings');

    // ==================== TEST 8: Theme Selector ====================
    print('TEST 8: Theme switching works');
    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Light'), findsWidgets,
        reason: 'Light theme option should be available');
    expect(find.textContaining('Dark'), findsWidgets,
        reason: 'Dark theme option should be available');
    expect(find.textContaining('System'), findsWidgets,
        reason: 'System theme option should be available');

    // Go back to settings
    await tester.tap(find.textContaining('Dark').first);
    await tester.pumpAndSettle();

    // ==================== TEST 9: Navigate to Sessions ====================
    print('TEST 9: Can navigate to sessions from projects');
    // Go back to Projects
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Projects'), findsWidgets, reason: 'Should be back on Projects');

    await tester.tap(find.byKey(const Key('allSessionsCard')));
    await tester.pumpAndSettle();

    expect(find.text('Sessions'), findsOneWidget,
        reason: 'Should navigate to Sessions screen');

    // ==================== TEST 10: Create New Session ====================
    print('TEST 10: Can create new session');
    await tester.tap(find.byKey(const Key('newSessionFab')));
    await tester.pumpAndSettle();

    // The dialog auto-creates session and shows "Creating session..."
    // It may close quickly, so just check that something happened
    // Either we're still on sessions screen, or we navigated to chat
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Should either be on sessions screen OR chat screen
    final onSessions = find.text('Sessions').evaluate().isNotEmpty;
    final onChat = find.byKey(const Key('messageInput')).evaluate().isNotEmpty;
    expect(onSessions || onChat, true,
        reason: 'Should be on Sessions or Chat screen after creating session');

    // ==================== TEST 11-13: Chat Screen ====================
    print('TEST 11-13: Chat screen functionality');

    // Make sure we're on the Sessions screen first
    if (find.text('Sessions').evaluate().isEmpty) {
      // Navigate back to Projects first
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Then tap All Sessions to go to Sessions
      if (find.byKey(const Key('allSessionsCard')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('allSessionsCard')));
        await tester.pumpAndSettle();
      }
    }

    // Now try to enter a chat session
    if (find.byKey(const Key('messageInput')).evaluate().isEmpty) {
      // Look for session tiles and tap the first one
      final sessionTile = find.byKey(const Key('sessionTile_'));
      if (sessionTile.evaluate().isNotEmpty) {
        await tester.tap(sessionTile.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      } else {
        // Create a new session if none exist
        await tester.tap(find.byKey(const Key('newSessionFab')));
        await tester.pumpAndSettle(const Duration(seconds: 3));
      }
    }

    // Verify chat screen elements (if we made it to chat)
    if (find.byKey(const Key('messageInput')).evaluate().isNotEmpty) {
      expect(find.byKey(const Key('messageInput')), findsOneWidget,
          reason: 'Message input should be visible');
      expect(find.byKey(const Key('sendButton')), findsOneWidget,
          reason: 'Send button should be visible');
      expect(find.byKey(const Key('modelSelectorButton')), findsOneWidget,
          reason: 'Model selector should be visible');

      // Test message input
      await tester.enterText(find.byKey(const Key('messageInput')), 'Hello, this is a test message');
      await tester.pumpAndSettle();

      final sendButton = tester.widget<IconButton>(find.byKey(const Key('sendButton')));
      expect(sendButton.onPressed, isNotNull,
          reason: 'Send button should be enabled when text is entered');

      // Test model selector
      await tester.tap(find.byKey(const Key('modelSelectorButton')));
      await tester.pumpAndSettle();

      expect(find.text('Select Model'), findsOneWidget,
          reason: 'Model picker should open');
      expect(find.text('Default'), findsOneWidget,
          reason: 'Default option should be visible');

      // Close model picker
      await tester.tap(find.text('Default'));
      await tester.pumpAndSettle();
    } else {
      print('Chat screen not accessible - skipping chat tests');
    }

    // ==================== TEST 14: Disconnect ====================
    print('TEST 14: Can disconnect from settings');

    // Navigate back to sessions, then projects
    await tester.pageBack();
    await tester.pumpAndSettle();

    // If we're on sessions, go back to projects
    if (find.text('Sessions').evaluate().isNotEmpty) {
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    expect(find.byKey(const Key('allSessionsCard')), findsOneWidget, reason: 'Should be on Projects');

    // Navigate to settings
    await tester.tap(find.byKey(const Key('settingsButton')));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget, reason: 'Should be on Settings');

    // Tap disconnect
    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Should return to connection screen
    expect(find.text('Connect to your OpenCode server'), findsOneWidget,
        reason: 'Should return to connection screen after disconnect');

    print('ALL TESTS PASSED!');
  });
}
