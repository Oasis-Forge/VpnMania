import 'package:flutter/material.dart';

import 'models/server_profile.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'services/config_repository.dart';
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
  final VpnController _vpn = VpnController();

  ServerCatalog? _catalog;
  ServerProfile? _selected;
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
    try {
      await _vpn.initialize();
    } catch (_) {
      // Initialize may fail until VPN permission / admin is granted.
      // UI still loads; connect will retry.
    }
    try {
      await _reloadCatalog();
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

  Future<void> _selectServer(ServerProfile profile) async {
    await _configRepository.setSelectedServerId(profile.id);
    setState(() => _selected = profile);
  }

  void _openSettings() {
    final catalog = _catalog;
    if (catalog == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsScreen(
          configRepository: _configRepository,
          catalog: catalog,
          selectedServer: _selected,
          onServerChanged: (profile) async {
            await _selectServer(profile);
          },
          onReloadCatalog: _reloadCatalog,
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
      onServerChanged: _selectServer,
      onOpenSettings: _openSettings,
    );
  }
}
