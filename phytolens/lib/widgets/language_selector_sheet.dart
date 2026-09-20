import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      builder: (ctx) => _LanguageSelectorContent(isDismissible: isDismissible),
    );
  }
}

class _LanguageSelectorContent extends ConsumerStatefulWidget {
  final bool isDismissible;
  const _LanguageSelectorContent({required this.isDismissible});

  @override
  ConsumerState<_LanguageSelectorContent> createState() => _LanguageSelectorContentState();
}

class _LanguageSelectorContentState extends ConsumerState<_LanguageSelectorContent>
    with SingleTickerProviderStateMixin {
  late AppLanguage _selectedLang;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _selectedLang = LanguageService().language;
  }

  String _getTitle() {
    switch (_selectedLang) {
      case AppLanguage.hindi:
        return 'अपनी भाषा चुनें';
      case AppLanguage.bengali:
        return 'পছন্দের ভাষা নির্বাচন করুন';
      case AppLanguage.english:
        return 'Choose Your Language';
    }
  }

  String _getSubtitle() {
    switch (_selectedLang) {
      case AppLanguage.hindi:
        return 'शुरू करने के लिए अपनी पसंदीदा भाषा चुनें';
      case AppLanguage.bengali:
        return 'শুরু করতে আপনার পছন্দের ভাষা নির্বাচন করুন';
      case AppLanguage.english:
        return 'Select your preferred language to get started';
    }
  }

  String _getContinueBtnText() {
    if (_isApplying) {
      switch (_selectedLang) {
        case AppLanguage.hindi:
          return 'भाषा लागू की जा रही है...';
        case AppLanguage.bengali:
          return 'ভাষা প্রয়োগ করা হচ্ছে...';
        case AppLanguage.english:
          return 'Applying Language...';
      }
    }

    switch (_selectedLang) {
      case AppLanguage.hindi:
        return 'जारी रखें →';
      case AppLanguage.bengali:
        return 'এগিয়ে যান →';
      case AppLanguage.english:
        return 'Continue →';
    }
  }

  Future<void> _handleApplyAndContinue() async {
    if (_isApplying) return;

    setState(() => _isApplying = true);
    HapticFeedback.mediumImpact();

    // Visual applying delay so user experiences smooth state transformation
    await Future.delayed(const Duration(milliseconds: 380));
    if (!mounted) return;

    // Apply language preference to provider and SharedPreferences
    await ref.read(languageProvider).setLanguage(_selectedLang);

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.isDismissible && !_isApplying,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF9FAFB),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag handle or header indicator
                Container(
                  width: 44,
                  height: 4.5,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),

                // Animated Header Title
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    _getTitle(),
                    key: ValueKey('${_selectedLang.code}_title'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.lightTextPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // Animated Subtitle
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    _getSubtitle(),
                    key: ValueKey('${_selectedLang.code}_sub'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      color: AppColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Language Option Cards
                ...AppLanguage.values.map((lang) {
                  final isSelected = _selectedLang == lang;
                  return GestureDetector(
                    onTap: _isApplying
                        ? null
                        : () {
                            if (_selectedLang != lang) {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedLang = lang);
                            }
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textMuted.withValues(alpha: 0.18),
                          width: isSelected ? 2.0 : 1.2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.18),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : Colors.grey.shade100,
                            ),
                            child: Text(
                              lang.flag,
                              style: const TextStyle(fontSize: 26),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang.nativeName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? AppColors.primaryDark
                                        : AppColors.lightTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  lang.englishName,
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    color: isSelected
                                        ? AppColors.primaryDark.withValues(alpha: 0.7)
                                        : AppColors.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedScale(
                            scale: isSelected ? 1.0 : 0.85,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.textMuted.withValues(alpha: 0.4),
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 12),

                // ─── Prominent Dynamic Continue Button with Applying Animation ───
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isApplying ? null : _handleApplyAndContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.7),
                      disabledForegroundColor: Colors.white,
                      elevation: 3,
                      shadowColor: AppColors.primary.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _isApplying
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _getContinueBtnText(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _getContinueBtnText(),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
