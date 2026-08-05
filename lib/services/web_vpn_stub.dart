import 'dart:async';

import 'package:wireguard_flutter/wireguard_flutter_platform_interface.dart';

/// Browser preview stub — WireGuard cannot tunnel from Chrome.
class WebVpnStub extends WireGuardFlutterInterface {
  final _controller = StreamController<VpnStage>.broadcast();
  VpnStage _stage = VpnStage.disconnected;

  @override
  Stream<VpnStage> get vpnStageSnapshot => _controller.stream;

  @override
  Future<void> initialize({required String interfaceName}) async {
    _stage = VpnStage.disconnected;
    _controller.add(_stage);
  }

  @override
  Future<void> startVpn({
    required String serverAddress,
    required String wgQuickConfig,
    required String providerBundleIdentifier,
  }) async {
    _stage = VpnStage.connecting;
    _controller.add(_stage);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _stage = VpnStage.connected;
    _controller.add(_stage);
  }

  @override
  Future<void> stopVpn() async {
    _stage = VpnStage.disconnecting;
    _controller.add(_stage);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _stage = VpnStage.disconnected;
    _controller.add(_stage);
  }

  @override
  Future<void> refreshStage() async {}

  @override
  Future<VpnStage> stage() async => _stage;
}
