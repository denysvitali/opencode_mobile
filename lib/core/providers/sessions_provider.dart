import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/opencode_client.dart';
import '../models/session.dart';

class SessionsState {
  final List<Session> sessions;
  final bool isLoading;
  final String? error;

  SessionsState({
    this.sessions = const [],
    this.isLoading = false,
    this.error,
  });

  SessionsState copyWith({
    List<Session>? sessions,
    bool? isLoading,
    String? error,
  }) {
    return SessionsState(
      sessions: sessions ?? this.sessions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class SessionsNotifier extends Notifier<SessionsState> {
  @override
  SessionsState build() {
    return SessionsState();
  }

  Future<void> loadSessions({String? directory}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final sessions = await OpenCodeClient().listSessions(directory: directory);
      sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = state.copyWith(sessions: sessions, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<Session?> createSession({String? directory, String? title}) async {
    try {
      final session = await OpenCodeClient().createSession(
        directory: directory,
        title: title,
      );
      state = state.copyWith(
        sessions: [session, ...state.sessions],
      );
      return session;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<void> deleteSession(String sessionId, {String? directory}) async {
    try {
      await OpenCodeClient().deleteSession(sessionId, directory: directory);
      state = state.copyWith(
        sessions: state.sessions.where((s) => s.id != sessionId).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void updateSession(Session updated) {
    final index = state.sessions.indexWhere((s) => s.id == updated.id);
    if (index != -1) {
      final newSessions = List<Session>.from(state.sessions);
      newSessions[index] = updated;
      state = state.copyWith(sessions: newSessions);
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final sessionsProvider = NotifierProvider<SessionsNotifier, SessionsState>(
  SessionsNotifier.new,
);
