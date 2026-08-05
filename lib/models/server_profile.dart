/// A WireGuard server profile used to reach Discord where it is blocked.
class ServerProfile {
  const ServerProfile({
    required this.id,
    required this.name,
    required this.serverAddress,
    required this.wgQuickConfig,
    this.region,
    this.discordOptimized = true,
  });

  final String id;
  final String name;
  final String serverAddress;
  final String wgQuickConfig;
  final String? region;

  /// When true, eligible for Recommended / Smart connect.
  final bool discordOptimized;

  /// True when config still uses placeholder keys / example host.
  bool get isPlaceholder {
    final cfg = wgQuickConfig.toUpperCase();
    return serverAddress.contains('example.com') ||
        serverAddress.contains('YOUR_VPS') ||
        cfg.contains('REPLACE_WITH') ||
        cfg.contains('PASTE_');
  }

  factory ServerProfile.fromJson(Map<String, dynamic> json) {
    return ServerProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      serverAddress: json['serverAddress'] as String,
      wgQuickConfig: json['wgQuickConfig'] as String,
      region: json['region'] as String?,
      discordOptimized: json['discordOptimized'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'serverAddress': serverAddress,
        'wgQuickConfig': wgQuickConfig,
        if (region != null) 'region': region,
        'discordOptimized': discordOptimized,
      };
}

class ServerCatalog {
  const ServerCatalog({required this.servers});

  final List<ServerProfile> servers;

  factory ServerCatalog.fromJson(Map<String, dynamic> json) {
    final list = json['servers'] as List<dynamic>? ?? const [];
    return ServerCatalog(
      servers: list
          .map((e) => ServerProfile.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'servers': servers.map((s) => s.toJson()).toList(),
      };

  bool get hasOnlyPlaceholders =>
      servers.isEmpty || servers.every((s) => s.isPlaceholder);

  List<ServerProfile> get discordServers =>
      servers.where((s) => s.discordOptimized).toList();

  ServerProfile? findById(String id) {
    for (final server in servers) {
      if (server.id == id) return server;
    }
    return null;
  }
}
