// lib/widgets/upgrade_celebration_dialog.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

class UpgradeCelebrationDialog extends StatefulWidget {
  final String tier;
  final VoidCallback? onDismiss;

  const UpgradeCelebrationDialog({
    super.key,
    required this.tier,
    this.onDismiss,
  });

  static Future<void> show(BuildContext context, {required String tier, VoidCallback? onDismiss}) {
    HapticFeedback.heavyImpact();
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'UpgradeCelebration',
      barrierColor: Colors.black.withValues(alpha: 0.85),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return UpgradeCelebrationDialog(tier: tier, onDismiss: onDismiss);
      },
    );
  }

  @override
  State<UpgradeCelebrationDialog> createState() => _UpgradeCelebrationDialogState();
}

class _UpgradeCelebrationDialogState extends State<UpgradeCelebrationDialog> {
  bool get isFarm => widget.tier.toLowerCase() == 'farm';

  @override
  void initState() {
    super.initState();
    HapticFeedback.vibrate();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = isFarm ? const Color(0xFFFFD700) : const Color(0xFF00E5A3);
    final secondaryColor = isFarm ? const Color(0xFFFFA000) : const Color(0xFF00BCD4);
    final title = isFarm ? 'FARM PACK UNLOCKED!' : 'PRO PLAN UNLOCKED!';
    final subtitle = isFarm
        ? 'Enterprise agricultural power at your fingertips'
        : 'Advanced diagnostic capabilities unlocked';

    final perks = isFarm
        ? [
            '🌾 Up to 100 Scans / Day & High Priority Queue',
            '🤖 100 In-depth AI Doctor chats every day',
            '📊 Bulk CSV & PDF Farm Diagnostics Export',
            '🏡 Full Garden & Multi-plot Management',
          ]
        : [
            '⚡ 50 Leaf Scans / Day with Rapid AI Diagnostics',
            '🌱 50 Expert AI Doctor Consultations / Day',
            '💊 Step-by-Step Organic & Chemical Treatment Plans',
            '📈 Plant Health Trend & Analytics Tracking',
          ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Ambient Glow Background
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.85,
                    colors: [
                      primaryColor.withValues(alpha: 0.22),
                      Colors.black.withValues(alpha: 0.9),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Main Celebratory Card
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Floating Tier Crest Icon
                    Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [primaryColor, secondaryColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.5),
                            blurRadius: 36,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          isFarm ? Icons.agriculture_rounded : Icons.auto_awesome_rounded,
                          color: Colors.black,
                          size: 54,
                        ),
                      ),
                    )
                        .animate()
                        .scale(
                          begin: const Offset(0.3, 0.3),
                          duration: 700.ms,
                          curve: Curves.elasticOut,
                        )
                        .rotate(begin: -0.15, end: 0, duration: 600.ms),

                    const SizedBox(height: 28),

                    // Tier Pill Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        isFarm ? '🌾 ENTERPRISE FARM EDITION' : '⚡ ADVANCED PRO EDITION',
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ).animate(delay: 200.ms).fadeIn().scale(),

                    const SizedBox(height: 14),

                    // Title
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.2, end: 0),

                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ).animate(delay: 400.ms).fadeIn(),

                    const SizedBox(height: 28),

                    // Perks List Container
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: perks.map((perk) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: primaryColor,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    perk,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.1, end: 0),

                    const SizedBox(height: 32),

                    // Glowing CTA Action Button
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        widget.onDismiss?.call();
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primaryColor, secondaryColor],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.45),
                              blurRadius: 24,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'Step Into Your New Superpowers',
                            style: TextStyle(
                              color: isFarm ? Colors.black : Colors.black,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    )
                        .animate(delay: 600.ms)
                        .fadeIn()
                        .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
