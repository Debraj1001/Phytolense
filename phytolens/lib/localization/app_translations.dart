// lib/localization/app_translations.dart
// Central dictionary registry, AppLanguage enum, and string accessor.
// Usage: AppTranslations.tr('key') or context.tr('key')

import 'translations_en.dart';
import 'translations_hi.dart';
import 'translations_bn.dart';

enum AppLanguage {
  english('en', 'English', 'English', '🇬🇧'),
  hindi('hi', 'हिन्दी', 'Hindi', '🇮🇳'),
  bengali('bn', 'বাংলা', 'Bengali', '🇮🇳');

  final String code;
  final String nativeName;
  final String englishName;
  final String flag;

  const AppLanguage(this.code, this.nativeName, this.englishName, this.flag);

  String get displayName => '$flag $nativeName';

  static AppLanguage fromCode(String code) {
    return AppLanguage.values.firstWhere(
      (l) => l.code == code,
      orElse: () => AppLanguage.english,
    );
  }
}

class AppTranslations {
  static AppLanguage _current = AppLanguage.english;

  static AppLanguage get current => _current;

  static void setLanguage(AppLanguage language) {
    _current = language;
  }

  static final Map<String, Map<String, String>> _dictionaries = {
    'en': translationsEn,
    'hi': translationsHi,
    'bn': translationsBn,
  };

  /// Translate a key in the current language.
  /// Falls back to English if key is missing in target language.
  /// Supports parameter interpolation: tr('key', {'count': '5'})
  static String tr(String key, [Map<String, String>? params]) {
    final dict = _dictionaries[_current.code] ?? translationsEn;
    String value = dict[key] ?? translationsEn[key] ?? key;

    if (params != null) {
      params.forEach((k, v) {
        value = value.replaceAll('{$k}', v);
      });
    }

    return value;
  }

  /// Get the AI language directive for the current language.
  static String get aiLanguageDirective {
    switch (_current) {
      case AppLanguage.hindi:
        return translationsEn['ai_language_directive_hi']!;
      case AppLanguage.bengali:
        return translationsEn['ai_language_directive_bn']!;
      case AppLanguage.english:
        return translationsEn['ai_language_directive_en']!;
    }
  }

  /// Get the TTS language code for current language.
  static String get ttsLanguageCode {
    switch (_current) {
      case AppLanguage.hindi:
        return 'hi-IN';
      case AppLanguage.bengali:
        return 'bn-IN';
      case AppLanguage.english:
        return 'en-IN';
    }
  }

  /// Get the Flutter Locale for current language.
  static String get localeCode => _current.code;
}
