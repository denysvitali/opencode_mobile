import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/opencode_client.dart';
import '../api/sse_client.dart';
import '../models/message.dart';

class PendingMessage {
  final String id;
  final String text;
  final DateTime createdAt;
  final bool isSending;
  final String? error;

  PendingMessage({
    required this.id,
    required this.text,
    required this.createdAt,
    this.isSending = true,
    this.error,
  });

  PendingMessage copyWith({
    bool? isSending,
    String? error,
  }) {
    return PendingMessage(
      id: id,
      text: text,
      createdAt: createdAt,
      isSending: isSending ?? this.isSending,
      error: error,
    );
  }
}

class ChatState {
  final List<Message> messages;
  final List<PendingMessage> pendingMessages;
  final bool isLoading;
  final bool isStreaming;
  final String? error;
  final String? currentMessageId;

  ChatState({
    this.messages = const [],
    this.pendingMessages = const [],
    this.isLoading = false,
    this.isStreaming = false,
    this.error,
    this.currentMessageId,
  });

  ChatState copyWith({
    List<Message>? messages,
    List<PendingMessage>? pendingMessages,
    bool? isLoading,
    bool? isStreaming,
    String? error,
    String? currentMessageId,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      pendingMessages: pendingMessages ?? this.pendingMessages,
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

    final pendingMessage = PendingMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      pendingMessages: [...state.pendingMessages, pendingMessage],
      error: null,
    );

    try {
      final response = await OpenCodeClient().sendPrompt(
        sessionId,
        text: text,
        directory: directory,
        providerID: providerID,
        modelID: modelID,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Message send timed out after 30 seconds');
        },
      );

      // Remove pending message and add server response
      final updatedPending = state.pendingMessages
          .where((p) => p.id != pendingMessage.id)
          .toList();

      state = state.copyWith(
        pendingMessages: updatedPending,
        messages: [...state.messages, response],
        currentMessageId: response.id,
      );
    } catch (e) {
      // Mark pending message as failed
      final updatedPending = state.pendingMessages.map((p) {
        if (p.id == pendingMessage.id) {
          return p.copyWith(isSending: false, error: e.toString());
        }
        return p;
      }).toList();

      state = state.copyWith(
        pendingMessages: updatedPending,
        isStreaming: false,
        error: e.toString(),
      );
    }
  }

  Future<void> retryPendingMessage(String pendingId, String sessionId, {String? directory, String? providerID, String? modelID}) async {
    final pendingMessage = state.pendingMessages.firstWhere(
      (p) => p.id == pendingId,
      orElse: () => throw Exception('Pending message not found'),
    );

    // Reset to sending state
    final updatedPending = state.pendingMessages.map((p) {
      if (p.id == pendingId) {
        return p.copyWith(isSending: true, error: null);
      }
      return p;
    }).toList();

    state = state.copyWith(pendingMessages: updatedPending, error: null);

    try {
      final response = await OpenCodeClient().sendMessage(
        sessionId,
        text: pendingMessage.text,
        directory: directory,
        providerID: providerID,
        modelID: modelID,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Message send timed out after 30 seconds');
        },
      );

      // Remove pending message and add server response
      final newPending = state.pendingMessages
          .where((p) => p.id != pendingId)
          .toList();

      state = state.copyWith(
        pendingMessages: newPending,
        messages: [...state.messages, response],
        currentMessageId: response.id,
      );
    } catch (e) {
      // Mark as failed again
      final newPending = state.pendingMessages.map((p) {
        if (p.id == pendingId) {
          return p.copyWith(isSending: false, error: e.toString());
        }
        return p;
      }).toList();

      state = state.copyWith(
        pendingMessages: newPending,
        error: e.toString(),
      );
    }
  }

  void removePendingMessage(String pendingId) {
    final updatedPending = state.pendingMessages
        .where((p) => p.id != pendingId)
        .toList();
    state = state.copyWith(pendingMessages: updatedPending);
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
