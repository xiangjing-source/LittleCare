import 'package:web/web.dart' as web;

import 'demo_storage_contract.dart';

DemoStorage createPlatformDemoStorage() => _WebDemoStorage();

class _WebDemoStorage implements DemoStorage {
  @override
  Future<String?> getString(String key) async =>
      web.window.localStorage.getItem(key);

  @override
  Future<void> setString(String key, String value) async {
    web.window.localStorage.setItem(key, value);
  }

  @override
  Future<void> remove(String key) async {
    web.window.localStorage.removeItem(key);
  }
}
