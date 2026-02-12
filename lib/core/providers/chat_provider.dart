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

// Simple ChatNotifier that receives sessionId in constructor
class ChatNotifier extends Notifier<ChatState> {
  late final String _sessionId;

  void init(String sessionId) {
    _sessionId = sessionId;
  }

  String get sessionId => _sessionId;

  @override
  ChatState build() {
    return ChatState();
  }

  Future<void> loadMessages({String? directory}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final messages = await OpenCodeClient().getMessages(_sessionId, directory: directory);
      state = state.copyWith(messages: messages, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> sendMessage(String text, {String? directory}) async {
    if (text.trim().isEmpty) return;

    final userMessage = Message(
      sessionId: _sessionId,
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
        _sessionId,
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
    if (updated.sessionId != _sessionId) return;

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

// Family provider using a map to store notifiers per sessionId
final _notifiers = Provider.family<ChatNotifier, String>((ref, sessionId) {
  final notifier = ChatNotifier();
  notifier.init(sessionId);
  return notifier;
});

// Re-export for easier access
final chatProvider = _notifiers;

final sseMessageProvider = StreamProvider<Message>((ref) {
  return SSEClient().messageUpdateStream;
});
