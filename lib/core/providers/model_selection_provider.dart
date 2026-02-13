import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/opencode_client.dart';
import '../models/provider.dart' as models;
import '../services/storage_service.dart';

class ModelSelection {
  final String? providerID;
  final String? modelID;

  const ModelSelection({this.providerID, this.modelID});

  bool get isDefault => providerID == null && modelID == null;

  String get displayName {
    if (isDefault) return 'Default';
    if (modelID != null) return modelID!;
    return providerID ?? 'Default';
  }
}

class ModelSelectionNotifier extends Notifier<ModelSelection> {
  @override
  ModelSelection build() {
    final storage = StorageService();
    final providerId = storage.getSelectedProviderId();
    final modelId = storage.getSelectedModelId();
    return ModelSelection(providerID: providerId, modelID: modelId);
  }

  Future<void> select(String providerId, String modelId) async {
    await StorageService().saveModelSelection(providerId, modelId);
    state = ModelSelection(providerID: providerId, modelID: modelId);
  }

  Future<void> reset() async {
    await StorageService().saveModelSelection(null, null);
    state = const ModelSelection();
  }
}

final modelSelectionProvider =
    NotifierProvider<ModelSelectionNotifier, ModelSelection>(
  ModelSelectionNotifier.new,
);

final providersProvider =
    FutureProvider.autoDispose<List<models.Provider>>((ref) async {
  final client = OpenCodeClient();
  try {
    final response = await client.getConfigProviders();
    return response.providers;
  } catch (_) {
    try {
      return await client.getProviders();
    } catch (_) {
      return [];
    }
  }
});
