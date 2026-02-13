import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/session.dart';
import '../../core/models/project.dart';
import '../../core/providers/sessions_provider.dart';
import '../../core/providers/project_provider.dart';
import 'new_session_dialog.dart';

class SessionsScreen extends ConsumerStatefulWidget {
  final String? projectId;

  const SessionsScreen({super.key, this.projectId});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionsProvider.notifier).loadSessions();
      ref.read(projectsProvider.notifier).loadProjects();
    });
  }

  Future<void> _refreshSessions() async {
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

  Future<void> _deleteSession(Session session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: Text('Are you sure you want to delete "${session.displayName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(sessionsProvider.notifier).deleteSession(session.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionsState = ref.watch(sessionsProvider);
    final projectsState = ref.watch(projectsProvider);

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

    ref.listen(sseSessionUpdateProvider, (previous, next) {
      next.when(
        data: (session) {
          ref.read(sessionsProvider.notifier).updateSession(session);
        },
        loading: () {},
        error: (_, __) {},
      );
    });

    // Filter sessions by projectId if provided
    final filteredSessions = widget.projectId != null
        ? sessionsState.sessions
            .where((s) => s.projectID == widget.projectId)
            .toList()
        : sessionsState.sessions;

    // Get project name for title if filtering by project
    final projectName = widget.projectId != null
        ? projectsState.projectMap[widget.projectId]?.displayName ?? 'Project'
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(projectName ?? 'Sessions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: sessionsState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : filteredSessions.isEmpty
              ? _buildEmptyState()
              : _buildSessionList(
                  filteredSessions,
                  projectsState.projectMap,
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createSession,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No sessions yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to start a new conversation',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionList(
    List<Session> sessions,
    Map<String, Project> projectMap,
  ) {
    // When filtered by project, show simple list without grouping
    if (widget.projectId != null) {
      return RefreshIndicator(
        onRefresh: _refreshSessions,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final session = sessions[index];
            return _SessionTile(
              session: session,
              onTap: () => context.push('/chat/${session.id}'),
              onDelete: () => _deleteSession(session),
            );
          },
        ),
      );
    }

    // When not filtered, show grouped by project
    final grouped = <String?, List<Session>>{};
    for (final session in sessions) {
      grouped.putIfAbsent(session.projectID, () => []).add(session);
    }

    // Sort groups: named projects first (alphabetically), then null/unknown
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == null && b == null) return 0;
        if (a == null) return 1;
        if (b == null) return -1;
        final nameA = projectMap[a]?.displayName ?? a;
        final nameB = projectMap[b]?.displayName ?? b;
        return nameA.compareTo(nameB);
      });

    return RefreshIndicator(
      onRefresh: _refreshSessions,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sortedKeys.fold<int>(0, (sum, key) =>
            sum + 1 + grouped[key]!.length), // headers + sessions
        itemBuilder: (context, index) {
          // Calculate which group/item we're at
          var currentIndex = 0;
          for (final key in sortedKeys) {
            final groupSessions = grouped[key]!;
            if (index == currentIndex) {
              // This is a header
              final project = key != null ? projectMap[key] : null;
              return _ProjectHeader(
                name: project?.displayName ?? 'Other',
                subtitle: project?.worktree,
              );
            }
            currentIndex++;
            if (index < currentIndex + groupSessions.length) {
              final session = groupSessions[index - currentIndex];
              return _SessionTile(
                session: session,
                onTap: () => context.push('/chat/${session.id}'),
                onDelete: () => _deleteSession(session),
              );
            }
            currentIndex += groupSessions.length;
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _ProjectHeader extends StatelessWidget {
  final String name;
  final String? subtitle;

  const _ProjectHeader({required this.name, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final Session session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionTile({
    required this.session,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.MMMd().add_jm();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildStatusIndicator(context),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateFormat.format(session.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(BuildContext context) {
    final (color, icon) = switch (session.status) {
      SessionStatus.idle => (Colors.grey, null),
      SessionStatus.pending => (Colors.orange, Icons.hourglass_empty),
      SessionStatus.running => (Colors.green, Icons.circle),
      SessionStatus.compacting => (Colors.blue, Icons.compress),
    };

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: icon != null
          ? Icon(icon, color: color, size: 20)
          : Icon(Icons.chat, color: color.withOpacity(0.5), size: 20),
    );
  }
}
