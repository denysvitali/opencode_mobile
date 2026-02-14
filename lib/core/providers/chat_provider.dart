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

class ChatNotifier extends Notifier<ChatState> {
  @override
  ChatState build() {
    return ChatState();
  }

  Future<void> loadMessages(String sessionId, {String? directory}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final messages = await OpenCodeClient().getMessages(sessionId, directory: directory);
      state = state.copyWith(messages: messages, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> sendMessage(String sessionId, String text, {String? directory, String? providerID, String? modelID}) async {
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
      final response = await OpenCodeClient().sendPrompt(
        sessionId,
        text: text,
        directory: directory,
        providerID: providerID,
        modelID: modelID,
      );

      state = state.copyWith(
        messages: [...state.messages, response],
        isStreaming: false,
        currentMessageId: response.id,
      );
    } catch (e) {
      final newMessages = List<Message>.from(state.messages);
      newMessages.remove(userMessage);
      state = state.copyWith(
        messages: newMessages,
        isStreaming: false,
        error: e.toString(),
      );
    }
  }

  void updateMessage(Message updated) {
    final index = state.messages.indexWhere((m) => m.id == updated.id);
    if (index != -1) {
      final newMessages = List<Message>.from(state.messages);
      newMessages[index] = updated;
      state = state.copyWith(messages: newMessages);
    } else {
      state = state.copyWith(messages: [...state.messages, updated]);
    }
  }

  Future<void> abortSession(String sessionId) async {
    try {
      await OpenCodeClient().abortSession(sessionId);
      state = state.copyWith(isStreaming: false);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);

final chatProviderFamily = Provider.family<ChatNotifier, String>((ref, sessionId) {
  throw UnimplementedError('Use chatProvider instead with sessionId in method calls');
});

final sseMessageProvider = StreamProvider<Message>((ref) {
  return SSEClient().messageUpdateStream;
});
