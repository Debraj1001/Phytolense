// lib/providers/language_provider.dart
// Riverpod ChangeNotifierProvider for LanguageService.
// Provides context.tr('key') extension for clean widget-level usage.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/language_service.dart';
import '../localization/app_translations.dart';

// Global ChangeNotifierProvider — rebuilds subtree on language change
final languageProvider = ChangeNotifierProvider<LanguageService>((ref) {
  return LanguageService();
});

/// BuildContext extension for clean localization syntax.
/// Usage: context.tr('key') or context.tr('key', {'count': '5'})
extension TranslationExtension on BuildContext {
  String tr(String key, [Map<String, String>? params]) =>
      AppTranslations.tr(key, params);

  AppLanguage get currentLanguage => LanguageService().language;
}

/// WidgetRef extension for accessing translations inside ConsumerWidgets.
extension RefTranslationExtension on WidgetRef {
  String tr(String key, [Map<String, String>? params]) {
    // Watch language provider to rebuild widget when language changes
    watch(languageProvider);
    return AppTranslations.tr(key, params);
  }
}
