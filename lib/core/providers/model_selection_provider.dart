import 'package:flutter/material.dart';
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

class ProvidersState {
  final List<models.Provider> providers;
  final bool isLoading;
  final String? error;

  const ProvidersState({
    this.providers = const [],
    this.isLoading = false,
    this.error,
  });

  ProvidersState copyWith({
    List<models.Provider>? providers,
    bool? isLoading,
    String? error,
  }) {
    return ProvidersState(
      providers: providers ?? this.providers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ProvidersNotifier extends Notifier<ProvidersState> {
  @override
  ProvidersState build() {
    return const ProvidersState();
  }

  Future<void> fetch() async {
    debugPrint('ProvidersNotifier: fetch() called');
    state = state.copyWith(isLoading: true, error: null);

    try {
      final client = OpenCodeClient();
      debugPrint('ProvidersNotifier: client URL = ${client.config.url}');
      try {
        debugPrint('ProvidersNotifier: calling getConfigProviders()');
        final response = await client.getConfigProviders();
        debugPrint('ProvidersNotifier: got ${response.providers.length} providers');
        state = ProvidersState(providers: response.providers, isLoading: false);
      } catch (e) {
        debugPrint('ProvidersNotifier: getConfigProviders failed: $e');
        try {
          final providers = await client.getProviders();
          debugPrint('ProvidersNotifier: getProviders returned ${providers.length} providers');
          state = ProvidersState(providers: providers, isLoading: false);
        } catch (e2) {
          debugPrint('ProvidersNotifier: getProviders also failed: $e2');
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('ProvidersNotifier: final error: $e');
      state = ProvidersState(isLoading: false, error: e.toString());
    }
  }

  void clear() {
    state = const ProvidersState();
  }
}

final providersProvider = NotifierProvider<ProvidersNotifier, ProvidersState>(
  ProvidersNotifier.new,
);
