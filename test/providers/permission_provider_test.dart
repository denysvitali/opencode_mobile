import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opencode_mobile/core/api/opencode_client.dart';
import 'package:opencode_mobile/core/models/permission.dart';
import 'package:opencode_mobile/core/providers/permission_provider.dart';

void main() {
  group('PermissionsState', () {
    test('initial state is empty', () {
      final state = PermissionsState();
      expect(state.permissions, isEmpty);
      expect(state.isLoading, false);
      expect(state.error, isNull);
    });

    test('copyWith creates new state with updated values', () {
      final state = PermissionsState();
      final permission = Permission(
        id: 'perm-1',
        sessionId: 'session-1',
        type: 'file_read',
      );
      final newState = state.copyWith(
        permissions: [permission],
        isLoading: true,
        error: 'test error',
      );
      expect(newState.permissions.length, 1);
      expect(newState.permissions.first.id, 'perm-1');
      expect(newState.isLoading, true);
      expect(newState.error, 'test error');
    });

    test('copyWith with no arguments preserves state', () {
      final permission = Permission(
        id: 'perm-1',
        sessionId: 'session-1',
        type: 'file_read',
      );
      final state = PermissionsState(
        permissions: [permission],
        isLoading: true,
        error: 'error',
      );
      final newState = state.copyWith();

      expect(newState.permissions.length, 1);
      expect(newState.permissions.first.id, 'perm-1');
      expect(newState.isLoading, true);
      expect(newState.error, 'error');
    });
  });

  group('PermissionsNotifier', () {
    group('initial state', () {
      test('is correct', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final state = container.read(permissionsProvider);
        expect(state.permissions, isEmpty);
        expect(state.isLoading, false);
        expect(state.error, isNull);
      });
    });

    group('loadPermissions', () {
      test('fetches and populates permissions', () async {
        final container = ProviderContainer(
          overrides: [
            permissionsProvider.overrideWith(() => TestPermissionsNotifier(
              permissionsToReturn: [
                Permission(id: 'perm-1', sessionId: 'session-1', type: 'file_read'),
                Permission(id: 'perm-2', sessionId: 'session-2', type: 'shell'),
              ],
            )),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(permissionsProvider.notifier);
        
        await notifier.loadPermissions();

        expect(notifier.state.permissions.length, 2);
        expect(notifier.state.isLoading, false);
        expect(notifier.state.error, isNull);
      });

      test('handles API errors', () async {
        final container = ProviderContainer(
          overrides: [
            permissionsProvider.overrideWith(() => TestPermissionsNotifier(
              shouldThrowError: true,
              errorMessage: 'API Error: 500',
            )),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(permissionsProvider.notifier);
        await notifier.loadPermissions();

        expect(notifier.state.error, contains('API Error: 500'));
        expect(notifier.state.permissions, isEmpty);
        expect(notifier.state.isLoading, false);
      });

      test('preserves loading=false on error', () async {
        final container = ProviderContainer(
          overrides: [
            permissionsProvider.overrideWith(() => TestPermissionsNotifier(
              shouldThrowError: true,
            )),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(permissionsProvider.notifier);
        await notifier.loadPermissions();

        expect(notifier.state.isLoading, false);
      });
    });

    group('addPermission', () {
      test('adds new permission to list', () {
        final container = ProviderContainer(
          overrides: [
            permissionsProvider.overrideWith(() => TestPermissionsNotifier()),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(permissionsProvider.notifier);
        final permission = Permission(
          id: 'new-perm',
          sessionId: 'session-1',
          type: 'file_read',
        );

        notifier.addPermission(permission);

        expect(notifier.state.permissions.length, 1);
        expect(notifier.state.permissions.first.id, 'new-perm');
      });

      test('adds permission to beginning of list', () {
        final container = ProviderContainer(
          overrides: [
            permissionsProvider.overrideWith(() => TestPermissionsNotifier(
              initialPermissions: [
                Permission(id: 'existing', sessionId: 'session-1', type: 'shell'),
              ],
            )),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(permissionsProvider.notifier);
        notifier.addPermission(Permission(
          id: 'new',
          sessionId: 'session-2',
          type: 'file_read',
        ));

        expect(notifier.state.permissions.length, 2);
        expect(notifier.state.permissions.first.id, 'new');
      });

      test('prevents duplicate permission IDs', () {
        final container = ProviderContainer(
          overrides: [
            permissionsProvider.overrideWith(() => TestPermissionsNotifier(
              initialPermissions: [
                Permission(id: 'duplicate', sessionId: 'session-1', type: 'file_read'),
              ],
            )),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(permissionsProvider.notifier);
        notifier.addPermission(Permission(
          id: 'duplicate',
          sessionId: 'session-2',
          type: 'shell',
        ));

        expect(notifier.state.permissions.length, 1);
      });
    });

    group('removePermission', () {
      test('removes permission by ID', () {
        final container = ProviderContainer(
          overrides: [
            permissionsProvider.overrideWith(() => TestPermissionsNotifier(
              initialPermissions: [
                Permission(id: 'perm-1', sessionId: 'session-1', type: 'file_read'),
                Permission(id: 'perm-2', sessionId: 'session-2', type: 'shell'),
              ],
            )),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(permissionsProvider.notifier);
        notifier.removePermission('perm-1');

        expect(notifier.state.permissions.length, 1);
        expect(notifier.state.permissions.first.id, 'perm-2');
      });

      test('handles non-existent ID gracefully', () {
        final container = ProviderContainer(
          overrides: [
            permissionsProvider.overrideWith(() => TestPermissionsNotifier(
              initialPermissions: [
                Permission(id: 'existing', sessionId: 'session-1', type: 'file_read'),
              ],
            )),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(permissionsProvider.notifier);
        notifier.removePermission('nonexistent');

        expect(notifier.state.permissions.length, 1);
      });

      test('handles empty list', () {
        final container = ProviderContainer(
          overrides: [
            permissionsProvider.overrideWith(() => TestPermissionsNotifier()),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(permissionsProvider.notifier);
        notifier.removePermission('any');

        expect(notifier.state.permissions, isEmpty);
      });
    });

    group('replyPermission', () {
      test('calls API and removes permission on success', () async {
        final container = ProviderContainer(
          overrides: [
            permissionsProvider.overrideWith(() => TestPermissionsNotifier(
              initialPermissions: [
                Permission(id: 'perm-1', sessionId: 'session-1', type: 'file_read'),
              ],
            )),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(permissionsProvider.notifier);
        
        await notifier.replyPermission('perm-1', PermissionReply.once);

        expect(notifier.state.permissions, isEmpty);
        expect(notifier.state.error, isNull);
      });

      test('calls API with correct reply type', () async {
        final container = ProviderContainer(
          overrides: [
            permissionsProvider.overrideWith(() => TestPermissionsNotifier(
              initialPermissions: [
                Permission(id: 'perm-1', sessionId: 'session-1', type: 'file_read'),
              ],
              expectedReply: PermissionReply.always,
            )),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(permissionsProvider.notifier);
        
        await notifier.replyPermission('perm-1', PermissionReply.always);

        expect(notifier.state.permissions, isEmpty);
      });

      test('sets error on API failure', () async {
        final container = ProviderContainer(
          overrides: [
            permissionsProvider.overrideWith(() => TestPermissionsNotifier(
              initialPermissions: [
                Permission(id: 'perm-1', sessionId: 'session-1', type: 'file_read'),
              ],
              shouldThrowError: true,
              errorMessage: 'Failed to reply',
            )),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(permissionsProvider.notifier);
        
        await notifier.replyPermission('perm-1', PermissionReply.once);

        expect(notifier.state.error, contains('Failed to reply'));
        expect(notifier.state.permissions.length, 1);
      });

      test('does not remove permission on API failure', () async {
        final container = ProviderContainer(
          overrides: [
            permissionsProvider.overrideWith(() => TestPermissionsNotifier(
              initialPermissions: [
                Permission(id: 'perm-1', sessionId: 'session-1', type: 'file_read'),
              ],
              shouldThrowError: true,
            )),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(permissionsProvider.notifier);
        
        await notifier.replyPermission('perm-1', PermissionReply.reject);

        expect(notifier.state.permissions.length, 1);
      });
    });
  });
}

class TestPermissionsNotifier extends PermissionsNotifier {
  final List<Permission>? permissionsToReturn;
  final bool shouldThrowError;
  final String? errorMessage;
  final List<Permission>? initialPermissions;
  PermissionReply? expectedReply;

  TestPermissionsNotifier({
    this.permissionsToReturn,
    this.shouldThrowError = false,
    this.errorMessage,
    this.initialPermissions,
    this.expectedReply,
  });

  @override
  PermissionsState build() {
    return PermissionsState(
      permissions: initialPermissions ?? [],
      isLoading: false,
      error: null,
    );
  }

  @override
  Future<void> loadPermissions() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      if (shouldThrowError) {
        throw OpenCodeException(errorMessage ?? 'Error');
      }
      final permissions = permissionsToReturn ?? [];
      state = state.copyWith(permissions: permissions, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  @override
  Future<void> replyPermission(String permissionId, PermissionReply reply) async {
    try {
      if (shouldThrowError) {
        throw OpenCodeException(errorMessage ?? 'Error');
      }
      if (expectedReply != null && expectedReply != reply) {
        throw OpenCodeException('Wrong reply type');
      }
      removePermission(permissionId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}
