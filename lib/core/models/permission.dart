class Permission {
  final String id;
  final String sessionId;
  final String type;
  final String? message;
  final Map<String, dynamic>? data;
  final DateTime createdAt;

  Permission({
    required this.id,
    required this.sessionId,
    required this.type,
    this.message,
    this.data,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Permission.fromJson(Map<String, dynamic> json) {
    return Permission(
      id: json['id'] as String? ?? '',
      sessionId: json['sessionID'] as String? ?? '',
      type: json['type'] as String? ?? '',
      message: json['message'] as String?,
      data: json['data'] as Map<String, dynamic>?,
      createdAt: json['time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['time'] as num).toInt())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionID': sessionId,
      'type': type,
      if (message != null) 'message': message,
      if (data != null) 'data': data,
      'time': createdAt.millisecondsSinceEpoch,
    };
  }
}
