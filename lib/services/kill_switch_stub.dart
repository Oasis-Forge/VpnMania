KillSwitchBackend createKillSwitch() => _NoopKillSwitch();

abstract class KillSwitchBackend {
  bool get isArmed;
  Future<void> arm();
  Future<void> disarm();
}

class _NoopKillSwitch implements KillSwitchBackend {
  @override
  bool get isArmed => false;

  @override
  Future<void> arm() async {}

  @override
  Future<void> disarm() async {}
}
