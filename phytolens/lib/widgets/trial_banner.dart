// lib/widgets/trial_banner.dart
//
// Animated, reusable trial status banner that adapts to the current
// trial phase (active / expiring soon / expired).

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/trial_service.dart';
import '../theme/colors.dart';
import '../widgets/bouncing_button.dart';

class TrialBanner extends StatelessWidget {
  final TrialInfo trialInfo;
  final VoidCallback onUpgradeTap;

  const TrialBanner({
    super.key,
    required this.trialInfo,
    required this.onUpgradeTap,
  });

  @override
  Widget build(BuildContext context) {
    // Don't show anything if upgraded or info says no banner
    if (!trialInfo.showBanner || trialInfo.isUpgraded) {
      return const SizedBox.shrink();
    }

    final isExpired = trialInfo.isExpired;
    final isExpiringSoon = trialInfo.isExpiringSoon;

    // Color scheme adapts to urgency
    final Color bgColor = isExpired
        ? const Color(0x1FEF4444)
        : (isExpiringSoon ? const Color(0x1FF59E0B) : const Color(0x1F10B981));
    final Color borderColor = isExpired
        ? AppColors.error.withValues(alpha: 0.4)
        : (isExpiringSoon
            ? AppColors.warning.withValues(alpha: 0.4)
            : AppColors.primary.withValues(alpha: 0.3));
    final Color accentColor = isExpired
        ? AppColors.error
        : (isExpiringSoon ? AppColors.warning : AppColors.primary);
    final IconData leadingIcon = isExpired
        ? Icons.lock_outline_rounded
        : (isExpiringSoon ? Icons.warning_amber_rounded : Icons.hourglass_bottom_rounded);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Leading icon
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(leadingIcon, color: accentColor, size: 16),
              ),
              const SizedBox(width: 10),

              // Message
              Expanded(
                child: Text(
                  trialInfo.bannerMessage,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                    height: 1.3,
                  ),
                ),
              ),

              // Upgrade CTA
              if (isExpired || isExpiringSoon)
                BouncingButton(
                  onTap: onUpgradeTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accentColor, accentColor.withValues(alpha: 0.8)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Upgrade',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Progress bar (only for active / expiring soon)
          if (!isExpired) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: trialInfo.progressFraction,
                backgroundColor: accentColor.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Day ${trialInfo.totalDays - trialInfo.remainingDays} of ${trialInfo.totalDays}',
                  style: TextStyle(
                    fontSize: 10,
                    color: accentColor.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  trialInfo.shortLabel,
                  style: TextStyle(
                    fontSize: 10,
                    color: accentColor.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: -0.1, end: 0, duration: 400.ms, curve: Curves.easeOut);
  }
}
