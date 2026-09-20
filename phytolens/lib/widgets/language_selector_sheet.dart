import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../localization/app_translations.dart';
import '../providers/language_provider.dart';
import '../services/language_service.dart';
import '../theme/colors.dart';

class LanguageSelectorSheet {
  static Future<void> show(BuildContext context, WidgetRef ref, {bool isDismissible = true}) async {
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => PopScope(
        canPop: isDismissible,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF5F5F0),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isDismissible)
                    Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  Text(
                    AppTranslations.tr('select_language'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose your preferred language to get started',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ...AppLanguage.values.map((lang) {
                    final isCurrent = LanguageService().language == lang;
                    return GestureDetector(
                      onTap: () async {
                        await ref.read(languageProvider).setLanguage(lang);
                        if (!ctx.mounted) return;
                        if (isDismissible) {
                          Navigator.pop(ctx);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isCurrent
                                ? AppColors.primary.withValues(alpha: 0.45)
                                : AppColors.textMuted.withValues(alpha: 0.15),
                            width: isCurrent ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(lang.flag, style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    lang.nativeName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: isCurrent ? AppColors.primaryDark : AppColors.lightTextPrimary,
                                      fontFamily: 'PlusJakartaSans',
                                    ),
                                  ),
                                  Text(
                                    lang.englishName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isCurrent)
                              const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
