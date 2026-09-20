// lib/screens/onboarding/onboarding_screen.dart
// Soft Botanical Minimalism — light theme onboarding.
// 5-step swipeable flow: tinted hero card, emerald pill dots, 12px-radius CTA.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/language_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/constants.dart';
import '../../theme/colors.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<_OnboardPage> get _pages => [
    _OnboardPage(
      emoji: '📸',
      title: ref.tr('onboarding_title_1'),
      subtitle:
          ref.tr('onboarding_desc_1'),
      tint: const Color(0xFFD1FAE5),
      accent: AppColors.primary,
    ),
    _OnboardPage(
      emoji: '🔍',
      title: ref.tr('onboarding_title_2'),
      subtitle:
          ref.tr('onboarding_desc_2'),
      tint: const Color(0xFFD1FAE5),
      accent: AppColors.primary,
    ),
    _OnboardPage(
      emoji: '💊',
      title: ref.tr('onboarding_title_3'),
      subtitle:
          ref.tr('onboarding_desc_3'),
      tint: const Color(0xFFDEF7EC),
      accent: const Color(0xFF059669),
    ),
    _OnboardPage(
      emoji: '📊',
      title: ref.tr('onboarding_title_4'),
      subtitle:
          ref.tr('onboarding_desc_4'),
      tint: const Color(0xFFECFDF5),
      accent: const Color(0xFF10B981),
    ),
    _OnboardPage(
      emoji: '🏆',
      title: ref.tr('onboarding_title_5'),
      subtitle:
          ref.tr('onboarding_desc_5'),
      tint: const Color(0xFFFEF9C3),
      accent: const Color(0xFFD97706),
    ),
  ];

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _skip() => _finish();

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.onboardingKey, true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppConstants.routeLogin);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: _skip,
                  child: Text(
                    ref.tr('skip'),
                    style: GoogleFonts.inter(
                      color: AppColors.lightTextMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

            // ── Page content ──────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (context, i) => _PageContent(page: _pages[i]),
              ),
            ),

            // ── Dots + CTA ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                children: [
                  // Pill dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: _currentPage == i ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? AppColors.primary
                              : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 26),

                  // CTA Button — full width, 48px, 12px radius
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _currentPage == _pages.length - 1
                            ? 'Get Started 🌱'
                            : 'Continue',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Page Content ──────────────────────────────────────────────────────────
class _PageContent extends StatelessWidget {
  final _OnboardPage page;
  const _PageContent({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Hero illustration card
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: page.tint,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: page.accent.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                page.emoji,
                style: const TextStyle(fontSize: 72),
              ),
            ),
          )
              .animate(key: ValueKey(page.emoji))
              .scale(
                begin: const Offset(0.7, 0.7),
                duration: 480.ms,
                curve: Curves.elasticOut,
              )
              .fadeIn(duration: 260.ms),

          const SizedBox(height: 40),

          Text(
            page.title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.lightTextPrimary,
              height: 1.2,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          )
              .animate(key: ValueKey('t_${page.emoji}'))
              .fadeIn(delay: 120.ms, duration: 280.ms)
              .slideY(begin: 0.18, end: 0, curve: Curves.easeOutCubic),

          const SizedBox(height: 14),

          Text(
            page.subtitle,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: AppColors.lightTextSecondary,
              height: 1.6,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          )
              .animate(key: ValueKey('s_${page.emoji}'))
              .fadeIn(delay: 220.ms, duration: 280.ms),
        ],
      ),
    );
  }
}

// ── Data Model ────────────────────────────────────────────────────────────
class _OnboardPage {
  final String emoji;
  final String title;
  final String subtitle;
  final Color tint;
  final Color accent;

  const _OnboardPage({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.accent,
  });
}
