import 'package:uuid/uuid.dart';

enum SessionStatus {
  idle,
  pending,
  running,
  compacting,
}

class PermissionRuleset {
  final String mode;
  final List<String>? allow;
  final List<String>? deny;

  PermissionRuleset({
    this.mode = 'auto',
    this.allow,
    this.deny,
  });

  factory PermissionRuleset.fromJson(Map<String, dynamic> json) {
    return PermissionRuleset(
      mode: json['mode'] as String? ?? 'auto',
      allow: (json['allow'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
      deny: (json['deny'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode,
      if (allow != null) 'allow': allow,
      if (deny != null) 'deny': deny,
    };
  }
}

class Session {
  final String id;
  final String? parentID;
  final String? title;
  final String? description;
  final SessionStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? archivedAt;
  final String? summary;
  final double? cost;
  final String path;
  final String? projectID;
  final PermissionRuleset? permission;

  Session({
    String? id,
    this.parentID,
    this.title,
    this.description,
    this.status = SessionStatus.idle,
    DateTime? createdAt,
    this.completedAt,
    this.archivedAt,
    this.summary,
    this.cost,
    this.path = '',
    this.projectID,
    this.permission,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  factory Session.fromJson(Map<String, dynamic> json) {
    final sessionId = json['id'] as String? ??
        json['sessionID'] as String? ??
        json['sessionId'] as String? ??
        '';
    return Session(
      id: sessionId,
      parentID: json['parentID'] as String?,
      title: json['title'] as String?,
      description: json['description'] as String?,
      status: _parseStatus(json['status'] as String?),
      createdAt: json['time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['time']['created'] as num).toInt())
          : null,
      completedAt: json['time'] != null && json['time']['completed'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['time']['completed'] as num).toInt())
          : null,
      archivedAt: json['time'] != null && json['time']['archived'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['time']['archived'] as num).toInt())
          : null,
      summary: json['summary'] is String ? json['summary'] as String : json['summary']?.toString(),
      cost: (json['cost'] as num?)?.toDouble(),
      path: json['path']?['cwd'] as String? ?? '',
      projectID: json['projectID'] as String?,
      permission: json['permission'] != null
          ? PermissionRuleset.fromJson(json['permission'] as Map<String, dynamic>)
          : null,
    );
  }

  static SessionStatus _parseStatus(String? status) {
    return switch (status) {
      'idle' => SessionStatus.idle,
      'pending' => SessionStatus.pending,
      'running' => SessionStatus.running,
      'compacting' => SessionStatus.compacting,
      _ => SessionStatus.idle,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (parentID != null) 'parentID': parentID,
      'title': title,
      'description': description,
      'status': status.name,
      'time': {
        'created': createdAt.millisecondsSinceEpoch,
        if (completedAt != null) 'completed': completedAt!.millisecondsSinceEpoch,
        if (archivedAt != null) 'archived': archivedAt!.millisecondsSinceEpoch,
      },
      'summary': summary,
      'cost': cost,
      'path': {'cwd': path},
      if (projectID != null) 'projectID': projectID,
      if (permission != null) 'permission': permission!.toJson(),
    };
  }

  Session copyWith({
    String? id,
    String? parentID,
    String? title,
    String? description,
    SessionStatus? status,
    DateTime? createdAt,
    DateTime? completedAt,
    DateTime? archivedAt,
    String? summary,
    double? cost,
    String? path,
    String? projectID,
    PermissionRuleset? permission,
  }) {
    return Session(
      id: id ?? this.id,
      parentID: parentID ?? this.parentID,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      summary: summary ?? this.summary,
      cost: cost ?? this.cost,
      path: path ?? this.path,
      projectID: projectID ?? this.projectID,
      permission: permission ?? this.permission,
    );
  }

  String get displayName => title?.isNotEmpty == true ? title! : 'New Session';
  bool get isArchived => archivedAt != null;
  bool get isChild => parentID != null;
}

class SessionUpdateInput {
  final String? title;
  final int? archivedAt;

  SessionUpdateInput({this.title, this.archivedAt});

  Map<String, dynamic> toJson() {
    return {
      if (title != null) 'title': title,
      if (archivedAt != null)
        'time': {'archived': archivedAt},
    };
  }
}

class SessionCreateInput {
  final String? parentID;
  final String? title;
  final PermissionRuleset? permission;

  SessionCreateInput({this.parentID, this.title, this.permission});

  Map<String, dynamic> toJson() {
    return {
      if (parentID != null) 'parentID': parentID,
      if (title != null) 'title': title,
      if (permission != null) 'permission': permission!.toJson(),
    };
  }
}
