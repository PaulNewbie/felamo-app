import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppFontSize { small, medium, large }

extension AppFontSizeX on AppFontSize {
  double get scale {
    switch (this) {
      case AppFontSize.small:
        return 0.9;
      case AppFontSize.medium:
        return 1.0;
      case AppFontSize.large:
        return 1.2;
    }
  }

  String get label {
    switch (this) {
      case AppFontSize.small:
        return 'Maliit';
      case AppFontSize.medium:
        return 'Katamtaman';
      case AppFontSize.large:
        return 'Malaki';
    }
  }
}

class FontScaleController extends ChangeNotifier {
  static const _prefsKey = 'app_font_size';

  AppFontSize _fontSize = AppFontSize.medium;
  AppFontSize get fontSize => _fontSize;
  double get scale => _fontSize.scale;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null) {
      _fontSize = AppFontSize.values.firstWhere(
        (e) => e.name == saved,
        orElse: () => AppFontSize.medium,
      );
      notifyListeners();
    }
  }

  Future<void> setFontSize(AppFontSize size) async {
    _fontSize = size;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, size.name);
  }
}

// Single global instance — simplest option given your app doesn't use
// Provider/Riverpod elsewhere.
final fontScaleController = FontScaleController();