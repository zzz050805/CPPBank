import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class AppPreferences extends ChangeNotifier {
  AppPreferences._();

  static final AppPreferences instance = AppPreferences._();

  Locale _locale = const Locale('vi');

  Locale get locale => _locale;

  static const List<Locale> supportedLocales = [Locale('vi'), Locale('en')];

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
}
