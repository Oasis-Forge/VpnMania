import 'package:flutter_test/flutter_test.dart';
import 'package:vpnmania/models/server_profile.dart';

void main() {
  test('ServerCatalog parses bundled JSON shape', () {
    final catalog = ServerCatalog.fromJson({
      'servers': [
        {
          'id': 'a',
          'name': 'Discord Access',
          'serverAddress': 'example.com:51820',
          'wgQuickConfig': '[Interface]\nPrivateKey = x',
          'region': 'Global',
        },
      ],
    });

    expect(catalog.servers, hasLength(1));
    expect(catalog.findById('a')?.name, 'Discord Access');
  });
}
