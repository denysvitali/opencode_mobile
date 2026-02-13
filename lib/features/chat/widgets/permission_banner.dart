import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/opencode_client.dart';
import '../../../core/models/permission.dart';
import '../../../core/providers/permission_provider.dart';

class PermissionBanner extends ConsumerWidget {
  final String sessionId;

  const PermissionBanner({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionsState = ref.watch(permissionsProvider);
    final sessionPermissions = permissionsState.permissions
        .where((p) => p.sessionId == sessionId)
        .toList();

    if (sessionPermissions.isEmpty) return const SizedBox.shrink();

    return Column(
      children: sessionPermissions.map((permission) {
        return _PermissionCard(permission: permission);
      }).toList(),
    );
  }
}

class _PermissionCard extends ConsumerWidget {
  final Permission permission;

  const _PermissionCard({required this.permission});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.tertiary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.security,
                size: 18,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Permission Required: ${permission.type}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ),
          if (permission.message != null) ...[
            const SizedBox(height: 8),
            Text(
              permission.message!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onTertiaryContainer,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  ref.read(permissionsProvider.notifier)
                      .replyPermission(permission.id, PermissionReply.reject);
                },
                child: const Text('Deny'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  ref.read(permissionsProvider.notifier)
                      .replyPermission(permission.id, PermissionReply.always);
                },
                child: const Text('Always Allow'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  ref.read(permissionsProvider.notifier)
                      .replyPermission(permission.id, PermissionReply.once);
                },
                child: const Text('Allow Once'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
