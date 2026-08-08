import 'package:flutter/material.dart';

import 'models/server_profile.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'services/config_repository.dart';
import 'services/latency_service.dart';
import 'services/vpn_controller.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VpnManiaApp());
}

class VpnManiaApp extends StatelessWidget {
  const VpnManiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VpnMania',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final ConfigRepository _configRepository = ConfigRepository();
  final LatencyService _latency = LatencyService();
  late final VpnController _vpn = VpnController();

  ServerCatalog? _catalog;
  ServerProfile? _selected;
  Map<String, Duration?> _latencies = {};
  Object? _loadError;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    await _vpn.loadSettings();
    try {
      await _vpn.initialize();
    } catch (_) {}
    try {
      await _reloadCatalog();
      await _probeLatencies();
      if (_vpn.settings.autoConnect &&
          _selected != null &&
          !_selected!.isPlaceholder &&
          !_vpn.isConnected) {
        try {
          await _vpn.connect(_selected!);
        } catch (_) {}
      }
    } catch (error) {
      _loadError = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reloadCatalog() async {
    final catalog = await _configRepository.loadCatalog();
    final savedId = await _configRepository.getSelectedServerId();
    final selected = catalog.findById(savedId ?? '') ??
        (catalog.servers.isNotEmpty ? catalog.servers.first : null);
    if (!mounted) return;
    setState(() {
      _catalog = catalog;
      _selected = selected;
    });
  }

  Future<void> _probeLatencies() async {
    final catalog = _catalog;
    if (catalog == null) return;
    _latency.invalidate();
    final map = await _latency.measureAll(catalog.servers);
    if (!mounted) return;
    setState(() => _latencies = map);
  }

  Future<void> _selectServer(ServerProfile profile) async {
    await _configRepository.setSelectedServerId(profile.id);
    setState(() => _selected = profile);
  }

  Future<void> _smartConnect() async {
    final catalog = _catalog;
    if (catalog == null) return;
    if (catalog.hasOnlyPlaceholders) {
      throw StateError('Configure a live peer first (NEXT_ACTIONS.md)');
    }
    final best = await _latency.pickFastest(catalog.servers);
    if (best == null) throw StateError('No servers available');
    await _selectServer(best);
    await _vpn.connect(best);
  }

  void _openSettings() {
    final catalog = _catalog;
    if (catalog == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsScreen(
          configRepository: _configRepository,
          settings: _vpn.settings,
          catalog: catalog,
          selectedServer: _selected,
          onServerChanged: (profile) async {
            await _selectServer(profile);
          },
          onReloadCatalog: () async {
            await _reloadCatalog();
            await _probeLatencies();
          },
          onSettingsChanged: () => setState(() {}),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _vpn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null || _catalog == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Could not load server profiles.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Text('$_loadError', textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _bootstrap,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return HomeScreen(
      vpn: _vpn,
      catalog: _catalog!,
      selectedServer: _selected,
      latency: _latency,
      latencies: _latencies,
      onServerChanged: _selectServer,
      onOpenSettings: _openSettings,
      onRefreshCatalog: () async {
        await _reloadCatalog();
        await _probeLatencies();
      },
      onRefreshLatencies: _probeLatencies,
      onSmartConnect: _smartConnect,
    );
  }
}
