import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/chat_provider.dart';
import '../../core/providers/sse_message_provider.dart';
import 'widgets/message_list.dart';
import 'widgets/message_input.dart';

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
      ref.read(chatProvider(widget.sessionId).notifier).loadMessages();
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
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage(String text) async {
    await ref.read(chatProvider(widget.sessionId).notifier).sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider(widget.sessionId));

    ref.listen<Message>(sseMessageProvider, (previous, next) {
      if (next.sessionId == widget.sessionId) {
        ref.read(chatProvider(widget.sessionId).notifier).updateMessage(next);
        _scrollToBottom();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          if (chatState.isStreaming)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
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
          Expanded(
            child: chatState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : MessageList(
                    messages: chatState.messages,
                    scrollController: _scrollController,
                  ),
          ),
          MessageInput(
            onSend: _sendMessage,
            isLoading: chatState.isStreaming,
          ),
        ],
      ),
    );
  }
}
