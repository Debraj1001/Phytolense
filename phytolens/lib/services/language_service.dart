// lib/services/language_service.dart
// Singleton LanguageService — persists & broadcasts language changes.
// Uses SharedPreferences for persistence and ChangeNotifier for reactive UI.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../localization/app_translations.dart';

class LanguageService extends ChangeNotifier {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  static const String _prefKey = 'app_language_code';

  AppLanguage _language = AppLanguage.english;
  bool _hasSelectedLanguage = false;

  AppLanguage get language => _language;
  String get languageCode => _language.code;
  bool get hasSelectedLanguage => _hasSelectedLanguage;

  /// Initialize — load persisted language, then notify listeners.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_prefKey);
      _hasSelectedLanguage = prefs.containsKey(_prefKey);
      if (savedCode != null) {
        _language = AppLanguage.fromCode(savedCode);
        AppTranslations.setLanguage(_language);
      }
    } catch (e) {
      debugPrint('LanguageService init error: $e');
    }
    notifyListeners();
  }

  /// Set a new language and persist it.
  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) return;
    _language = language;
    AppTranslations.setLanguage(language);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, language.code);
      _hasSelectedLanguage = true;
    } catch (e) {
      debugPrint('LanguageService persist error: $e');
    }
    notifyListeners();
  }

  /// Shortcut translation accessor — wraps AppTranslations.tr()
  String tr(String key, [Map<String, String>? params]) =>
      AppTranslations.tr(key, params);

  /// AI language directive for current language.
  String get aiLanguageDirective => AppTranslations.aiLanguageDirective;

  /// TTS language code for current language.
  String get ttsLanguageCode => AppTranslations.ttsLanguageCode;
}
