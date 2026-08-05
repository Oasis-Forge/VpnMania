import 'package:flutter/material.dart';

import '../models/server_profile.dart';
import '../services/latency_service.dart';
import '../theme/app_theme.dart';

class ServerPickerSheet extends StatefulWidget {
  const ServerPickerSheet({
    super.key,
    required this.catalog,
    required this.selected,
    required this.latency,
    required this.latencies,
    required this.onRefreshLatencies,
  });

  final ServerCatalog catalog;
  final ServerProfile? selected;
  final LatencyService latency;
  final Map<String, Duration?> latencies;
  final Future<void> Function() onRefreshLatencies;

  static Future<ServerProfile?> show(
    BuildContext context, {
    required ServerCatalog catalog,
    required ServerProfile? selected,
    required LatencyService latency,
    required Map<String, Duration?> latencies,
    required Future<void> Function() onRefreshLatencies,
  }) {
    return showModalBottomSheet<ServerProfile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (context, controller) => ServerPickerSheet(
          catalog: catalog,
          selected: selected,
          latency: latency,
          latencies: latencies,
          onRefreshLatencies: onRefreshLatencies,
        ),
      ),
    );
  }

  @override
  State<ServerPickerSheet> createState() => _ServerPickerSheetState();
}

class _ServerPickerSheetState extends State<ServerPickerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _search = TextEditingController();
  bool _probing = false;
  late Map<String, Duration?> _latencies;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _latencies = Map.of(widget.latencies);
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  List<ServerProfile> get _filtered {
    final q = _search.text.trim().toLowerCase();
    var list = widget.catalog.servers;
    if (q.isNotEmpty) {
      list = list
          .where(
            (s) =>
                s.name.toLowerCase().contains(q) ||
                (s.region?.toLowerCase().contains(q) ?? false) ||
                s.serverAddress.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  List<ServerProfile> get _recommended {
    final list = _filtered.where((s) => s.discordOptimized).toList();
    list.sort((a, b) {
      final la = _latencies[a.id];
      final lb = _latencies[b.id];
      if (la == null && lb == null) return a.name.compareTo(b.name);
      if (la == null) return 1;
      if (lb == null) return -1;
      return la.compareTo(lb);
    });
    return list;
  }

  Future<void> _refresh() async {
    setState(() => _probing = true);
    try {
      await widget.onRefreshLatencies();
      setState(() => _latencies = {
            for (final s in widget.catalog.servers)
              s.id: widget.latency.cached(s.id),
          });
    } finally {
      if (mounted) setState(() => _probing = false);
    }
  }

  String _badge(ServerProfile s) {
    final d = _latencies[s.id];
    if (d == null) return '—';
    return '${d.inMilliseconds} ms';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppTheme.muted.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Choose server',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: 'Refresh latency',
                onPressed: _probing ? null : _refresh,
                icon: _probing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.speed),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _search,
            decoration: const InputDecoration(
              hintText: 'Search name or region',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        TabBar(
          controller: _tabs,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.muted,
          tabs: const [
            Tab(text: 'Recommended'),
            Tab(text: 'All'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _list(_recommended),
              _list(_filtered),
            ],
          ),
        ),
      ],
    );
  }

  Widget _list(List<ServerProfile> servers) {
    if (servers.isEmpty) {
      return const Center(
        child: Text('No servers match', style: TextStyle(color: AppTheme.muted)),
      );
    }
    return ListView.builder(
      itemCount: servers.length,
      itemBuilder: (context, index) {
        final s = servers[index];
        final selected = s.id == widget.selected?.id;
        return ListTile(
          title: Text(s.name),
          subtitle: Text(s.region ?? s.serverAddress),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _badge(s),
                style: const TextStyle(color: AppTheme.muted, fontSize: 13),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                const Icon(Icons.check_circle, color: AppTheme.accent),
              ],
            ],
          ),
          onTap: () => Navigator.pop(context, s),
        );
      },
    );
  }
}
