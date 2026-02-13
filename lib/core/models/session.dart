import 'package:uuid/uuid.dart';

enum SessionStatus {
  idle,
  pending,
  running,
  compacting,
}

class Session {
  final String id;
  final String? title;
  final String? description;
  final SessionStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? summary;
  final double? cost;
  final String path;
  final String? projectId;

  Session({
    String? id,
    this.title,
    this.description,
    this.status = SessionStatus.idle,
    DateTime? createdAt,
    this.completedAt,
    this.summary,
    this.cost,
    this.path = '',
    this.projectId,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  factory Session.fromJson(Map<String, dynamic> json) {
    // Handle different possible field names for session ID
    final sessionId = json['id'] as String? ??
        json['sessionID'] as String? ??
        json['sessionId'] as String? ??
        '';
    return Session(
      id: sessionId,
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
      summary: json['summary'] is String ? json['summary'] as String : json['summary']?.toString(),
      cost: (json['cost'] as num?)?.toDouble(),
      path: json['path']?['cwd'] as String? ?? '',
      projectId: json['projectID'] as String?,
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
      'title': title,
      'description': description,
      'status': status.name,
      'time': {
        'created': createdAt.millisecondsSinceEpoch,
        if (completedAt != null)
          'completed': completedAt!.millisecondsSinceEpoch,
      },
      'summary': summary,
      'cost': cost,
      'path': {'cwd': path},
      if (projectId != null) 'projectID': projectId,
    };
  }

  Session copyWith({
    String? id,
    String? title,
    String? description,
    SessionStatus? status,
    DateTime? createdAt,
    DateTime? completedAt,
    String? summary,
    double? cost,
    String? path,
    String? projectId,
  }) {
    return Session(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      summary: summary ?? this.summary,
      cost: cost ?? this.cost,
      path: path ?? this.path,
      projectId: projectId ?? this.projectId,
    );
  }

  String get displayName => title?.isNotEmpty == true ? title! : 'New Session';
}
