import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:state_notifier/state_notifier.dart';

import '../api/opencode_client.dart';
import '../api/sse_client.dart';
import '../models/message.dart';

class ChatState {
  final List<Message> messages;
  final bool isLoading;
  final bool isStreaming;
  final String? error;
  final String? currentMessageId;

  ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isStreaming = false,
    this.error,
    this.currentMessageId,
  });

  ChatState copyWith({
    List<Message>? messages,
    bool? isLoading,
    bool? isStreaming,
    String? error,
    String? currentMessageId,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isStreaming: isStreaming ?? this.isStreaming,
      error: error ?? this.error,
      currentMessageId: currentMessageId ?? this.currentMessageId,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final String sessionId;

  ChatNotifier(this.sessionId) : super(ChatState());

  Future<void> loadMessages({String? directory}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final messages = await OpenCodeClient().getMessages(sessionId, directory: directory);
      state = state.copyWith(messages: messages, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> sendMessage(String text, {String? directory}) async {
    if (text.trim().isEmpty) return;

    final userMessage = Message(
      sessionId: sessionId,
      role: MessageRole.user,
      parts: [MessagePart(type: MessagePartType.text, text: text)],
    );

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isStreaming: true,
      error: null,
    );

    try {
      final response = await OpenCodeClient().sendMessage(
        sessionId,
        text: text,
        directory: directory,
      );

      state = state.copyWith(
        messages: [...state.messages, response],
        isStreaming: false,
        currentMessageId: response.id,
      );
    } catch (e) {
      state = state.copyWith(
        isStreaming: false,
        error: e.toString(),
      );
    }
  }

  void updateMessage(Message updated) {
    if (updated.sessionId != sessionId) return;

    final index = state.messages.indexWhere((m) => m.id == updated.id);
    if (index != -1) {
      final newMessages = List<Message>.from(state.messages);
      newMessages[index] = updated;
      state = state.copyWith(messages: newMessages);
    } else {
      state = state.copyWith(messages: [...state.messages, updated]);
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final chatProvider = StateNotifierProvider.family<ChatNotifier, ChatState, String>(
  (ref, sessionId) => ChatNotifier(sessionId),
);

final sseMessageProvider = StreamProvider<Message>((ref) {
  return SSEClient().messageUpdateStream;
});
