import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/provider.dart' as models;
import '../../../core/providers/model_selection_provider.dart';

class ModelSelector extends ConsumerWidget {
  const ModelSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(modelSelectionProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ActionChip(
          avatar: Icon(
            selection.isDefault ? Icons.auto_awesome : Icons.model_training,
            size: 16,
          ),
          label: Text(
            selection.displayName,
            style: const TextStyle(fontSize: 12),
          ),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onPressed: () => _showModelPicker(context, ref),
        ),
      ),
    );
  }

  void _showModelPicker(BuildContext context, WidgetRef ref) {
    final providersAsync = ref.read(providersProvider);
    final currentSelection = ref.read(modelSelectionProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
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
                    'Select Model',
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
                data: (providers) => _buildProviderList(
                  context,
                  ref,
                  scrollController,
                  providers,
                  currentSelection,
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

  Widget _buildProviderList(
    BuildContext context,
    WidgetRef ref,
    ScrollController scrollController,
    List<models.Provider> providers,
    ModelSelection currentSelection,
  ) {
    return ListView(
      controller: scrollController,
      children: [
        ListTile(
          leading: const Icon(Icons.auto_awesome),
          title: const Text('Default'),
          subtitle: const Text('Use server default model'),
          trailing: currentSelection.isDefault
              ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
              : null,
          onTap: () {
            ref.read(modelSelectionProvider.notifier).reset();
            Navigator.of(context).pop();
          },
        ),
        const Divider(height: 1),
        ...providers.map((provider) => ExpansionTile(
              leading: Icon(
                provider.isDefault ? Icons.star : Icons.cloud_outlined,
                color: provider.isDefault
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: Text(provider.name),
              subtitle: provider.isDefault ? const Text('Default provider') : null,
              children: provider.models.map((model) {
                final isSelected = !currentSelection.isDefault &&
                    currentSelection.providerID == provider.id &&
                    currentSelection.modelID == model;
                return ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.only(left: 72, right: 16),
                  title: Text(model),
                  trailing: isSelected
                      ? Icon(Icons.check,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    ref
                        .read(modelSelectionProvider.notifier)
                        .select(provider.id, model);
                    Navigator.of(context).pop();
                  },
                );
              }).toList(),
            )),
      ],
    );
  }
}
