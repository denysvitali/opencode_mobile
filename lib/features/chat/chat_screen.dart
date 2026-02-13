import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/chat_provider.dart';
import '../../core/providers/model_selection_provider.dart';
import '../../core/providers/sessions_provider.dart';
import '../../core/providers/permission_provider.dart';
import 'widgets/message_list.dart';
import 'widgets/message_input.dart';
import 'widgets/model_selector.dart';
import 'widgets/permission_banner.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const ChatScreen({super.key, required this.sessionId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatProvider.notifier).loadMessages(widget.sessionId);
      ref.read(permissionsProvider.notifier).loadPermissions();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage(String text) async {
    final selection = ref.read(modelSelectionProvider);
    await ref.read(chatProvider.notifier).sendMessage(
          widget.sessionId,
          text,
          providerID: selection.isDefault ? null : selection.providerID,
          modelID: selection.isDefault ? null : selection.modelID,
        );
    _scrollToBottom();
  }

  String _getSessionTitle() {
    final sessionsState = ref.read(sessionsProvider);
    final session = sessionsState.sessions
        .where((s) => s.id == widget.sessionId)
        .firstOrNull;
    return session?.displayName ?? 'Chat';
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    // Watch sessions to reactively update title
    ref.watch(sessionsProvider);

    ref.listen(sseMessageProvider, (previous, next) {
      next.when(
        data: (message) {
          if (message.sessionId == widget.sessionId) {
            ref.read(chatProvider.notifier).updateMessage(message);
            _scrollToBottom();
          }
        },
        loading: () {},
        error: (_, __) {},
      );
    });

    // Listen for new permissions via SSE
    ref.listen(ssePermissionProvider, (previous, next) {
      next.when(
        data: (permission) {
          if (permission.sessionId == widget.sessionId) {
            ref.read(permissionsProvider.notifier).addPermission(permission);
          }
        },
        loading: () {},
        error: (_, __) {},
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(_getSessionTitle()),
        actions: [
          if (chatState.isStreaming)
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined),
              tooltip: 'Abort',
              onPressed: () {
                ref.read(chatProvider.notifier).abortSession(widget.sessionId);
              },
            ),
          if (chatState.isStreaming)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (chatState.error != null)
            MaterialBanner(
              content: Text(chatState.error!),
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              leading: Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    ref.read(chatProvider.notifier).clearError();
                  },
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          PermissionBanner(sessionId: widget.sessionId),
          Expanded(
            child: chatState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : MessageList(
                    messages: chatState.messages,
                    scrollController: _scrollController,
                  ),
          ),
          const ModelSelector(),
          MessageInput(
            onSend: _sendMessage,
            isLoading: chatState.isStreaming,
          ),
        ],
      ),
    );
  }
}
