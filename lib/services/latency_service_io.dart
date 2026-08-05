import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/server_profile.dart';

LatencyServiceBackend createLatencyService({
  Duration cacheTtl = const Duration(minutes: 2),
}) =>
    IoLatencyService(cacheTtl: cacheTtl);

abstract class LatencyServiceBackend {
  Future<Duration?> measure(ServerProfile profile);
  Future<Map<String, Duration?>> measureAll(List<ServerProfile> profiles);
  Future<ServerProfile?> pickFastest(List<ServerProfile> profiles);
  Duration? cached(String serverId);
  void invalidate();
}

class IoLatencyService implements LatencyServiceBackend {
  IoLatencyService({this.cacheTtl = const Duration(minutes: 2)});

  final Duration cacheTtl;
  final Map<String, _CacheEntry> _cache = {};

  @override
  Future<Duration?> measure(ServerProfile profile) async {
    final cached = _cache[profile.id];
    if (cached != null &&
        DateTime.now().difference(cached.at) < cacheTtl) {
      return cached.rtt;
    }

    final hostPort = _parseHostPort(profile.serverAddress);
    if (hostPort == null) {
      _cache[profile.id] = _CacheEntry(null, DateTime.now());
      return null;
    }

    final stopwatch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(
        hostPort.$1,
        hostPort.$2,
        timeout: const Duration(seconds: 3),
      );
      stopwatch.stop();
      await socket.close();
      final rtt = stopwatch.elapsed;
      _cache[profile.id] = _CacheEntry(rtt, DateTime.now());
      return rtt;
    } catch (error) {
      debugPrint('Latency probe failed for ${profile.serverAddress}: $error');
      _cache[profile.id] = _CacheEntry(null, DateTime.now());
      return null;
    }
  }

  @override
  Future<Map<String, Duration?>> measureAll(List<ServerProfile> profiles) async {
    final results = <String, Duration?>{};
    await Future.wait(profiles.map((p) async {
      results[p.id] = await measure(p);
    }));
    return results;
  }

  @override
  Future<ServerProfile?> pickFastest(List<ServerProfile> profiles) async {
    final candidates =
        profiles.where((p) => p.discordOptimized && !p.isPlaceholder).toList();
    final pool = candidates.isNotEmpty
        ? candidates
        : profiles.where((p) => !p.isPlaceholder).toList();
    if (pool.isEmpty) {
      return profiles.isEmpty ? null : profiles.first;
    }

    Duration? best;
    ServerProfile? winner;
    for (final profile in pool) {
      final rtt = await measure(profile);
      if (rtt == null) continue;
      if (best == null || rtt < best) {
        best = rtt;
        winner = profile;
      }
    }
    return winner ?? pool.first;
  }

  @override
  Duration? cached(String serverId) => _cache[serverId]?.rtt;

  @override
  void invalidate() => _cache.clear();

  (String, int)? _parseHostPort(String address) {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return null;
    late final String host;
    late final String portStr;
    if (trimmed.startsWith('[')) {
      final end = trimmed.indexOf(']');
      host = trimmed.substring(1, end);
      portStr = trimmed.contains(']:')
          ? trimmed.substring(end + 2)
          : '51820';
    } else {
      final parts = trimmed.split(':');
      host = parts.first;
      portStr = parts.length > 1 ? parts.last : '51820';
    }
    final port = int.tryParse(portStr) ?? 51820;
    if (host.isEmpty) return null;
    return (host, port);
  }
}

class _CacheEntry {
  _CacheEntry(this.rtt, this.at);
  final Duration? rtt;
  final DateTime at;
}
