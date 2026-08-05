import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wireguard_flutter/wireguard_flutter.dart';
import 'package:wireguard_flutter/wireguard_flutter_platform_interface.dart';

import '../models/server_profile.dart';

/// Thin facade over [WireGuardFlutter] for connect / disconnect / status.
class VpnController extends ChangeNotifier {
  VpnController({
    WireGuardFlutterInterface? wireguard,
    this.interfaceName = 'wg0',
    this.providerBundleIdentifier = 'com.vpnmania.vpnmania.WGExtension',
  }) : _wireguard = wireguard ?? WireGuardFlutter.instance;

  final WireGuardFlutterInterface _wireguard;
  final String interfaceName;

  /// iOS/macOS Network Extension bundle id (ignored on Android/Windows).
  final String providerBundleIdentifier;

  VpnStage _stage = VpnStage.disconnected;
  String? _error;
  bool _initialized = false;
  StreamSubscription<VpnStage>? _stageSub;

  VpnStage get stage => _stage;
  String? get error => _error;
  bool get isConnected => _stage == VpnStage.connected;
  bool get isBusy =>
      _stage == VpnStage.connecting ||
      _stage == VpnStage.disconnecting ||
      _stage == VpnStage.preparing ||
      _stage == VpnStage.authenticating;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await _wireguard.initialize(interfaceName: interfaceName);
      _stageSub = _wireguard.vpnStageSnapshot.listen((event) {
        _stage = event;
        notifyListeners();
      });
      _stage = await _wireguard.stage();
      _initialized = true;
      _error = null;
      notifyListeners();
    } catch (error, stack) {
      debugPrint('VPN initialize failed: $error\n$stack');
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> connect(ServerProfile profile) async {
    _error = null;
    _stage = VpnStage.connecting;
    notifyListeners();
    try {
      if (!_initialized) {
        await initialize();
      }
      await _wireguard.startVpn(
        serverAddress: profile.serverAddress,
        wgQuickConfig: profile.wgQuickConfig,
        providerBundleIdentifier: providerBundleIdentifier,
      );
      _stage = await _wireguard.stage();
      notifyListeners();
    } catch (error, stack) {
      debugPrint('VPN connect failed: $error\n$stack');
      _error = error.toString();
      _stage = VpnStage.disconnected;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    _error = null;
    _stage = VpnStage.disconnecting;
    notifyListeners();
    try {
      await _wireguard.stopVpn();
      _stage = await _wireguard.stage();
      notifyListeners();
    } catch (error, stack) {
      debugPrint('VPN disconnect failed: $error\n$stack');
      _error = error.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> refresh() async {
    try {
      await _wireguard.refreshStage();
      _stage = await _wireguard.stage();
      notifyListeners();
    } catch (error, stack) {
      debugPrint('VPN refresh failed: $error\n$stack');
    }
  }

  String statusLabel() {
    switch (_stage) {
      case VpnStage.connected:
        return 'Connected';
      case VpnStage.connecting:
      case VpnStage.preparing:
      case VpnStage.authenticating:
      case VpnStage.waitingConnection:
        return 'Connecting…';
      case VpnStage.disconnecting:
      case VpnStage.exiting:
        return 'Disconnecting…';
      case VpnStage.denied:
        return 'Permission denied';
      case VpnStage.noConnection:
        return 'No connection';
      case VpnStage.reconnect:
        return 'Reconnecting…';
      case VpnStage.disconnected:
        return 'Disconnected';
    }
  }

  @override
  void dispose() {
    _stageSub?.cancel();
    super.dispose();
  }
}
