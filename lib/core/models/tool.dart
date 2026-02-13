class ToolParameter {
  final String type;
  final String? description;
  final bool required;
  final Map<String, dynamic>? properties;
  final List<String>? enumValues;

  ToolParameter({
    required this.type,
    this.description,
    this.required = false,
    this.properties,
    this.enumValues,
  });

  factory ToolParameter.fromJson(Map<String, dynamic> json) {
    return ToolParameter(
      type: json['type'] as String? ?? 'string',
      description: json['description'] as String?,
      required: json['required'] as bool? ?? false,
      properties: json['properties'] as Map<String, dynamic>?,
      enumValues: (json['enum'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
    );
  }
}

class ToolInputSchema {
  final String type;
  final Map<String, ToolParameter> properties;
  final List<String> required;

  ToolInputSchema({
    this.type = 'object',
    Map<String, ToolParameter>? properties,
    this.required = const [],
  }) : properties = properties ?? {};

  factory ToolInputSchema.fromJson(Map<String, dynamic> json) {
    final props = json['properties'] as Map<String, dynamic>? ?? {};
    final reqList = (json['required'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    return ToolInputSchema(
      type: json['type'] as String? ?? 'object',
      properties: props.map((k, v) => MapEntry(k, ToolParameter.fromJson(v as Map<String, dynamic>))),
      required: reqList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'properties': properties.map((k, v) => MapEntry(k, {
        'type': v.type,
        if (v.description != null) 'description': v.description,
        if (v.properties != null) 'properties': v.properties,
        if (v.enumValues != null) 'enum': v.enumValues,
      })),
      'required': required,
    };
  }
}

class Tool {
  final String name;
  final String? description;
  final ToolInputSchema? inputSchema;

  Tool({
    required this.name,
    this.description,
    this.inputSchema,
  });

  factory Tool.fromJson(Map<String, dynamic> json) {
    return Tool(
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      inputSchema: json['inputSchema'] != null
          ? ToolInputSchema.fromJson(json['inputSchema'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (description != null) 'description': description,
      if (inputSchema != null) 'inputSchema': inputSchema!.toJson(),
    };
  }
}

class ToolList {
  final List<Tool> tools;

  ToolList({required this.tools});

  factory ToolList.fromJson(Map<String, dynamic> json) {
    final toolsList = json['tools'] as List<dynamic>? ?? [];
    return ToolList(
      tools: toolsList.map((t) => Tool.fromJson(t as Map<String, dynamic>)).toList(),
    );
  }
}
