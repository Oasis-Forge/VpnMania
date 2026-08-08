import 'kill_switch_stub.dart'
    if (dart.library.io) 'kill_switch_io.dart' as impl;

/// Best-effort fail-safe when the WireGuard tunnel drops unexpectedly.
class KillSwitchService {
  KillSwitchService() : _backend = impl.createKillSwitch();

  final impl.KillSwitchBackend _backend;

  bool get isArmed => _backend.isArmed;

  Future<void> arm() => _backend.arm();

  Future<void> disarm() => _backend.disarm();
}
