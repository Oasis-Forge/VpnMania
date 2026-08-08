import 'package:shared_preferences/shared_preferences.dart';

/// User preferences for Discord-focused reliability UX.
class AppSettings {
  static const _autoConnectKey = 'vpnmania.auto_connect';
  static const _autoReconnectKey = 'vpnmania.auto_reconnect';
  static const _killSwitchKey = 'vpnmania.kill_switch';

  bool autoConnect = false;
  bool autoReconnect = true;
  bool killSwitch = false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    autoConnect = prefs.getBool(_autoConnectKey) ?? false;
    autoReconnect = prefs.getBool(_autoReconnectKey) ?? true;
    killSwitch = prefs.getBool(_killSwitchKey) ?? false;
  }

  Future<void> setAutoConnect(bool value) async {
    autoConnect = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoConnectKey, value);
  }

  Future<void> setAutoReconnect(bool value) async {
    autoReconnect = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoReconnectKey, value);
  }

  Future<void> setKillSwitch(bool value) async {
    killSwitch = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_killSwitchKey, value);
  }
}
