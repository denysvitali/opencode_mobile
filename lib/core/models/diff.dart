class DiffHunk {
  final int oldStart;
  final int oldLines;
  final int newStart;
  final int newLines;
  final String content;

  DiffHunk({
    required this.oldStart,
    required this.oldLines,
    required this.newStart,
    required this.newLines,
    required this.content,
  });

  factory DiffHunk.fromJson(Map<String, dynamic> json) {
    return DiffHunk(
      oldStart: json['oldStart'] as int? ?? 0,
      oldLines: json['oldLines'] as int? ?? 0,
      newStart: json['newStart'] as int? ?? 0,
      newLines: json['newLines'] as int? ?? 0,
      content: json['content'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'oldStart': oldStart,
      'oldLines': oldLines,
      'newStart': newStart,
      'newLines': newLines,
      'content': content,
    };
  }
}

class FileDiff {
  final String path;
  final String? oldPath;
  final String status;
  final int additions;
  final int deletions;
  final List<DiffHunk> hunks;
  final String? content;

  FileDiff({
    required this.path,
    this.oldPath,
    required this.status,
    this.additions = 0,
    this.deletions = 0,
    this.hunks = const [],
    this.content,
  });

  factory FileDiff.fromJson(Map<String, dynamic> json) {
    final hunksList = json['hunks'] as List<dynamic>? ?? [];
    return FileDiff(
      path: json['path'] as String? ?? '',
      oldPath: json['oldPath'] as String?,
      status: json['status'] as String? ?? 'modified',
      additions: json['additions'] as int? ?? 0,
      deletions: json['deletions'] as int? ?? 0,
      hunks: hunksList
          .map((h) => DiffHunk.fromJson(h as Map<String, dynamic>))
          .toList(),
      content: json['content'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      if (oldPath != null) 'oldPath': oldPath,
      'status': status,
      'additions': additions,
      'deletions': deletions,
      'hunks': hunks.map((h) => h.toJson()).toList(),
      if (content != null) 'content': content,
    };
  }

  bool get isBinary => status == 'binary';
  bool get isAdded => status == 'added';
  bool get isDeleted => status == 'deleted';
  bool get isRenamed => status == 'renamed';
  bool get isModified => status == 'modified';
}

class SessionDiff {
  final List<FileDiff> files;
  final int totalAdditions;
  final int totalDeletions;

  SessionDiff({
    required this.files,
    this.totalAdditions = 0,
    this.totalDeletions = 0,
  });

  factory SessionDiff.fromJson(Map<String, dynamic> json) {
    final filesList = json['files'] as List<dynamic>? ?? [];
    final diffs = filesList
        .map((f) => FileDiff.fromJson(f as Map<String, dynamic>))
        .toList();
    return SessionDiff(
      files: diffs,
      totalAdditions: diffs.fold(0, (sum, f) => sum + f.additions),
      totalDeletions: diffs.fold(0, (sum, f) => sum + f.deletions),
    );
  }
}
