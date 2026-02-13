class ProjectIcon {
  final String? url;
  final String? override;
  final String? color;

  ProjectIcon({this.url, this.override, this.color});

  factory ProjectIcon.fromJson(Map<String, dynamic> json) {
    return ProjectIcon(
      url: json['url'] as String?,
      override: json['override'] as String?,
      color: json['color'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (url != null) 'url': url,
      if (override != null) 'override': override,
      if (color != null) 'color': color,
    };
  }
}

class ProjectCommands {
  final String? start;

  ProjectCommands({this.start});

  factory ProjectCommands.fromJson(Map<String, dynamic> json) {
    return ProjectCommands(
      start: json['start'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (start != null) 'start': start,
    };
  }
}

class Project {
  final String id;
  final String? worktree;
  final String? vcs;
  final DateTime? createdAt;
  final ProjectIcon? icon;
  final ProjectCommands? commands;

  Project({
    required this.id,
    this.worktree,
    this.vcs,
    this.createdAt,
    this.icon,
    this.commands,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String? ?? '',
      worktree: json['worktree'] as String?,
      vcs: json['vcs'] as String?,
      createdAt: json['time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['time']['created'] as num).toInt())
          : null,
      icon: json['icon'] != null
          ? ProjectIcon.fromJson(json['icon'] as Map<String, dynamic>)
          : null,
      commands: json['commands'] != null
          ? ProjectCommands.fromJson(json['commands'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (worktree != null) 'worktree': worktree,
      if (vcs != null) 'vcs': vcs,
      if (createdAt != null) 'time': createdAt!.millisecondsSinceEpoch,
      if (icon != null) 'icon': icon!.toJson(),
      if (commands != null) 'commands': commands!.toJson(),
    };
  }

  String get displayName {
    if (worktree == null || worktree!.isEmpty) return id;
    final parts = worktree!.split('/');
    return parts.last.isNotEmpty ? parts.last : id;
  }
}

class ProjectUpdateInput {
  final String? name;
  final ProjectIcon? icon;
  final ProjectCommands? commands;

  ProjectUpdateInput({this.name, this.icon, this.commands});

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (icon != null) 'icon': icon!.toJson(),
      if (commands != null) 'commands': commands!.toJson(),
    };
  }
}
