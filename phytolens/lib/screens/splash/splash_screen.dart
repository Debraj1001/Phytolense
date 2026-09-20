// lib/screens/splash/splash_screen.dart
//
// Soft Botanical Minimalism — light theme splash.
// Off-white canvas, sage emerald icon in tinted halo,
// slim progress bar, staggered entrance choreography.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/constants.dart';
import '../../services/supabase_service.dart';
import '../../services/language_service.dart';
import '../../widgets/language_selector_sheet.dart';
import '../../theme/colors.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  String _detectedTier = 'free';

  late final AnimationController _haloCtrl;
  late final AnimationController _iconCtrl;
  late final AnimationController _titleCtrl;
  late final AnimationController _badgeCtrl;
  late final AnimationController _taglineCtrl;
  late final AnimationController _barCtrl;
  late final AnimationController _exitCtrl;
  late final AnimationController _shimmerCtrl;

  late final Animation<double> _haloScale;
  late final Animation<double> _haloOpacity;
  late final Animation<double> _iconScale;
  late final Animation<double> _iconOpacity;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _badgeOpacity;
  late final Animation<double> _taglineOpacity;
  late final Animation<double> _barProgress;
  late final Animation<double> _exitOpacity;
  late final Animation<double> _shimmerPos;

  bool _exiting = false;

  @override
  void initState() {
    super.initState();

    _haloCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _iconCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _titleCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
    _badgeCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _taglineCtrl= AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _barCtrl    = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _exitCtrl   = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _shimmerCtrl= AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

    _haloScale   = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _haloCtrl, curve: Curves.easeOutCubic));
    _haloOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _haloCtrl, curve: Curves.easeOut));

    _iconScale   = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _iconCtrl, curve: Curves.elasticOut));
    _iconOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _iconCtrl, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)));

    _titleSlide  = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _titleCtrl, curve: Curves.easeOutCubic));
    _titleOpacity= Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _titleCtrl, curve: Curves.easeOut));

    _badgeOpacity   = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _badgeCtrl, curve: Curves.easeOut));
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _taglineCtrl, curve: Curves.easeOut));

    _barProgress = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _barCtrl, curve: Curves.easeInOut));
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn));
    _shimmerPos  = Tween<double>(begin: -1.0, end: 2.0).animate(CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut));

    _runEntrance();
    _detectTierAndNavigate();
  }

  Future<void> _runEntrance() async {
    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    _haloCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    _iconCtrl.forward();
    _shimmerCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _titleCtrl.forward();
    _barCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    _badgeCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    _taglineCtrl.forward();
  }

  Future<void> _detectTierAndNavigate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_user_tier');
      if (cached != null && cached.isNotEmpty && mounted) {
        setState(() => _detectedTier = cached.toLowerCase());
      }
      final sbUser = Supabase.instance.client.auth.currentUser;
      if (sbUser != null) {
        final appUser = await SupabaseService().getUser(sbUser.id);
        if (appUser != null && mounted) {
          final tier = appUser.subscriptionTier.toLowerCase();
          setState(() => _detectedTier = tier);
          await prefs.setString('cached_user_tier', tier);
        }
      }
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 2600));
    if (!mounted) return;

    if (!LanguageService().hasSelectedLanguage) {
      await LanguageSelectorSheet.show(context, ref, isDismissible: false);
      if (!mounted) return;
    }

    setState(() => _exiting = true);
    await _exitCtrl.forward();
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool(AppConstants.onboardingKey) ?? false;
    User? user;
    try {
      user = Supabase.instance.client.auth.currentUser;
    } catch (e) {
      debugPrint('Error getting Supabase user: $e');
    }
    if (!mounted) return;

    if (!onboardingDone) {
      Navigator.pushReplacementNamed(context, AppConstants.routeOnboarding);
    } else if (user == null) {
      Navigator.pushReplacementNamed(context, AppConstants.routeLogin);
    } else {
      Navigator.pushReplacementNamed(context, AppConstants.routeHome);
    }
  }

  @override
  void dispose() {
    _haloCtrl.dispose();
    _iconCtrl.dispose();
    _titleCtrl.dispose();
    _badgeCtrl.dispose();
    _taglineCtrl.dispose();
    _barCtrl.dispose();
    _exitCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFarm = _detectedTier == 'farm';
    final isPro  = _detectedTier == 'pro';

    final Color tierColor = isFarm
        ? const Color(0xFFF59E0B)
        : (isPro ? const Color(0xFF0EA5E9) : AppColors.primary);

    final IconData tierIcon = isFarm
        ? Icons.agriculture_rounded
        : (isPro ? Icons.auto_awesome_rounded : Icons.eco_rounded);

    final String editionLabel = isFarm
        ? '🌾 FARM EDITION'
        : (isPro ? '⚡ PRO SUITE' : '🌱 FREE EDITION');

    final String editionTagline = isFarm
        ? 'Precision Agricultural & Crop Care'
        : (isPro
            ? 'Advanced AI Botanical Intelligence'
            : 'Your Plant\'s Best Health Companion');

    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _haloCtrl, _iconCtrl, _titleCtrl, _badgeCtrl,
          _taglineCtrl, _barCtrl, _exitCtrl, _shimmerCtrl,
        ]),
        builder: (context, _) {
          return FadeTransition(
            opacity: _exiting ? _exitOpacity : const AlwaysStoppedAnimation(1.0),
            child: Stack(
              children: [
                // ── Soft ambient halo ──────────────────────────────────────
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.22,
                  left: MediaQuery.of(context).size.width * 0.5 - 110,
                  child: Opacity(
                    opacity: _haloOpacity.value * 0.6,
                    child: Transform.scale(
                      scale: _haloScale.value,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: tierColor.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Central content ────────────────────────────────────────
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon in tinted circle
                      Opacity(
                        opacity: _iconOpacity.value,
                        child: Transform.scale(
                          scale: _iconScale.value,
                          child: _buildIconCrest(tierColor, tierIcon),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // App Name
                      SlideTransition(
                        position: _titleSlide,
                        child: Opacity(
                          opacity: _titleOpacity.value,
                          child: Text(
                            'PhytoLens',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: AppColors.lightTextPrimary,
                              letterSpacing: -0.8,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Edition badge
                      Opacity(
                        opacity: _badgeOpacity.value,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: tierColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: tierColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            editionLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: tierColor,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Tagline
                      Opacity(
                        opacity: _taglineOpacity.value,
                        child: Text(
                          editionTagline,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.lightTextSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),

                      const SizedBox(height: 60),

                      // Slim progress bar
                      Opacity(
                        opacity: _taglineOpacity.value,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 60),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _barProgress.value,
                              minHeight: 4,
                              backgroundColor: const Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                tierColor.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildIconCrest(Color tierColor, IconData tierIcon) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        children: [
          // Tinted circle base
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: tierColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: tierColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Icon(tierIcon, color: tierColor, size: 44),
            ),
          ),

          // Shimmer sweep
          ClipOval(
            child: SizedBox(
              width: 96,
              height: 96,
              child: ShaderMask(
                shaderCallback: (rect) {
                  return LinearGradient(
                    begin: Alignment(_shimmerPos.value - 1, 0),
                    end: Alignment(_shimmerPos.value, 0),
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ).createShader(rect);
                },
                blendMode: BlendMode.srcATop,
                child: Container(
                  width: 96,
                  height: 96,
                  color: Colors.white.withValues(alpha: 0.01),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
