import 'package:shared_preferences/shared_preferences.dart';

import 'demo_storage_contract.dart';

DemoStorage createPlatformDemoStorage() => _SharedPreferencesDemoStorage();

class _SharedPreferencesDemoStorage implements DemoStorage {
  SharedPreferences? _preferences;

  Future<SharedPreferences> get _instance async =>
      _preferences ??= await SharedPreferences.getInstance();

  @override
  Future<String?> getString(String key) async =>
      (await _instance).getString(key);

  @override
  Future<void> setString(String key, String value) async {
    await (await _instance).setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await (await _instance).remove(key);
  }
}
