import 'package:flutter/material.dart';

import '../models/server_profile.dart';
import '../services/config_repository.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.configRepository,
    required this.catalog,
    required this.selectedServer,
    required this.onServerChanged,
    required this.onReloadCatalog,
  });

  final ConfigRepository configRepository;
  final ServerCatalog catalog;
  final ServerProfile? selectedServer;
  final ValueChanged<ServerProfile> onServerChanged;
  final Future<void> Function() onReloadCatalog;

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
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Server',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.muted,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
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
          const Text(
            'Remote config URL',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.muted,
              letterSpacing: 0.6,
            ),
          ),
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
          const Text(
            'About',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.muted,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'VpnMania tunnels your device traffic over WireGuard so you can '
            'reach Discord in regions where the chat app is blocked.\n\n'
            'Your traffic is sent through the configured VPN server while '
            'connected. Ping/latency-based server picking is planned for a '
            'later release.',
            style: TextStyle(
              color: AppTheme.onSurface,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
