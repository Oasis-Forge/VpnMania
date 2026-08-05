import '../models/server_profile.dart';

/// Placeholder for future ping / latency-based server selection.
///
/// Not used in the Discord-access MVP. Implement later to measure RTT to
/// WireGuard endpoints and pick the lowest-latency profile.
abstract class LatencyService {
  Future<Duration?> measure(ServerProfile profile);

  Future<ServerProfile?> pickFastest(List<ServerProfile> profiles);
}

class NoOpLatencyService implements LatencyService {
  @override
  Future<Duration?> measure(ServerProfile profile) async => null;

  @override
  Future<ServerProfile?> pickFastest(List<ServerProfile> profiles) async {
    if (profiles.isEmpty) return null;
    return profiles.first;
  }
}
