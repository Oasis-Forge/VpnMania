import 'package:flutter/material.dart';
import 'package:wireguard_flutter/wireguard_flutter.dart';

import '../models/server_profile.dart';
import '../services/latency_service.dart';
import '../services/vpn_controller.dart';
import '../theme/app_theme.dart';
import 'server_picker_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.vpn,
    required this.catalog,
    required this.selectedServer,
    required this.latency,
    required this.latencies,
    required this.onServerChanged,
    required this.onOpenSettings,
    required this.onRefreshCatalog,
    required this.onRefreshLatencies,
    required this.onSmartConnect,
  });

  final VpnController vpn;
  final ServerCatalog catalog;
  final ServerProfile? selectedServer;
  final LatencyService latency;
  final Map<String, Duration?> latencies;
  final ValueChanged<ServerProfile> onServerChanged;
  final VoidCallback onOpenSettings;
  final Future<void> Function() onRefreshCatalog;
  final Future<void> Function() onRefreshLatencies;
  final Future<void> Function() onSmartConnect;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _busy = false;

  bool get _placeholderMode => widget.catalog.hasOnlyPlaceholders;

  Future<void> _toggle() async {
    if (_placeholderMode && !widget.vpn.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add a live WireGuard peer first (see NEXT_ACTIONS.md).',
          ),
        ),
      );
      return;
    }
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _smartConnect() async {
    setState(() => _busy = true);
    try {
      await widget.onSmartConnect();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.vpn.error ?? 'Smart connect failed')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPicker() async {
    final selected = await ServerPickerSheet.show(
      context,
      catalog: widget.catalog,
      selected: widget.selectedServer,
      latency: widget.latency,
      latencies: widget.latencies,
      onRefreshLatencies: widget.onRefreshLatencies,
    );
    if (selected != null) widget.onServerChanged(selected);
  }

  String? _latencyLabel(ServerProfile? server) {
    if (server == null) return null;
    final d = widget.latencies[server.id] ?? widget.latency.cached(server.id);
    if (d == null) return null;
    return '${d.inMilliseconds} ms';
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
        final duration = vpn.connectionDurationLabel();
        final busy = _busy || vpn.isBusy;

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
                        tooltip: 'Refresh servers',
                        onPressed: busy ? null : () => widget.onRefreshCatalog(),
                        icon: const Icon(Icons.refresh),
                      ),
                      IconButton(
                        tooltip: 'Settings',
                        onPressed: widget.onOpenSettings,
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Optimized for Discord',
                    style: TextStyle(
                      color: AppTheme.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Connect so Discord works where it is blocked.',
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                  if (_placeholderMode) ...[
                    const SizedBox(height: 16),
                    const _EmptyLivePeerCard(),
                  ],
                  const Spacer(),
                  Center(
                    child: _StatusRing(
                      connected: connected,
                      busy: busy,
                      label: vpn.statusLabel(),
                      color: statusColor,
                      duration: connected && duration.isNotEmpty ? duration : null,
                      protocol: 'WireGuard',
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (server != null)
                    Material(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: busy ? null : _openPicker,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.dns_outlined, color: AppTheme.accent),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      server.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.onSurface,
                                      ),
                                    ),
                                    Text(
                                      [
                                        server.region ?? server.serverAddress,
                                        if (_latencyLabel(server) != null)
                                          _latencyLabel(server)!,
                                      ].join(' · '),
                                      style: const TextStyle(
                                        color: AppTheme.muted,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.expand_more, color: AppTheme.muted),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (vpn.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      vpn.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.danger, fontSize: 13),
                    ),
                  ],
                  if (vpn.killSwitch.isArmed) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Kill switch armed — outbound traffic blocked until reconnect.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.danger, fontSize: 12),
                    ),
                  ],
                  const Spacer(),
                  if (!connected && !_placeholderMode) ...[
                    Center(
                      child: TextButton(
                        onPressed: busy ? null : _smartConnect,
                        child: const Text('Smart connect'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Center(
                    child: connected
                        ? OutlinedButton(
                            onPressed: busy ? null : _toggle,
                            child: const Text('Disconnect'),
                          )
                        : FilledButton(
                            onPressed: busy ? null : _toggle,
                            child: Text(busy ? 'Please wait…' : 'Connect'),
                          ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    vpn.isWebPreview
                        ? 'Browser preview only — WireGuard needs Android, iOS, or Windows.'
                        : 'Full-tunnel WireGuard · Discord-first',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
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

class _EmptyLivePeerCard extends StatelessWidget {
  const _EmptyLivePeerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.35)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No live VPN peer yet',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 6),
          Text(
            'Follow NEXT_ACTIONS.md: create a VPS, run server/setup-wireguard.sh, '
            'and save the JSON to assets/config/servers.local.json.',
            style: TextStyle(color: AppTheme.muted, fontSize: 13, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _StatusRing extends StatelessWidget {
  const _StatusRing({
    required this.connected,
    required this.busy,
    required this.label,
    required this.color,
    this.duration,
    this.protocol,
  });

  final bool connected;
  final bool busy;
  final String label;
  final Color color;
  final String? duration;
  final String? protocol;

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
              colors: [color.withValues(alpha: 0.35), AppTheme.card],
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
        const SizedBox(height: 16),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (duration != null) ...[
          const SizedBox(height: 4),
          Text(
            duration!,
            style: const TextStyle(
              color: AppTheme.onSurface,
              fontSize: 16,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
        if (protocol != null) ...[
          const SizedBox(height: 4),
          Text(
            protocol!,
            style: const TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
        ],
      ],
    );
  }
}
