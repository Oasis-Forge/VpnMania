import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vpnmania/services/local_config_loader_io.dart';

void main() {
  test('loadLocalServerCatalog reads override file', () async {
    final dir = await Directory.systemTemp.createTemp('vpnmania_cfg_');
    final file = File('${dir.path}/servers.local.json');
    await file.writeAsString(
      jsonEncode({
        'servers': [
          {
            'id': 'live',
            'name': 'Live',
            'serverAddress': '1.2.3.4:51820',
            'wgQuickConfig': '[Interface]\nPrivateKey = x',
          },
        ],
      }),
    );

    final catalog = await loadLocalServerCatalog(file.path);
    expect(catalog, isNotNull);
    expect(catalog!.servers.single.id, 'live');

    await dir.delete(recursive: true);
  });
}
