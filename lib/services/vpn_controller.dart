import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wireguard_flutter/wireguard_flutter.dart';
import 'package:wireguard_flutter/wireguard_flutter_platform_interface.dart';

import '../models/server_profile.dart';
import 'app_settings.dart';
import 'kill_switch_service.dart';
import 'web_vpn_stub.dart';

/// Thin facade over [WireGuardFlutter] for connect / disconnect / status.
class VpnController extends ChangeNotifier {
  VpnController({
    WireGuardFlutterInterface? wireguard,
    AppSettings? settings,
    KillSwitchService? killSwitch,
    this.interfaceName = 'wg0',
    this.providerBundleIdentifier = 'com.vpnmania.vpnmania.WGExtension',
  })  : _wireguard = wireguard ?? _createBackend(),
        _settings = settings ?? AppSettings(),
        _killSwitch = killSwitch ?? KillSwitchService();

  static WireGuardFlutterInterface _createBackend() {
    if (kIsWeb) return WebVpnStub();
    return WireGuardFlutter.instance;
  }

  final WireGuardFlutterInterface _wireguard;
  final AppSettings _settings;
  final KillSwitchService _killSwitch;
  final String interfaceName;
  final String providerBundleIdentifier;

  VpnStage _stage = VpnStage.disconnected;
  String? _error;
  bool _initialized = false;
  StreamSubscription<VpnStage>? _stageSub;
  ServerProfile? _activeProfile;
  DateTime? _connectedAt;
  Timer? _ticker;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _userDisconnect = false;
  bool _reconnectInFlight = false;

  AppSettings get settings => _settings;
  KillSwitchService get killSwitch => _killSwitch;

  bool get isWebPreview => kIsWeb;
  VpnStage get stage => _stage;
  String? get error => _error;
  ServerProfile? get activeProfile => _activeProfile;
  DateTime? get connectedAt => _connectedAt;
  bool get isConnected => _stage == VpnStage.connected;
  bool get isBusy =>
      _stage == VpnStage.connecting ||
      _stage == VpnStage.disconnecting ||
      _stage == VpnStage.preparing ||
      _stage == VpnStage.authenticating ||
      _stage == VpnStage.reconnect;

  Duration? get connectionDuration {
    final start = _connectedAt;
    if (start == null || !isConnected) return null;
    return DateTime.now().difference(start);
  }

  String connectionDurationLabel() {
    final d = connectionDuration;
    if (d == null) return '';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '${d.inMinutes.toString().padLeft(2, '0')}:$s';
  }

  Future<void> loadSettings() => _settings.load();

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await _wireguard.initialize(interfaceName: interfaceName);
      _stageSub = _wireguard.vpnStageSnapshot.listen(_onStage);
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

  void _onStage(VpnStage event) {
    final wasConnected = _stage == VpnStage.connected;
    _stage = event;
    if (event == VpnStage.connected) {
      _connectedAt ??= DateTime.now();
      _reconnectAttempt = 0;
      _startTicker();
      _disarmKillSwitchSafe();
    } else if (event == VpnStage.disconnected ||
        event == VpnStage.noConnection ||
        event == VpnStage.denied) {
      _stopTicker();
      if (wasConnected && !_userDisconnect) {
        _handleUnexpectedDrop();
      }
      if (event != VpnStage.disconnected || _userDisconnect) {
        _connectedAt = null;
      }
    }
    notifyListeners();
  }

  Future<void> connect(ServerProfile profile) async {
    _userDisconnect = false;
    _reconnectTimer?.cancel();
    _error = null;
    _activeProfile = profile;
    _stage = VpnStage.connecting;
    notifyListeners();
    try {
      if (!_initialized) {
        await initialize();
      }
      if (_settings.killSwitch) {
        // Arm after connect succeeds? Express arms before — we arm on drop.
        // Pre-arm would block reaching the VPN endpoint. Only arm on drop.
      }
      await _wireguard.startVpn(
        serverAddress: profile.serverAddress,
        wgQuickConfig: profile.wgQuickConfig,
        providerBundleIdentifier: providerBundleIdentifier,
      );
      _stage = await _wireguard.stage();
      if (_stage == VpnStage.connected) {
        _connectedAt = DateTime.now();
        _startTicker();
      }
      notifyListeners();
    } catch (error, stack) {
      debugPrint('VPN connect failed: $error\n$stack');
      _error = error.toString();
      _stage = VpnStage.disconnected;
      _connectedAt = null;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    _userDisconnect = true;
    _reconnectTimer?.cancel();
    _error = null;
    _stage = VpnStage.disconnecting;
    notifyListeners();
    try {
      await _wireguard.stopVpn();
      await _killSwitch.disarm();
      _stage = await _wireguard.stage();
      _connectedAt = null;
      _stopTicker();
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

  void _handleUnexpectedDrop() {
    if (_settings.killSwitch) {
      unawaited(_armKillSwitchSafe());
    }
    if (_settings.autoReconnect && _activeProfile != null) {
      _scheduleReconnect();
    } else {
      _connectedAt = null;
    }
  }

  void _scheduleReconnect() {
    if (_reconnectInFlight || _userDisconnect) return;
    _stage = VpnStage.reconnect;
    notifyListeners();
    final delay = Duration(
      seconds: (1 << _reconnectAttempt.clamp(0, 4)).clamp(1, 16),
    );
    _reconnectAttempt++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      final profile = _activeProfile;
      if (profile == null || _userDisconnect) return;
      _reconnectInFlight = true;
      try {
        await connect(profile);
      } catch (_) {
        _scheduleReconnect();
      } finally {
        _reconnectInFlight = false;
      }
    });
  }

  Future<void> _armKillSwitchSafe() async {
    try {
      await _killSwitch.arm();
      notifyListeners();
    } catch (error) {
      _error = 'Kill switch failed: $error';
      notifyListeners();
    }
  }

  Future<void> _disarmKillSwitchSafe() async {
    try {
      await _killSwitch.disarm();
    } catch (_) {}
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (isConnected) notifyListeners();
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
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
    _ticker?.cancel();
    _reconnectTimer?.cancel();
    unawaited(_killSwitch.disarm());
    super.dispose();
  }
}
