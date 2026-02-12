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
