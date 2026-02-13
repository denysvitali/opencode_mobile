import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/http/http_client.dart';
import 'core/providers/connection_provider.dart';
import 'core/services/storage_service.dart';
import 'core/utils/theme.dart';
import 'features/connection/connection_screen.dart';
import 'features/sessions/sessions_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/settings/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (Platform.isAndroid) {
    await platformHttpClient.initialize();
    if (platformHttpClient.hasCronetFailed) {
      debugPrint('WARNING: Cronet failed to load, using fallback HTTP client. '
          'User CA certificates may not be trusted for REST API.');
    }
  }
  
  await StorageService().initialize();
  runApp(const ProviderScope(child: OpenCodeApp()));
}

class OpenCodeApp extends ConsumerStatefulWidget {
  const OpenCodeApp({super.key});

  @override
  ConsumerState<OpenCodeApp> createState() => _OpenCodeAppState();
}

class _OpenCodeAppState extends ConsumerState<OpenCodeApp> {
  late final GoRouter _router;
  AppThemeMode _themeMode = AppThemeMode.system;

  @override
  void initState() {
    super.initState();
    _router = _buildRouter();
    _loadTheme();
    _initConnection();
  }

  Future<void> _loadTheme() async {
    final mode = await StorageService().getThemeMode();
    setState(() {
      _themeMode = AppThemeModeExtension.fromString(mode);
    });
  }

  Future<void> _initConnection() async {
    await ref.read(connectionProvider.notifier).loadConfig();
    final config = ref.read(connectionProvider).config;
    if (config.url.isNotEmpty) {
      ref.read(connectionProvider.notifier).connect();
    }
  }

  void _setThemeMode(AppThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
    StorageService().setThemeMode(mode.name);
  }

  GoRouter _buildRouter() {
    return GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) => const ConnectionGate(
            child: SessionsScreen(),
          ),
        ),
        GoRoute(
          path: '/sessions',
          name: 'sessions',
          builder: (context, state) => const ConnectionGate(
            child: SessionsScreen(),
          ),
        ),
        GoRoute(
          path: '/chat/:sessionId',
          name: 'chat',
          builder: (context, state) {
            final sessionId = state.pathParameters['sessionId']!;
            return ConnectionGate(
              child: ChatScreen(sessionId: sessionId),
            );
          },
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => ConnectionGate(
            child: SettingsScreen(
              onThemeChanged: _setThemeMode,
              currentTheme: _themeMode,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'OpenCode',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildLightTheme(),
      darkTheme: AppTheme.buildDarkTheme(),
      themeMode: _getThemeMode(),
      routerConfig: _router,
    );
  }

  ThemeMode _getThemeMode() {
    return switch (_themeMode) {
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
      AppThemeMode.system => ThemeMode.system,
    };
  }
}

class ConnectionGate extends ConsumerWidget {
  final Widget child;

  const ConnectionGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(connectionProvider);

    if (!connectionState.isConnected) {
      return const ConnectionScreen();
    }

    return child;
  }
}
