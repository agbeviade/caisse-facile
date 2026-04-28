import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists ThemeMode in SharedPreferences and exposes it as a ValueNotifier
/// so widgets can rebuild on toggle.
class ThemeService {
  ThemeService._();
  static final ThemeService instance = ThemeService._();

  static const _key = 'theme_mode';

  final ValueNotifier<ThemeMode> mode =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key);
    mode.value = switch (v) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> set(ThemeMode m) async {
    mode.value = m;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, switch (m) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    });
  }
}
