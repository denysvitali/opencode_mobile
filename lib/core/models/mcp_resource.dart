class McpResource {
  final String uri;
  final String name;
  final String? description;
  final String? mimeType;

  McpResource({
    required this.uri,
    required this.name,
    this.description,
    this.mimeType,
  });

  factory McpResource.fromJson(Map<String, dynamic> json) {
    return McpResource(
      uri: json['uri'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      mimeType: json['mimeType'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uri': uri,
      'name': name,
      if (description != null) 'description': description,
      if (mimeType != null) 'mimeType': mimeType,
    };
  }
}
