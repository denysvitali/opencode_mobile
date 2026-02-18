import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:opencode_mobile/core/models/session.dart';
import 'package:opencode_mobile/core/models/project.dart';
import 'package:opencode_mobile/features/projects/projects_screen.dart';
import 'package:opencode_mobile/core/providers/sessions_provider.dart';
import 'package:opencode_mobile/core/providers/project_provider.dart';

final testRouter = GoRouter(
  initialLocation: '/projects',
  routes: [
    GoRoute(
      path: '/projects',
      builder: (context, state) => const ProjectsScreen(),
    ),
    GoRoute(
      path: '/sessions',
      builder: (context, state) => Scaffold(
        body: Center(child: Text('Sessions: ${state.queryParameters['projectId']}')),
      ),
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
  group('ProjectsScreen Widget Tests', () {
    testWidgets('shows empty state when no projects', (tester) async {
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

      expect(find.text('No projects yet'), findsOneWidget);
      expect(find.text('Connect to an OpenCode server to see projects'), findsOneWidget);
    });

    testWidgets('shows project list with session counts', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionsProvider.overrideWith(() => PopulatedSessionsNotifier()),
            projectsProvider.overrideWith(() => PopulatedProjectsNotifier()),
          ],
          child: MaterialApp.router(
            routerConfig: testRouter,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show the project name
      expect(find.text('Test Project'), findsOneWidget);
      // Should show session count badge (2 sessions match the worktree)
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('counts sessions by path matching project worktree', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionsProvider.overrideWith(() => MixedPathSessionsNotifier()),
            projectsProvider.overrideWith(() => MultipleProjectsNotifier()),
          ],
          child: MaterialApp.router(
            routerConfig: testRouter,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find session count badges
      final countBadges = find.text('2');
      // Project A has 2 sessions matching /project-a
      expect(countBadges, findsNWidgets(1));
    });

    testWidgets('shows zero count for project with no matching sessions', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionsProvider.overrideWith(() => PopulatedSessionsNotifier()),
            projectsProvider.overrideWith(() => ProjectWithNoSessionsNotifier()),
          ],
          child: MaterialApp.router(
            routerConfig: testRouter,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show project with different worktree
      expect(find.text('Empty Project'), findsOneWidget);
      // Should show 0 count (no sessions match /different/path)
      expect(find.text('0'), findsOneWidget);
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

    testWidgets('navigates to sessions when project card tapped', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionsProvider.overrideWith(() => PopulatedSessionsNotifier()),
            projectsProvider.overrideWith(() => PopulatedProjectsNotifier()),
          ],
          child: MaterialApp.router(
            routerConfig: testRouter,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on the project card
      await tester.tap(find.text('Test Project'));
      await tester.pumpAndSettle();

      // Should navigate to sessions screen with projectId
      expect(find.textContaining('Sessions:'), findsOneWidget);
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
          title: 'Session 1',
          status: SessionStatus.idle,
          createdAt: DateTime.now(),
          path: '/test/project',
        ),
        Session(
          id: 'session-2',
          title: 'Session 2',
          status: SessionStatus.running,
          createdAt: DateTime.now(),
          path: '/test/project',
        ),
      ],
      isLoading: false,
    );
  }
}

class MixedPathSessionsNotifier extends SessionsNotifier {
  @override
  Future<void> loadSessions({String? directory}) async {
    state = state.copyWith(
      sessions: [
        Session(
          id: 'session-a1',
          title: 'Project A Session 1',
          status: SessionStatus.idle,
          createdAt: DateTime.now(),
          path: '/project-a',
        ),
        Session(
          id: 'session-a2',
          title: 'Project A Session 2',
          status: SessionStatus.idle,
          createdAt: DateTime.now(),
          path: '/project-a',
        ),
        Session(
          id: 'session-b1',
          title: 'Project B Session 1',
          status: SessionStatus.running,
          createdAt: DateTime.now(),
          path: '/project-b',
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

class PopulatedProjectsNotifier extends ProjectsNotifier {
  @override
  Future<void> loadProjects() async {
    state = ProjectsState(
      projects: [
        Project(
          id: 'proj-1',
          worktree: '/test/project',
        ),
      ],
      isLoading: false,
    );
  }
}

class MultipleProjectsNotifier extends ProjectsNotifier {
  @override
  Future<void> loadProjects() async {
    state = ProjectsState(
      projects: [
        Project(
          id: 'proj-a',
          worktree: '/project-a',
        ),
        Project(
          id: 'proj-b',
          worktree: '/project-b',
        ),
      ],
      isLoading: false,
    );
  }
}

class ProjectWithNoSessionsNotifier extends ProjectsNotifier {
  @override
  Future<void> loadProjects() async {
    state = ProjectsState(
      projects: [
        Project(
          id: 'proj-empty',
          worktree: '/different/path',
        ),
      ],
      isLoading: false,
    );
  }
}
