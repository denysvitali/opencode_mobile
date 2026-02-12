import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class ChatNotifier extends AsyncNotifier<ChatState> {
  late final String sessionId;

  @override
  Future<ChatState> build() async {
    // sessionId is set when the family provider creates this notifier
    if (sessionId.isNotEmpty) {
      final messages = await OpenCodeClient().getMessages(sessionId);
      return ChatState(messages: messages);
    }
    return ChatState();
  }

  Future<void> loadMessages({String? directory}) async {
    state = const AsyncLoading();
    try {
      final messages = await OpenCodeClient().getMessages(sessionId, directory: directory);
      state = AsyncData(ChatState(messages: messages));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> sendMessage(String text, {String? directory}) async {
    if (text.trim().isEmpty) return;

    final currentState = state.valueOrNull ?? ChatState();
    final userMessage = Message(
      sessionId: sessionId,
      role: MessageRole.user,
      parts: [MessagePart(type: MessagePartType.text, text: text)],
    );

    state = AsyncData(currentState.copyWith(
      messages: [...currentState.messages, userMessage],
      isStreaming: true,
      error: null,
    ));

    try {
      final response = await OpenCodeClient().sendMessage(
        sessionId,
        text: text,
        directory: directory,
      );

      final newState = state.valueOrNull ?? ChatState();
      state = AsyncData(newState.copyWith(
        messages: [...newState.messages, response],
        isStreaming: false,
        currentMessageId: response.id,
      ));
    } catch (e, st) {
      final newState = state.valueOrNull ?? ChatState();
      state = AsyncData(newState.copyWith(
        isStreaming: false,
        error: e.toString(),
      ));
    }
  }

  void updateMessage(Message updated) {
    if (updated.sessionId != sessionId) return;
    
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    final index = currentState.messages.indexWhere((m) => m.id == updated.id);
    if (index != -1) {
      final newMessages = List<Message>.from(currentState.messages);
      newMessages[index] = updated;
      state = AsyncData(currentState.copyWith(messages: newMessages));
    } else {
      state = AsyncData(currentState.copyWith(
        messages: [...currentState.messages, updated],
      ));
    }
  }

  void clearError() {
    final currentState = state.valueOrNull;
    if (currentState != null) {
      state = AsyncData(currentState.copyWith(error: null));
    }
  }
}

final chatSessionIdProvider = StateProvider<String>((ref) => '');

final chatProvider = AsyncNotifierProvider.family<ChatNotifier, ChatState, String>((ref, sessionId) {
  final notifier = ChatNotifier();
  notifier.sessionId = sessionId;
  return notifier;
});

final sseMessageProvider = StreamProvider<Message>((ref) {
  return SSEClient().messageUpdateStream;
});
