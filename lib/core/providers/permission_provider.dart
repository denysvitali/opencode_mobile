import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/opencode_client.dart';
import '../api/sse_client.dart';
import '../models/permission.dart';

class PermissionsState {
  final List<Permission> permissions;
  final bool isLoading;
  final String? error;

  PermissionsState({
    this.permissions = const [],
    this.isLoading = false,
    this.error,
  });

  PermissionsState copyWith({
    List<Permission>? permissions,
    bool? isLoading,
    String? error,
  }) {
    return PermissionsState(
      permissions: permissions ?? this.permissions,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class PermissionsNotifier extends Notifier<PermissionsState> {
  @override
  PermissionsState build() {
    return PermissionsState();
  }

  Future<void> loadPermissions() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final permissions = await OpenCodeClient().getPermissions();
      state = state.copyWith(permissions: permissions, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void addPermission(Permission permission) {
    final exists = state.permissions.any((p) => p.id == permission.id);
    if (!exists) {
      state = state.copyWith(
        permissions: [permission, ...state.permissions],
      );
    }
  }

  void removePermission(String permissionId) {
    state = state.copyWith(
      permissions: state.permissions.where((p) => p.id != permissionId).toList(),
    );
  }

  Future<void> replyPermission(String permissionId, PermissionReply reply) async {
    try {
      await OpenCodeClient().replyPermission(permissionId, reply: reply);
      removePermission(permissionId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final permissionsProvider = NotifierProvider<PermissionsNotifier, PermissionsState>(
  PermissionsNotifier.new,
);

final ssePermissionProvider = StreamProvider<Permission>((ref) {
  return SSEClient().permissionStream;
});
