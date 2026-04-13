import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences extends ChangeNotifier {
  AppPreferences._();

  static final AppPreferences instance = AppPreferences._();

  Locale _locale = const Locale('vi');
  static const String _localePreferenceKey = 'app_locale_code';
  bool _didLoadSavedLocale = false;

  Locale get locale => _locale;

  static const List<Locale> supportedLocales = [Locale('vi'), Locale('en')];

  Future<void> loadSavedLocale() async {
    if (_didLoadSavedLocale) {
      return;
    }
    _didLoadSavedLocale = true;

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String code = (prefs.getString(_localePreferenceKey) ?? '').trim();
      if (code.isEmpty) {
        return;
      }

      final bool isSupported = supportedLocales.any(
        (Locale locale) => locale.languageCode == code,
      );
      if (!isSupported) {
        return;
      }

      _locale = Locale(code);
    } catch (_) {
      // Keep default locale if shared preferences is unavailable.
    }
  }

  void setLocale(Locale locale) {
    if (_locale == locale) {
      return;
    }
    _locale = locale;

    final SchedulerPhase phase = WidgetsBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  Future<void> setLocaleAndPersist(Locale locale) async {
    setLocale(locale);
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_localePreferenceKey, locale.languageCode);
    } catch (_) {
      // Keep runtime locale change even if persistence fails.
    }
  }
}
