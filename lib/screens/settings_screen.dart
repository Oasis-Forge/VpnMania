import 'package:flutter/material.dart';

import '../models/server_profile.dart';
import '../services/app_settings.dart';
import '../services/config_repository.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.configRepository,
    required this.settings,
    required this.catalog,
    required this.selectedServer,
    required this.onServerChanged,
    required this.onReloadCatalog,
    required this.onSettingsChanged,
  });

  final ConfigRepository configRepository;
  final AppSettings settings;
  final ServerCatalog catalog;
  final ServerProfile? selectedServer;
  final ValueChanged<ServerProfile> onServerChanged;
  final Future<void> Function() onReloadCatalog;
  final VoidCallback onSettingsChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _urlController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    final url = await widget.configRepository.getRemoteConfigUrl();
    if (!mounted) return;
    _urlController.text = url ?? '';
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _saveUrl() async {
    setState(() => _saving = true);
    try {
      await widget.configRepository.setRemoteConfigUrl(
        _urlController.text.trim(),
      );
      await widget.onReloadCatalog();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Config refreshed')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to refresh: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _SectionLabel('Connection'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-connect on launch'),
            subtitle: const Text('Connect to the last Discord server when the app starts'),
            value: s.autoConnect,
            onChanged: (v) async {
              await s.setAutoConnect(v);
              widget.onSettingsChanged();
              setState(() {});
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-reconnect on drop'),
            subtitle: const Text('Retry with backoff if the tunnel drops unexpectedly'),
            value: s.autoReconnect,
            onChanged: (v) async {
              await s.setAutoReconnect(v);
              widget.onSettingsChanged();
              setState(() {});
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Kill switch (Windows)'),
            subtitle: const Text(
              'Best-effort: block outbound traffic if the VPN drops. '
              'Requires Administrator. See docs/KILL_SWITCH.md.',
            ),
            value: s.killSwitch,
            onChanged: (v) async {
              await s.setKillSwitch(v);
              widget.onSettingsChanged();
              setState(() {});
            },
          ),
          const Divider(height: 32),
          const _SectionLabel('Server'),
          ...widget.catalog.servers.map((server) {
            final selected = server.id == widget.selectedServer?.id;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(server.name),
              subtitle: Text(server.region ?? server.serverAddress),
              trailing: selected
                  ? const Icon(Icons.check_circle, color: AppTheme.accent)
                  : null,
              onTap: () => widget.onServerChanged(server),
            );
          }),
          const Divider(height: 32),
          const _SectionLabel('Remote config URL'),
          const SizedBox(height: 8),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              hintText: 'https://example.com/servers.json',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _saveUrl,
            child: Text(_saving ? 'Saving…' : 'Save & refresh'),
          ),
          const Divider(height: 40),
          const _SectionLabel('About'),
          const SizedBox(height: 8),
          const Text(
            'VpnMania is a Discord-focused WireGuard client: connect so chat '
            'and voice work where Discord is blocked.\n\n'
            'Traffic is full-tunneled while connected. Smart connect picks the '
            'lowest-latency Discord-optimized server. Kill switch is Windows '
            'firewall best-effort, not a kernel driver.',
            style: TextStyle(color: AppTheme.onSurface, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.muted,
        letterSpacing: 0.6,
      ),
    );
  }
}
