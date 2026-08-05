import 'package:flutter/material.dart';
import 'package:wireguard_flutter/wireguard_flutter.dart';

import '../models/server_profile.dart';
import '../services/vpn_controller.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.vpn,
    required this.catalog,
    required this.selectedServer,
    required this.onServerChanged,
    required this.onOpenSettings,
  });

  final VpnController vpn;
  final ServerCatalog catalog;
  final ServerProfile? selectedServer;
  final ValueChanged<ServerProfile> onServerChanged;
  final VoidCallback onOpenSettings;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _busy = false;

  Future<void> _toggle() async {
    final server = widget.selectedServer;
    if (server == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No server profile available.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      if (widget.vpn.isConnected) {
        await widget.vpn.disconnect();
      } else {
        await widget.vpn.connect(server);
      }
    } catch (_) {
      if (!mounted) return;
      final message = widget.vpn.error ?? 'Connection failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vpn = widget.vpn;

    return AnimatedBuilder(
      animation: vpn,
      builder: (context, _) {
        final server = widget.selectedServer;
        final connected = vpn.isConnected;
        final statusColor = connected
            ? AppTheme.success
            : vpn.stage == VpnStage.denied
                ? AppTheme.danger
                : AppTheme.muted;

        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'VpnMania',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Settings',
                        onPressed: widget.onOpenSettings,
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Connect so Discord works where it is blocked.',
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 16,
                      height: 1.35,
                    ),
                  ),
                  const Spacer(),
                  Center(
                    child: _StatusRing(
                      connected: connected,
                      busy: _busy || vpn.isBusy,
                      label: vpn.statusLabel(),
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (server != null)
                    _ServerChip(
                      profile: server,
                      profiles: widget.catalog.servers,
                      onChanged: widget.onServerChanged,
                    ),
                  if (vpn.error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      vpn.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.danger,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Center(
                    child: connected
                        ? OutlinedButton(
                            onPressed: _busy || vpn.isBusy ? null : _toggle,
                            child: const Text('Disconnect'),
                          )
                        : FilledButton(
                            onPressed: _busy || vpn.isBusy ? null : _toggle,
                            child: Text(
                              _busy || vpn.isBusy ? 'Please wait…' : 'Connect',
                            ),
                          ),
                  ),
                  const SizedBox(height: 24),
                  if (vpn.isWebPreview)
                    const Text(
                      'Browser preview only — WireGuard VPN requires Android, '
                      'iOS, or Windows.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    )
                  else
                    const Text(
                      'Full-tunnel WireGuard. Replace the sample server '
                      'config with your own endpoint before production use.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusRing extends StatelessWidget {
  const _StatusRing({
    required this.connected,
    required this.busy,
    required this.label,
    required this.color,
  });

  final bool connected;
  final bool busy;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: 0.35),
                AppTheme.card,
              ],
            ),
            border: Border.all(color: color, width: 3),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.25),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : Icon(
                    connected ? Icons.shield : Icons.shield_outlined,
                    size: 64,
                    color: color,
                  ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ServerChip extends StatelessWidget {
  const _ServerChip({
    required this.profile,
    required this.profiles,
    required this.onChanged,
  });

  final ServerProfile profile;
  final List<ServerProfile> profiles;
  final ValueChanged<ServerProfile> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: profiles.length < 2
            ? null
            : () async {
                final selected = await showModalBottomSheet<ServerProfile>(
                  context: context,
                  backgroundColor: AppTheme.surface,
                  builder: (context) {
                    return SafeArea(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                            child: Text(
                              'Choose server',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          for (final p in profiles)
                            ListTile(
                              title: Text(p.name),
                              subtitle: Text(p.region ?? p.serverAddress),
                              trailing: p.id == profile.id
                                  ? const Icon(
                                      Icons.check,
                                      color: AppTheme.accent,
                                    )
                                  : null,
                              onTap: () => Navigator.pop(context, p),
                            ),
                        ],
                      ),
                    );
                  },
                );
                if (selected != null) onChanged(selected);
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.dns_outlined, color: AppTheme.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurface,
                      ),
                    ),
                    Text(
                      profile.region ?? profile.serverAddress,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (profiles.length > 1)
                const Icon(Icons.expand_more, color: AppTheme.muted),
            ],
          ),
        ),
      ),
    );
  }
}
