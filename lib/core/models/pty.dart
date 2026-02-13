class PtySize {
  final int rows;
  final int cols;

  PtySize({required this.rows, required this.cols});

  factory PtySize.fromJson(Map<String, dynamic> json) {
    return PtySize(
      rows: json['rows'] as int? ?? 24,
      cols: json['cols'] as int? ?? 80,
    );
  }

  Map<String, dynamic> toJson() => {'rows': rows, 'cols': cols};
}

enum PtyStatus { running, exited }

class Pty {
  final String id;
  final String command;
  final List<String> args;
  final String? cwd;
  final String? title;
  final PtyStatus status;
  final int? exitCode;
  final PtySize? size;
  final Map<String, String>? env;
  final DateTime createdAt;

  Pty({
    required this.id,
    required this.command,
    this.args = const [],
    this.cwd,
    this.title,
    this.status = PtyStatus.running,
    this.exitCode,
    this.size,
    this.env,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Pty.fromJson(Map<String, dynamic> json) {
    return Pty(
      id: json['id'] as String? ?? '',
      command: json['command'] as String? ?? '',
      args: (json['args'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      cwd: json['cwd'] as String?,
      title: json['title'] as String?,
      status: json['status'] == 'exited' ? PtyStatus.exited : PtyStatus.running,
      exitCode: json['exitCode'] as int?,
      size: json['size'] != null ? PtySize.fromJson(json['size'] as Map<String, dynamic>) : null,
      env: (json['env'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v.toString())),
      createdAt: json['time'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['time'] as num).toInt())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'command': command,
      'args': args,
      if (cwd != null) 'cwd': cwd,
      if (title != null) 'title': title,
      'status': status.name,
      if (exitCode != null) 'exitCode': exitCode,
      if (size != null) 'size': size!.toJson(),
      if (env != null) 'env': env,
      'time': createdAt.millisecondsSinceEpoch,
    };
  }
}

class PtyCreateInput {
  final String command;
  final List<String>? args;
  final String? cwd;
  final String? title;
  final Map<String, String>? env;

  PtyCreateInput({
    required this.command,
    this.args,
    this.cwd,
    this.title,
    this.env,
  });

  Map<String, dynamic> toJson() {
    return {
      'command': command,
      if (args != null) 'args': args,
      if (cwd != null) 'cwd': cwd,
      if (title != null) 'title': title,
      if (env != null) 'env': env,
    };
  }
}

class PtyUpdateInput {
  final String? title;
  final PtySize? size;

  PtyUpdateInput({this.title, this.size});

  Map<String, dynamic> toJson() {
    return {
      if (title != null) 'title': title,
      if (size != null) 'size': size!.toJson(),
    };
  }
}
