import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/provider.dart' as models;
import '../../core/providers/connection_provider.dart';
import '../../core/providers/model_selection_provider.dart';
import '../../core/utils/theme.dart';

class SettingsScreen extends ConsumerWidget {
  final Function(AppThemeMode) onThemeChanged;
  final AppThemeMode currentTheme;

  const SettingsScreen({
    super.key,
    required this.onThemeChanged,
    required this.currentTheme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(connectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          _buildSectionHeader(context, 'Connection'),
          _buildListTile(
            context,
            icon: Icons.link,
            title: 'Server URL',
            subtitle: connectionState.config.url,
          ),
          _buildListTile(
            context,
            icon: Icons.person,
            title: 'Username',
            subtitle: connectionState.config.username ?? 'Not set',
          ),
          _buildListTile(
            context,
            icon: Icons.info_outline,
            title: 'Server Version',
            subtitle: connectionState.serverVersion ?? 'Unknown',
          ),
          _buildProvidersListTile(context, ref),
          const Divider(),
          _buildSectionHeader(context, 'Appearance'),
          _buildThemeSelector(context),
          const Divider(),
          _buildSectionHeader(context, 'About'),
          _buildListTile(
            context,
            icon: Icons.code,
            title: 'OpenCode Mobile',
            subtitle: 'Version 1.0.0',
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () {
                ref.read(connectionProvider.notifier).disconnect();
                context.go('/');
              },
              icon: const Icon(Icons.logout),
              label: const Text('Disconnect'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }

  Widget _buildProvidersListTile(BuildContext context, WidgetRef ref) {
    final providersAsync = ref.watch(providersProvider);

    return ListTile(
      leading: const Icon(Icons.model_training),
      title: const Text('Available Models'),
      subtitle: providersAsync.when(
        data: (providers) => Text(
          providers.isEmpty
              ? 'No models available'
              : '${providers.length} provider(s) available',
        ),
        loading: () => const Text('Loading...'),
        error: (_, __) => const Text('Unable to load'),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showProvidersDialog(context, providersAsync),
    );
  }

  void _showProvidersDialog(BuildContext context, AsyncValue<List<models.Provider>> providersAsync) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Available Models',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: providersAsync.when(
                data: (providers) => providers.isEmpty
                    ? const Center(
                        child: Text('No models available'),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: providers.length,
                        itemBuilder: (context, index) {
                          final provider = providers[index];
                          return ExpansionTile(
                            leading: Icon(
                              provider.isDefault
                                  ? Icons.star
                                  : Icons.cloud_outlined,
                              color: provider.isDefault
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                            title: Text(provider.name),
                            subtitle: provider.configured
                                ? const Text('Configured')
                                : null,
                            children: provider.models.map((model) {
                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.only(left: 72, right: 16),
                                title: Text(model.name),
                                trailing: provider.configured && provider.models.indexOf(model) == 0
                                    ? Chip(
                                        label: const Text('Default'),
                                        labelStyle: const TextStyle(fontSize: 10),
                                        padding: EdgeInsets.zero,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      )
                                    : null,
                              );
                            }).toList(),
                          );
                        },
                      ),
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48),
                      const SizedBox(height: 16),
                      Text('Error loading providers: $error'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.palette_outlined),
      title: const Text('Theme'),
      subtitle: Text(_getThemeName(currentTheme)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showThemeDialog(context),
    );
  }

  String _getThemeName(AppThemeMode mode) {
    return switch (mode) {
      AppThemeMode.light => 'Light',
      AppThemeMode.dark => 'Dark',
      AppThemeMode.system => 'System',
    };
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppThemeMode.values.map((mode) {
            return RadioListTile<AppThemeMode>(
              title: Text(_getThemeName(mode)),
              value: mode,
              groupValue: currentTheme,
              onChanged: (value) {
                if (value != null) {
                  onThemeChanged(value);
                  Navigator.of(context).pop();
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
