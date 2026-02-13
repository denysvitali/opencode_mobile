class Project {
  final String id;
  final String? worktree;
  final String? vcs;
  final DateTime? createdAt;

  Project({
    required this.id,
    this.worktree,
    this.vcs,
    this.createdAt,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (worktree != null) 'worktree': worktree,
      if (vcs != null) 'vcs': vcs,
      if (createdAt != null) 'time': createdAt!.millisecondsSinceEpoch,
    };
  }

  String get displayName {
    if (worktree == null || worktree!.isEmpty) return id;
    final parts = worktree!.split('/');
    return parts.last.isNotEmpty ? parts.last : id;
  }
}
