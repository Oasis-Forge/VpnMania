import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/server_profile.dart';

/// Loads gitignored `servers.local.json` from cwd or next to the executable.
Future<ServerCatalog?> loadLocalServerCatalog(String relativePath) async {
  final candidates = <File>[
    File(relativePath),
  ];

  try {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    candidates.add(File('$exeDir/servers.local.json'));
    candidates.add(File('$exeDir/assets/config/servers.local.json'));
  } catch (_) {}

  for (final file in candidates) {
    try {
      if (!await file.exists()) continue;
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) continue;
      return ServerCatalog.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (error, stack) {
      debugPrint('Local override ${file.path} failed: $error\n$stack');
    }
  }
  return null;
}
