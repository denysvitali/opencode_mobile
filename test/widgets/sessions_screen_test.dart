import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:opencode_mobile/core/models/session.dart';
import 'package:opencode_mobile/core/models/project.dart';
import 'package:opencode_mobile/features/sessions/sessions_screen.dart';
import 'package:opencode_mobile/core/providers/sessions_provider.dart';
import 'package:opencode_mobile/core/providers/project_provider.dart';

final testRouter = GoRouter(
  initialLocation: '/sessions',
  routes: [
    GoRoute(
      path: '/sessions',
      builder: (context, state) => const SessionsScreen(),
    ),
    GoRoute(
      path: '/chat/:sessionId',
      builder: (context, state) => Scaffold(
        body: Center(child: Text('Chat: ${state.pathParameters['sessionId']}')),
      ),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const Scaffold(
        body: Center(child: Text('Settings')),
      ),
    ),
  ],
);

void main() {
  group('SessionsScreen Widget Tests', () {
    testWidgets('shows empty state when no sessions', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionsProvider.overrideWith(() => EmptySessionsNotifier()),
            projectsProvider.overrideWith(() => EmptyProjectsNotifier()),
          ],
          child: MaterialApp.router(
            routerConfig: testRouter,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No sessions yet'), findsOneWidget);
      expect(find.text('Tap + to start a new conversation'), findsOneWidget);
    });

    testWidgets('shows session list when sessions exist', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionsProvider.overrideWith(() => PopulatedSessionsNotifier()),
            projectsProvider.overrideWith(() => EmptyProjectsNotifier()),
          ],
          child: MaterialApp.router(
            routerConfig: testRouter,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Test Session 1'), findsOneWidget);
      expect(find.text('Test Session 2'), findsOneWidget);
    });

    testWidgets('shows FAB for creating new session', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionsProvider.overrideWith(() => EmptySessionsNotifier()),
            projectsProvider.overrideWith(() => EmptyProjectsNotifier()),
          ],
          child: MaterialApp.router(
            routerConfig: testRouter,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('shows settings icon in app bar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionsProvider.overrideWith(() => EmptySessionsNotifier()),
            projectsProvider.overrideWith(() => EmptyProjectsNotifier()),
          ],
          child: MaterialApp.router(
            routerConfig: testRouter,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets('shows session status indicators', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionsProvider.overrideWith(() => StatusSessionsNotifier()),
            projectsProvider.overrideWith(() => EmptyProjectsNotifier()),
          ],
          child: MaterialApp.router(
            routerConfig: testRouter,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chat), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
      expect(find.byIcon(Icons.circle), findsOneWidget);
    });
  });
}

class EmptySessionsNotifier extends SessionsNotifier {
  @override
  Future<void> loadSessions({String? directory}) async {
    state = state.copyWith(sessions: [], isLoading: false);
  }
}

class PopulatedSessionsNotifier extends SessionsNotifier {
  @override
  Future<void> loadSessions({String? directory}) async {
    state = state.copyWith(
      sessions: [
        Session(
          id: 'session-1',
          title: 'Test Session 1',
          status: SessionStatus.idle,
          createdAt: DateTime.now(),
          path: '/test',
        ),
        Session(
          id: 'session-2',
          title: 'Test Session 2',
          status: SessionStatus.running,
          createdAt: DateTime.now(),
          path: '/test',
        ),
      ],
      isLoading: false,
    );
  }
}

class StatusSessionsNotifier extends SessionsNotifier {
  @override
  Future<void> loadSessions({String? directory}) async {
    state = state.copyWith(
      sessions: [
        Session(
          id: 'session-1',
          title: 'Idle Session',
          status: SessionStatus.idle,
          createdAt: DateTime.now(),
          path: '/test',
        ),
        Session(
          id: 'session-2',
          title: 'Pending Session',
          status: SessionStatus.pending,
          createdAt: DateTime.now(),
          path: '/test',
        ),
        Session(
          id: 'session-3',
          title: 'Running Session',
          status: SessionStatus.running,
          createdAt: DateTime.now(),
          path: '/test',
        ),
      ],
      isLoading: false,
    );
  }
}

class EmptyProjectsNotifier extends ProjectsNotifier {
  @override
  Future<void> loadProjects() async {
    state = ProjectsState(projects: [], isLoading: false);
  }
}
