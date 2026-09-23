import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_strings.dart';

const _kLocaleKey = 'app_locale';

/// Riverpod provider for the locale notifier.
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('en')) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kLocaleKey) ?? 'en';
    AppStrings.setLang(code);
    state = Locale(code);
  }

  Future<void> setLocale(String langCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, langCode);
    AppStrings.setLang(langCode);
    state = Locale(langCode);
  }

  bool get isArabic => state.languageCode == 'ar';
}
