import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/project.dart';
import '../../core/models/session.dart';
import '../../core/providers/sessions_provider.dart';
import '../../core/providers/project_provider.dart';
import '../sessions/sessions_screen.dart';
import '../sessions/new_session_dialog.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionsProvider.notifier).loadSessions();
      ref.read(projectsProvider.notifier).loadProjects();
    });
  }

  Future<void> _refreshData() async {
    await Future.wait([
      ref.read(sessionsProvider.notifier).loadSessions(),
      ref.read(projectsProvider.notifier).loadProjects(),
    ]);
  }

  Future<void> _createSession() async {
    final session = await showDialog<Session>(
      context: context,
      builder: (context) => NewSessionDialog(ref: ref),
    );

    if (session != null && mounted) {
      context.push('/chat/${session.id}');
    }
  }

  int _getSessionCountForProject(String projectId, List<Session> sessions) {
    return sessions.where((s) => s.projectId == projectId).length;
  }

  @override
  Widget build(BuildContext context) {
    final projectsState = ref.watch(projectsProvider);
    final sessionsState = ref.watch(sessionsProvider);

    // Listen to SSE session events for real-time updates
    ref.listen(sseSessionCreatedProvider, (previous, next) {
      next.when(
        data: (session) {
          ref.read(sessionsProvider.notifier).addSession(session);
        },
        loading: () {},
        error: (_, __) {},
      );
    });

    ref.listen(sseSessionDeletedProvider, (previous, next) {
      next.when(
        data: (sessionId) {
          ref.read(sessionsProvider.notifier).removeSession(sessionId);
        },
        loading: () {},
        error: (_, __) {},
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: projectsState.isLoading || sessionsState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(
              projectsState.projects,
              sessionsState.sessions,
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createSession,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildContent(List<Project> projects, List<Session> sessions) {
    // Calculate session counts
    final sessionCounts = <String, int>{};
    for (final project in projects) {
      sessionCounts[project.id] = _getSessionCountForProject(project.id, sessions);
    }

    final totalSessions = sessions.length;

    // If no projects and no sessions, show empty state
    if (projects.isEmpty && totalSessions == 0) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // All Sessions option
          _AllSessionsCard(
            sessionCount: totalSessions,
            onTap: () => context.push('/sessions'),
          ),
          const SizedBox(height: 16),
          // Projects header
          if (projects.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Projects',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            ...projects.map((project) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ProjectCard(
                project: project,
                sessionCount: sessionCounts[project.id] ?? 0,
                onTap: () => context.push('/sessions?projectId=${project.id}'),
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No projects yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect to an OpenCode server to see projects',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllSessionsCard extends StatelessWidget {
  final int sessionCount;
  final VoidCallback onTap;

  const _AllSessionsCard({
    required this.sessionCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.chat_bubble_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'All Sessions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$sessionCount ${sessionCount == 1 ? 'session' : 'sessions'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final int sessionCount;
  final VoidCallback onTap;

  const _ProjectCard({
    required this.project,
    required this.sessionCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.folder_outlined,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      project.worktree ?? '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$sessionCount',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
