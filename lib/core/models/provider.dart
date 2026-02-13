class ProviderModel {
  final String id;
  final String name;
  final double? costInput;
  final double? costOutput;
  final int? contextWindow;
  final int? maxOutput;

  ProviderModel({
    required this.id,
    required this.name,
    this.costInput,
    this.costOutput,
    this.contextWindow,
    this.maxOutput,
  });

  factory ProviderModel.fromJson(Map<String, dynamic> json) {
    return ProviderModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      costInput: (json['cost'] as Map<String, dynamic>?)?['input'] as double?,
      costOutput: (json['cost'] as Map<String, dynamic>?)?['output'] as double?,
      contextWindow: json['context'] as int?,
      maxOutput: json['limit'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (costInput != null || costOutput != null)
        'cost': {
          if (costInput != null) 'input': costInput,
          if (costOutput != null) 'output': costOutput,
        },
      if (contextWindow != null) 'context': contextWindow,
      if (maxOutput != null) 'limit': maxOutput,
    };
  }
}

class Provider {
  final String id;
  final String name;
  final List<ProviderModel> models;
  final bool configured;

  Provider({
    required this.id,
    required this.name,
    List<ProviderModel>? models,
    this.configured = false,
  }) : models = models ?? [];

  factory Provider.fromJson(Map<String, dynamic> json) {
    final modelsData = json['models'];
    List<ProviderModel> modelsList = [];
    
    if (modelsData is Map<String, dynamic>) {
      modelsList = modelsData.entries.map((e) {
        final modelData = e.value as Map<String, dynamic>? ?? {};
        return ProviderModel(
          id: e.key,
          name: modelData['name'] as String? ?? e.key,
          costInput: (modelData['cost'] as Map<String, dynamic>?)?['input'] as double?,
          costOutput: (modelData['cost'] as Map<String, dynamic>?)?['output'] as double?,
          contextWindow: modelData['context'] as int?,
          maxOutput: modelData['limit'] as int?,
        );
      }).toList();
    } else if (modelsData is List<dynamic>) {
      modelsList = modelsData
          .map((m) => ProviderModel.fromJson(m as Map<String, dynamic>))
          .toList();
    }

    return Provider(
      id: json['id'] as String? ?? json['name'] as String? ?? '',
      name: json['name'] as String? ?? json['id'] as String? ?? '',
      models: modelsList,
      configured: json['configured'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'models': models.map((m) => m.toJson()).toList(),
      'configured': configured,
    };
  }
}

class ProvidersResponse {
  final List<Provider> providers;
  final Map<String, String> defaults;

  ProvidersResponse({
    required this.providers,
    this.defaults = const {},
  });

  factory ProvidersResponse.fromJson(Map<String, dynamic> json) {
    final providersList = json['providers'] as List<dynamic>? ?? [];
    final defaultsMap = json['default'] as Map<String, dynamic>? ?? {};
    return ProvidersResponse(
      providers: providersList
          .map((p) => Provider.fromJson(p as Map<String, dynamic>))
          .toList(),
      defaults: defaultsMap.map((k, v) => MapEntry(k, v.toString())),
    );
  }
}
