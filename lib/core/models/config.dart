class ServerConfig {
  final String url;
  final String? username;
  final String? password;
  final bool isConnected;
  final String? version;

  ServerConfig({
    this.url = 'http://localhost:4096',
    this.username,
    this.password,
    this.isConnected = false,
    this.version,
  });

  ServerConfig copyWith({
    String? url,
    String? username,
    String? password,
    bool? isConnected,
    String? version,
  }) {
    return ServerConfig(
      url: url ?? this.url,
      username: username ?? this.username,
      password: password ?? this.password,
      isConnected: isConnected ?? this.isConnected,
      version: version ?? this.version,
    );
  }

  bool get hasAuth => username != null && username!.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'username': username,
      'password': password,
      'isConnected': isConnected,
      'version': version,
    };
  }

  factory ServerConfig.fromJson(Map<String, dynamic> json) {
    return ServerConfig(
      url: json['url'] as String? ?? 'http://localhost:4096',
      username: json['username'] as String?,
      password: json['password'] as String?,
      isConnected: json['isConnected'] as bool? ?? false,
      version: json['version'] as String?,
    );
  }
}

class AppConfigAgent {
  final String? model;
  final String? provider;

  AppConfigAgent({this.model, this.provider});

  factory AppConfigAgent.fromJson(Map<String, dynamic> json) {
    return AppConfigAgent(
      model: json['model'] as String?,
      provider: json['provider'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (model != null) 'model': model,
      if (provider != null) 'provider': provider,
    };
  }
}

class AppConfig {
  final String? theme;
  final AppConfigAgent? agent;
  final Map<String, dynamic>? provider;
  final Map<String, dynamic>? mcp;
  final Map<String, dynamic>? plugin;

  AppConfig({
    this.theme,
    this.agent,
    this.provider,
    this.mcp,
    this.plugin,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      theme: json['theme'] as String?,
      agent: json['agent'] != null
          ? AppConfigAgent.fromJson(json['agent'] as Map<String, dynamic>)
          : null,
      provider: json['provider'] as Map<String, dynamic>?,
      mcp: json['mcp'] as Map<String, dynamic>?,
      plugin: json['plugin'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (theme != null) 'theme': theme,
      if (agent != null) 'agent': agent!.toJson(),
      if (provider != null) 'provider': provider,
      if (mcp != null) 'mcp': mcp,
      if (plugin != null) 'plugin': plugin,
    };
  }

  AppConfig copyWith({
    String? theme,
    AppConfigAgent? agent,
    Map<String, dynamic>? provider,
    Map<String, dynamic>? mcp,
    Map<String, dynamic>? plugin,
  }) {
    return AppConfig(
      theme: theme ?? this.theme,
      agent: agent ?? this.agent,
      provider: provider ?? this.provider,
      mcp: mcp ?? this.mcp,
      plugin: plugin ?? this.plugin,
    );
  }
}
