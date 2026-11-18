import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';

/// Provider for managing and persisting global application theme mode (Light / Dark).
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  bool _isInitialized = false;

  ThemeProvider({bool autoLoad = true}) {
    if (autoLoad) {
      loadThemePreference();
    }
  }

  ThemeMode get themeMode => _themeMode;
  bool get isInitialized => _isInitialized;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Loads saved theme preference from local storage.
  Future<void> loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(AppConstants.keyAppTheme);
      if (savedMode != null) {
        if (savedMode == 'dark') {
          _themeMode = ThemeMode.dark;
        } else if (savedMode == 'light') {
          _themeMode = ThemeMode.light;
        } else if (savedMode == 'system') {
          _themeMode = ThemeMode.system;
        }
      }
    } catch (e) {
      debugPrint("ThemeProvider: error loading saved theme: $e");
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Sets and persists a specific theme mode.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final modeString = mode == ThemeMode.dark
          ? 'dark'
          : mode == ThemeMode.system
          ? 'system'
          : 'light';
      await prefs.setString(AppConstants.keyAppTheme, modeString);
    } catch (e) {
      debugPrint("ThemeProvider: error saving theme preference: $e");
    }
  }

  /// Toggles between Light and Dark mode.
  Future<void> toggleTheme() async {
    final nextMode = _themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    await setThemeMode(nextMode);
  }
}
