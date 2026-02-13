import 'package:uuid/uuid.dart';

enum MessageRole { user, assistant }

enum MessagePartType {
  text,
  reasoning,
  tool,
  file,
  stepStart,
  stepFinish,
  snapshot,
  patch,
  error,
}

class MessagePart {
  final String id;
  final MessagePartType type;
  final String? text;
  final Map<String, dynamic>? toolData;
  final Map<String, dynamic>? fileData;
  final String? error;

  MessagePart({
    String? id,
    required this.type,
    this.text,
    this.toolData,
    this.fileData,
    this.error,
  }) : id = id ?? const Uuid().v4();

  factory MessagePart.fromJson(Map<String, dynamic> json) {
    return MessagePart(
      id: json['id'] as String?,
      type: _parseType(json['type'] as String?),
      text: json['text'] as String?,
      toolData: json['tool'] is Map ? json['tool'] as Map<String, dynamic> : null,
      fileData: json['file'] as Map<String, dynamic>?,
      error: json['error'] as String?,
    );
  }

  static MessagePartType _parseType(String? type) {
    return switch (type) {
      'text' => MessagePartType.text,
      'reasoning' => MessagePartType.reasoning,
      'tool' => MessagePartType.tool,
      'tool-call' => MessagePartType.tool,
      'file' => MessagePartType.file,
      'step-start' => MessagePartType.stepStart,
      'step-finish' => MessagePartType.stepFinish,
      'snapshot' => MessagePartType.snapshot,
      'patch' => MessagePartType.patch,
      'error' => MessagePartType.error,
      _ => MessagePartType.text,
    };
  }

  String? get toolName => toolData?['name'] as String?;
  String? get toolState => toolData?['state'] as String?;
  String? get toolInput => toolData?['input']?.toString();
  String? get toolOutput => toolData?['output']?.toString();

  bool get isToolPending => toolState == 'pending';
  bool get isToolRunning => toolState == 'running';
  bool get isToolCompleted => toolState == 'completed';
  bool get isToolError => toolState == 'error';
}

class Message {
  final String id;
  final String sessionId;
  final MessageRole role;
  final DateTime createdAt;
  final DateTime? completedAt;
  final List<MessagePart> parts;
  final String? parentMessageId;
  final String? modelId;
  final String? providerId;
  final double? cost;
  final Map<String, dynamic>? tokens;
  final String? error;
  final String? finishReason;

  Message({
    String? id,
    required this.sessionId,
    required this.role,
    DateTime? createdAt,
    this.completedAt,
    List<MessagePart>? parts,
    this.parentMessageId,
    this.modelId,
    this.providerId,
    this.cost,
    this.tokens,
    this.error,
    this.finishReason,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        parts = parts ?? [];

  factory Message.fromJson(Map<String, dynamic> json) {
    final partsList = json['parts'] as List<dynamic>? ?? [];
    return Message(
      id: json['id'] as String?,
      sessionId: json['sessionID'] as String? ?? json['sessionId'] as String? ?? '',
      role: json['role'] == 'assistant' ? MessageRole.assistant : MessageRole.user,
      createdAt: json['time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['time']['created'] as num).toInt())
          : null,
      completedAt: json['time'] != null && json['time']['completed'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['time']['completed'] as num).toInt())
          : null,
      parts: partsList
          .map((p) => MessagePart.fromJson(p as Map<String, dynamic>))
          .toList(),
      parentMessageId: json['parentID'] as String?,
      modelId: json['modelID'] as String?,
      providerId: json['providerID'] as String?,
      cost: (json['cost'] as num?)?.toDouble(),
      tokens: json['tokens'] as Map<String, dynamic>?,
      error: json['error']?['message'] as String?,
      finishReason: json['finish'] as String?,
    );
  }

  String get textContent {
    return parts
        .where((p) => p.type == MessagePartType.text)
        .map((p) => p.text ?? '')
        .join('\n');
  }

  List<MessagePart> get toolParts =>
      parts.where((p) => p.type == MessagePartType.tool).toList();

  Message copyWith({
    String? id,
    String? sessionId,
    MessageRole? role,
    DateTime? createdAt,
    DateTime? completedAt,
    List<MessagePart>? parts,
    String? parentMessageId,
    String? modelId,
    String? providerId,
    double? cost,
    Map<String, dynamic>? tokens,
    String? error,
    String? finishReason,
  }) {
    return Message(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      parts: parts ?? this.parts,
      parentMessageId: parentMessageId ?? this.parentMessageId,
      modelId: modelId ?? this.modelId,
      providerId: providerId ?? this.providerId,
      cost: cost ?? this.cost,
      tokens: tokens ?? this.tokens,
      error: error ?? this.error,
      finishReason: finishReason ?? this.finishReason,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionID': sessionId,
      'role': role.name,
      'time': {
        'created': createdAt.millisecondsSinceEpoch,
        if (completedAt != null)
          'completed': completedAt!.millisecondsSinceEpoch,
      },
      'parts': parts.map((p) => {
        'id': p.id,
        'type': p.type.name,
        if (p.text != null) 'text': p.text,
        if (p.toolData != null) 'tool': p.toolData,
        if (p.fileData != null) 'file': p.fileData,
      }).toList(),
    };
  }
}
