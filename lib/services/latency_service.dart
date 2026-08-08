import '../models/server_profile.dart';
import 'latency_service_stub.dart'
    if (dart.library.io) 'latency_service_io.dart' as impl;

/// Measures endpoint RTT for Smart connect / Recommended sorting.
class LatencyService {
  LatencyService({Duration cacheTtl = const Duration(minutes: 2)})
      : _inner = impl.createLatencyService(cacheTtl: cacheTtl);

  final impl.LatencyServiceBackend _inner;

  Future<Duration?> measure(ServerProfile profile) => _inner.measure(profile);

  Future<Map<String, Duration?>> measureAll(List<ServerProfile> profiles) =>
      _inner.measureAll(profiles);

  Future<ServerProfile?> pickFastest(List<ServerProfile> profiles) =>
      _inner.pickFastest(profiles);

  Duration? cached(String serverId) => _inner.cached(serverId);

  void invalidate() => _inner.invalidate();
}
