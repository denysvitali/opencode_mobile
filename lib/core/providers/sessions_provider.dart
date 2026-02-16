import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/opencode_client.dart';
import '../api/sse_client.dart';
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
      error: error ?? this.error,
    );
  }
}

class SessionsNotifier extends Notifier<SessionsState> {
  @override
  SessionsState build() {
    return SessionsState();
  }

  List<Session> _sortSessions(List<Session> sessions) {
    final sorted = List<Session>.from(sessions);
    sorted.sort((a, b) {
      final aTime = a.createdAt;
      final bTime = b.createdAt;
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  Future<void> loadSessions({String? directory}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final sessions = await OpenCodeClient().listSessions(directory: directory);
      state = state.copyWith(
        sessions: _sortSessions(sessions),
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<Session?> createSession({String? directory, String? title}) async {
    try {
      final session = await OpenCodeClient().createSession(
        directory: directory,
        input: title != null ? SessionCreateInput(title: title) : null,
      );
      final newSessions = _sortSessions([session, ...state.sessions]);
      state = state.copyWith(sessions: newSessions, error: null);
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
        error: null,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> initSession(String sessionId, {String? directory}) async {
    try {
      await OpenCodeClient().initSession(sessionId, directory: directory);
      final updatedSession = await OpenCodeClient().getSession(sessionId, directory: directory);
      updateSessionFromSSE(updatedSession);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateSession(String sessionId, SessionUpdateInput input, {String? directory}) async {
    try {
      final updatedSession = await OpenCodeClient().updateSession(
        sessionId,
        input,
        directory: directory,
      );
      final index = state.sessions.indexWhere((s) => s.id == sessionId);
      if (index != -1) {
        final newSessions = List<Session>.from(state.sessions);
        newSessions[index] = updatedSession;
        state = state.copyWith(sessions: newSessions, error: null);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  void updateSessionFromSSE(Session session) {
    final index = state.sessions.indexWhere((s) => s.id == session.id);
    if (index != -1) {
      final newSessions = List<Session>.from(state.sessions);
      newSessions[index] = session;
      state = state.copyWith(sessions: newSessions);
    } else {
      addSession(session);
    }
  }

  void addSession(Session session) {
    final exists = state.sessions.any((s) => s.id == session.id);
    if (!exists) {
      final newSessions = _sortSessions([session, ...state.sessions]);
      state = state.copyWith(sessions: newSessions);
    }
  }

  void removeSession(String sessionId) {
    state = state.copyWith(
      sessions: state.sessions.where((s) => s.id != sessionId).toList(),
    );
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final sessionsProvider = NotifierProvider<SessionsNotifier, SessionsState>(
  SessionsNotifier.new,
);

final sseSessionUpdateProvider = StreamProvider<Session>((ref) {
  return SSEClient().sessionUpdateStream;
});

final sseSessionCreatedProvider = StreamProvider<Session>((ref) {
  return SSEClient().sessionCreatedStream;
});

final sseSessionDeletedProvider = StreamProvider<String>((ref) {
  return SSEClient().sessionDeletedStream;
});
