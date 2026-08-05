import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/server_profile.dart';

/// Loads WireGuard server profiles over HTTPS, with a local cache and
/// bundled asset fallback for offline / first-run use.
class ConfigRepository {
  ConfigRepository({
    http.Client? client,
    this.remoteConfigUrl,
    this.assetPath = 'assets/config/servers.json',
  }) : _client = client ?? http.Client();

  static const _cacheKey = 'vpnmania.server_catalog';
  static const _selectedServerKey = 'vpnmania.selected_server_id';
  static const _configUrlKey = 'vpnmania.config_url';

  /// Optional HTTPS endpoint that returns the same JSON shape as [assetPath].
  /// Override at runtime via [setRemoteConfigUrl].
  final String? remoteConfigUrl;
  final String assetPath;
  final http.Client _client;

  Future<ServerCatalog> loadCatalog() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_configUrlKey) ?? remoteConfigUrl;

    if (url != null && url.isNotEmpty) {
      try {
        final catalog = await _fetchRemote(url);
        await _writeCache(prefs, catalog);
        return catalog;
      } catch (error, stack) {
        debugPrint('Remote config fetch failed: $error\n$stack');
      }
    }

    final cached = prefs.getString(_cacheKey);
    if (cached != null && cached.isNotEmpty) {
      try {
        return ServerCatalog.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        );
      } catch (error, stack) {
        debugPrint('Cache parse failed: $error\n$stack');
      }
    }

    return _loadAsset();
  }

  Future<ServerCatalog> _fetchRemote(String url) async {
    final response = await _client
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Config HTTP ${response.statusCode}');
    }
    return ServerCatalog.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<ServerCatalog> _loadAsset() async {
    final raw = await rootBundle.loadString(assetPath);
    return ServerCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> _writeCache(SharedPreferences prefs, ServerCatalog catalog) {
    return prefs.setString(_cacheKey, jsonEncode(catalog.toJson()));
  }

  Future<String?> getSelectedServerId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedServerKey);
  }

  Future<void> setSelectedServerId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedServerKey, id);
  }

  Future<void> setRemoteConfigUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null || url.isEmpty) {
      await prefs.remove(_configUrlKey);
    } else {
      await prefs.setString(_configUrlKey, url);
    }
  }

  Future<String?> getRemoteConfigUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_configUrlKey) ?? remoteConfigUrl;
  }
}
