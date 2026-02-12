class Project {
  final String id;
  final String name;
  final String path;
  final String? description;

  Project({
    required this.id,
    required this.name,
    required this.path,
    this.description,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled Project',
      path: json['path'] as String? ?? '',
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'path': path,
      if (description != null) 'description': description,
    };
  }
}
