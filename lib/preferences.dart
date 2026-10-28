import 'package:shared_preferences/shared_preferences.dart';

class Preferences {
  static final String _cacheBootstrapped = 'CACHE_BOOTSTRAPPED';

  static Future<void> setCacheBootstrapped() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cacheBootstrapped, true);
  }

  static Future<bool> isCacheBootstrapped() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_cacheBootstrapped) ?? false;
  }

  /// Set when the user turned the bootstrap import down — „Most nem", or
  /// stopping the download — so that it is not offered again (ADR-0006).
  static final String _bootstrapDeclined = 'BOOTSTRAP_DECLINED';

  static Future<void> setBootstrapDeclined() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_bootstrapDeclined, true);
  }

  static Future<bool> isBootstrapDeclined() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_bootstrapDeclined) ?? false;
  }
}
