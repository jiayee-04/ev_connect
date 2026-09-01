import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController extends ValueNotifier<Locale> {
  LocaleController._() : super(const Locale('en'));
  static final LocaleController instance = LocaleController._();

  static const _key = 'ev_connect_locale';
  static const supported = [Locale('en'), Locale('ms'), Locale('zh')];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key) ?? 'en';
    value = Locale(code);
  }

  Future<void> setLocale(String code) async {
    value = Locale(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
  }
}
