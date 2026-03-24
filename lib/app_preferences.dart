import 'package:flutter/material.dart';

class AppPreferences extends ChangeNotifier {
  AppPreferences._();

  static final AppPreferences instance = AppPreferences._();

  Locale _locale = const Locale('vi');

  Locale get locale => _locale;

  static const List<Locale> supportedLocales = [Locale('vi'), Locale('en')];

  void setLocale(Locale locale) {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
  }
}
