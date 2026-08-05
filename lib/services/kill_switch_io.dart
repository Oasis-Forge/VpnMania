import 'dart:io';

import 'package:flutter/foundation.dart';

KillSwitchBackend createKillSwitch() => WindowsKillSwitch();

abstract class KillSwitchBackend {
  bool get isArmed;
  Future<void> arm();
  Future<void> disarm();
}

/// Windows Firewall outbound block while armed. See docs/KILL_SWITCH.md.
class WindowsKillSwitch implements KillSwitchBackend {
  static const ruleName = 'VpnManiaKillSwitch';

  bool _armed = false;

  @override
  bool get isArmed => _armed;

  @override
  Future<void> arm() async {
    if (!Platform.isWindows) {
      debugPrint('Kill switch arm skipped (not Windows)');
      return;
    }
    try {
      await _runPowerShell('''
\$name = '$ruleName'
if (-not (Get-NetFirewallRule -DisplayName \$name -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -DisplayName \$name -Direction Outbound -Action Block -Enabled True -Profile Any | Out-Null
} else {
  Enable-NetFirewallRule -DisplayName \$name | Out-Null
}
''');
      _armed = true;
      debugPrint('Kill switch armed');
    } catch (error, stack) {
      debugPrint('Kill switch arm failed: $error\n$stack');
      rethrow;
    }
  }

  @override
  Future<void> disarm() async {
    if (!Platform.isWindows) return;
    try {
      await _runPowerShell('''
\$name = '$ruleName'
\$rule = Get-NetFirewallRule -DisplayName \$name -ErrorAction SilentlyContinue
if (\$rule) { Disable-NetFirewallRule -DisplayName \$name | Out-Null }
''');
      _armed = false;
      debugPrint('Kill switch disarmed');
    } catch (error, stack) {
      debugPrint('Kill switch disarm failed: $error\n$stack');
    }
  }

  Future<void> _runPowerShell(String script) async {
    final result = await Process.run(
      'powershell',
      ['-NoProfile', '-NonInteractive', '-Command', script],
      runInShell: true,
    );
    if (result.exitCode != 0) {
      throw StateError(
        'PowerShell exit ${result.exitCode}: ${result.stderr}',
      );
    }
  }
}
