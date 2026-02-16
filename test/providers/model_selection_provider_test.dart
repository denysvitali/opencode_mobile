import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opencode_mobile/core/providers/model_selection_provider.dart';

void main() {
  group('ModelSelection', () {
    test('isDefault returns true when both providerID and modelID are null', () {
      const selection = ModelSelection();
      expect(selection.isDefault, true);
    });

    test('isDefault returns false when providerID is set', () {
      const selection = ModelSelection(providerID: 'openai');
      expect(selection.isDefault, false);
    });

    test('isDefault returns false when modelID is set', () {
      const selection = ModelSelection(modelID: 'gpt-4');
      expect(selection.isDefault, false);
    });

    test('isDefault returns false when both providerID and modelID are set', () {
      const selection = ModelSelection(providerID: 'openai', modelID: 'gpt-4');
      expect(selection.isDefault, false);
    });

    test('displayName returns Default when isDefault is true', () {
      const selection = ModelSelection();
      expect(selection.displayName, 'Default');
    });

    test('displayName returns modelID when set', () {
      const selection = ModelSelection(providerID: 'openai', modelID: 'gpt-4');
      expect(selection.displayName, 'gpt-4');
    });

    test('displayName returns providerID when modelID is null but providerID is set', () {
      const selection = ModelSelection(providerID: 'openai');
      expect(selection.displayName, 'openai');
    });

    test('displayName returns providerID when modelID is null but providerID is set', () {
      const selection = ModelSelection(providerID: 'anthropic', modelID: null);
      expect(selection.displayName, 'anthropic');
    });
  });

  group('ModelSelectionNotifier', () {
    group('initial state', () {
      test('is correct with no saved selection', () {
        final container = ProviderContainer(
          overrides: [
            modelSelectionProvider.overrideWith(() => TestModelSelectionNotifier()),
          ],
        );
        addTearDown(container.dispose);

        final state = container.read(modelSelectionProvider);
        expect(state.providerID, isNull);
        expect(state.modelID, isNull);
        expect(state.isDefault, true);
      });

      test('is correct with saved selection', () {
        final container = ProviderContainer(
          overrides: [
            modelSelectionProvider.overrideWith(() => TestModelSelectionNotifier(
              savedProviderId: 'openai',
              savedModelId: 'gpt-4',
            )),
          ],
        );
        addTearDown(container.dispose);

        final state = container.read(modelSelectionProvider);
        expect(state.providerID, 'openai');
        expect(state.modelID, 'gpt-4');
        expect(state.isDefault, false);
        expect(state.displayName, 'gpt-4');
      });
    });

    group('select', () {
      test('saves to storage and updates state', () async {
        String? savedProviderId;
        String? savedModelId;

        final container = ProviderContainer(
          overrides: [
            modelSelectionProvider.overrideWith(() => TestModelSelectionNotifier(
              onSave: (providerId, modelId) {
                savedProviderId = providerId;
                savedModelId = modelId;
              },
            )),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(modelSelectionProvider.notifier);
        await notifier.select('anthropic', 'claude-3');

        expect(savedProviderId, 'anthropic');
        expect(savedModelId, 'claude-3');
        expect(notifier.state.providerID, 'anthropic');
        expect(notifier.state.modelID, 'claude-3');
        expect(notifier.state.isDefault, false);
        expect(notifier.state.displayName, 'claude-3');
      });
    });

    group('reset', () {
      test('clears storage and resets state', () async {
        bool cleared = false;

        final container = ProviderContainer(
          overrides: [
            modelSelectionProvider.overrideWith(() => TestModelSelectionNotifier(
              savedProviderId: 'openai',
              savedModelId: 'gpt-4',
              onClear: () {
                cleared = true;
              },
            )),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(modelSelectionProvider.notifier);
        await notifier.reset();

        expect(cleared, true);
        expect(notifier.state.providerID, isNull);
        expect(notifier.state.modelID, isNull);
        expect(notifier.state.isDefault, true);
        expect(notifier.state.displayName, 'Default');
      });
    });
  });
}

class TestModelSelectionNotifier extends ModelSelectionNotifier {
  final String? savedProviderId;
  final String? savedModelId;
  final void Function(String?, String?)? onSave;
  final void Function()? onClear;

  TestModelSelectionNotifier({
    this.savedProviderId,
    this.savedModelId,
    this.onSave,
    this.onClear,
  });

  @override
  ModelSelection build() {
    return ModelSelection(
      providerID: savedProviderId,
      modelID: savedModelId,
    );
  }

  @override
  Future<void> select(String providerId, String modelId) async {
    onSave?.call(providerId, modelId);
    state = ModelSelection(providerID: providerId, modelID: modelId);
  }

  @override
  Future<void> reset() async {
    onClear?.call();
    state = const ModelSelection();
  }
}
