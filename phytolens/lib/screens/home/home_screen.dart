// lib/screens/home/home_screen.dart
// Soft Botanical Minimalism — white pill nav, no glassmorphism.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/colors.dart';
import '../../theme/design_tokens.dart';
import '../../providers/user_provider.dart';
import '../../widgets/user_avatar.dart';
import '../dashboard/dashboard_screen.dart';
import '../scanner/camera_screen.dart';
import '../history/scan_history_screen.dart';
import '../ai/chatbot_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/subscription_details_screen.dart';
import '../subscription/upgrade_screen.dart';

final navIndexProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const _screens = [
    DashboardScreen(),
    CameraScreen(),
    ScanHistoryScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = ref.watch(navIndexProvider);
    final user = ref.watch(currentUserProvider).value;

    return Scaffold(
      backgroundColor: AppColors.lightBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: AppColors.lightBg,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
            ),
            child: Row(
              children: [
                // ── Brand ─────────────────────────────────────────────────
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.eco_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'PhytoLens',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.lightTextPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
                const Spacer(),

                // ── Tier Pill ─────────────────────────────────────────────
                if (user != null)
                  GestureDetector(
                    onTap: () {
                      if (user.isPro) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SubscriptionDetailsScreen(user: user),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const UpgradeScreen(),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: user.isFarm
                            ? const Color(0xFFFEF9C3)
                            : (user.isPro
                                ? const Color(0xFFE0F2FE)
                                : const Color(0xFFD1FAE5)),
                        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                        border: Border.all(
                          color: user.isFarm
                              ? const Color(0xFFFDE68A)
                              : (user.isPro
                                  ? const Color(0xFFBAE6FD)
                                  : const Color(0xFF6EE7B7)),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        user.isFarm ? '🌾 FARM' : (user.isPro ? '⚡ PRO' : '🌱 FREE'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: user.isFarm
                              ? const Color(0xFF92400E)
                              : (user.isPro
                                  ? const Color(0xFF0369A1)
                                  : AppColors.primaryDark),
                        ),
                      ),
                    ),
                  ),

                // ── AI Action Button ───────────────────────────────────────
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatbotScreen()),
                    );
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: const Border.fromBorderSide(
                        BorderSide(color: Color(0xFFE2E8F0), width: 1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0x080F172A),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.primary,
                      size: 17,
                    ),
                  ),
                ),

                // ── Profile Avatar ─────────────────────────────────────────
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                  child: UserAvatar(
                    avatarUrl: user?.avatarUrl,
                    displayName: user?.displayName ?? 'User',
                    tier: user?.subscriptionTier,
                    size: 17,
                    showBorder: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
            ),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.015),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey<int>(idx),
          child: _screens[idx.clamp(0, _screens.length - 1)],
        ),
      ),

      extendBody: true,

      // ── White Pill Bottom Nav ────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Container(
            height: 66,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: const Border.fromBorderSide(
                BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x100F172A),
                  blurRadius: 16,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: const Color(0x060F172A),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                _LightNavItem(
                  icon: Icons.yard_outlined,
                  activeIcon: Icons.yard_rounded,
                  label: 'Plants',
                  isSelected: idx == 0,
                  onTap: () => ref.read(navIndexProvider.notifier).state = 0,
                ),
                _LightNavItem(
                  icon: Icons.filter_center_focus_rounded,
                  activeIcon: Icons.filter_center_focus_rounded,
                  label: 'Scan',
                  isSelected: idx == 1,
                  onTap: () => ref.read(navIndexProvider.notifier).state = 1,
                ),
                _LightNavItem(
                  icon: Icons.auto_stories_outlined,
                  activeIcon: Icons.auto_stories_rounded,
                  label: 'Care Log',
                  isSelected: idx == 2,
                  onTap: () => ref.read(navIndexProvider.notifier).state = 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Light Nav Item ─────────────────────────────────────────────────────────
class _LightNavItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LightNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_LightNavItem> createState() => _LightNavItemState();
}

class _LightNavItemState extends State<_LightNavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(
        parent: _pressCtrl,
        curve: Curves.easeInOutCubic,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          HapticFeedback.selectionClick();
          _pressCtrl.forward();
        },
        onTapUp: (_) {
          _pressCtrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _pressCtrl.reverse(),
        child: ScaleTransition(
          scale: _scale,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? const Color(0xFFD1FAE5)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedScale(
                    scale: widget.isSelected ? 1.1 : 1.0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutBack,
                    child: Icon(
                      widget.isSelected ? widget.activeIcon : widget.icon,
                      color: widget.isSelected
                          ? AppColors.primary
                          : AppColors.lightTextMuted,
                      size: 21,
                    ),
                  ),
                  const SizedBox(height: 3),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    style: GoogleFonts.inter(
                      color: widget.isSelected
                          ? AppColors.primary
                          : AppColors.lightTextMuted,
                      fontSize: 11,
                      fontWeight: widget.isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                    child: Text(widget.label),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
