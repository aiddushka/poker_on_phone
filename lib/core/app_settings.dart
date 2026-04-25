import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { ru, en }

class AppSettings extends ChangeNotifier {
  AppSettings(this._language);

  static const _languageKey = 'app_language';
  AppLanguage _language;

  AppLanguage get language => _language;

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_languageKey) ?? 'ru';
    return AppSettings(raw == 'en' ? AppLanguage.en : AppLanguage.ru);
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) return;
    _language = language;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _languageKey,
      language == AppLanguage.en ? 'en' : 'ru',
    );
  }
}

class AppSettingsScope extends InheritedNotifier<AppSettings> {
  const AppSettingsScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    if (scope == null || scope.notifier == null) {
      throw StateError('AppSettingsScope not found in widget tree.');
    }
    return scope.notifier!;
  }

  static AppSettings? read(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<AppSettingsScope>();
    final widget = element?.widget;
    if (widget is AppSettingsScope) {
      return widget.notifier;
    }
    return null;
  }
}
