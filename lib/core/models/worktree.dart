class Worktree {
  final String path;
  final String branch;
  final String head;

  Worktree({
    required this.path,
    required this.branch,
    required this.head,
  });

  factory Worktree.fromJson(Map<String, dynamic> json) {
    return Worktree(
      path: json['path'] as String? ?? '',
      branch: json['branch'] as String? ?? '',
      head: json['head'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'branch': branch,
      'head': head,
    };
  }
}

class WorktreeCreateInput {
  final String? branch;
  final bool? createBranch;

  WorktreeCreateInput({this.branch, this.createBranch});

  Map<String, dynamic> toJson() {
    return {
      if (branch != null) 'branch': branch,
      if (createBranch != null) 'createBranch': createBranch,
    };
  }
}

class WorktreeRemoveInput {
  final String directory;

  WorktreeRemoveInput({required this.directory});

  Map<String, dynamic> toJson() => {'directory': directory};
}

class WorktreeResetInput {
  final String directory;

  WorktreeResetInput({required this.directory});

  Map<String, dynamic> toJson() => {'directory': directory};
}
