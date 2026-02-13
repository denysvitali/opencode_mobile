class Provider {
  final String id;
  final String name;
  final List<String> models;
  final bool isDefault;

  Provider({
    required this.id,
    required this.name,
    this.models = const [],
    this.isDefault = false,
  });

  factory Provider.fromJson(Map<String, dynamic> json) {
    // models can be a Map (id -> model details) or a List
    List<String> modelIds = [];
    final modelsData = json['models'];
    if (modelsData is Map<String, dynamic>) {
      modelIds = modelsData.keys.toList();
    } else if (modelsData is List<dynamic>) {
      modelIds = modelsData.map((e) => e.toString()).toList();
    }

    return Provider(
      id: json['id'] as String? ?? json['name'] as String? ?? '',
      name: json['name'] as String? ?? json['id'] as String? ?? '',
      models: modelIds,
      isDefault: json['default'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'models': models,
      'default': isDefault,
    };
  }
}
