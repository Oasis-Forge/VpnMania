import '../models/server_profile.dart';

LatencyServiceBackend createLatencyService({
  Duration cacheTtl = const Duration(minutes: 2),
}) =>
    _StubLatency(cacheTtl: cacheTtl);

abstract class LatencyServiceBackend {
  Future<Duration?> measure(ServerProfile profile);
  Future<Map<String, Duration?>> measureAll(List<ServerProfile> profiles);
  Future<ServerProfile?> pickFastest(List<ServerProfile> profiles);
  Duration? cached(String serverId);
  void invalidate();
}

class _StubLatency implements LatencyServiceBackend {
  _StubLatency({required this.cacheTtl});
  final Duration cacheTtl;

  @override
  Future<Duration?> measure(ServerProfile profile) async => null;

  @override
  Future<Map<String, Duration?>> measureAll(List<ServerProfile> profiles) async =>
      {for (final p in profiles) p.id: null};

  @override
  Future<ServerProfile?> pickFastest(List<ServerProfile> profiles) async =>
      profiles.isEmpty ? null : profiles.first;

  @override
  Duration? cached(String serverId) => null;

  @override
  void invalidate() {}
}
