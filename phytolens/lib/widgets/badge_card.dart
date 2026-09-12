// lib/widgets/badge_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/badge_model.dart';
import '../theme/colors.dart';

class BadgeCard extends StatelessWidget {
  final BadgeModel badge;
  final bool compact;

  const BadgeCard({
    super.key,
    required this.badge,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: badge.isEarned
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: badge.isEarned
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.textMuted.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: compact ? 36 : 44,
            height: compact ? 36 : 44,
            decoration: BoxDecoration(
              color: badge.isEarned
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : AppColors.cardDarker,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                badge.icon,
                size: compact ? 18 : 22,
                color: badge.isEarned ? AppColors.primaryLight : AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            badge.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: badge.isEarned
                  ? AppColors.textPrimary
                  : AppColors.textMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            badge.isEarned ? '+${badge.xpReward} XP' : badge.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9.5,
              color: badge.isEarned
                  ? AppColors.primaryLight
                  : AppColors.textMuted,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (!badge.isEarned) ...[
            const SizedBox(height: 4),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline,
                size: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    ).animate(target: badge.isEarned ? 1 : 0).shimmer(
          color: AppColors.primaryLight.withValues(alpha: 0.3),
          duration: 800.ms,
        );
  }
}

/// Badge unlock toast notification
class BadgeUnlockToast extends StatelessWidget {
  final BadgeModel badge;

  const BadgeUnlockToast({super.key, required this.badge});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(badge.icon, size: 24, color: AppColors.primaryLight),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '🏆 Badge Unlocked!',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  badge.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '+${badge.xpReward} XP',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .slideY(begin: 1, end: 0, duration: 400.ms, curve: Curves.elasticOut)
        .fadeIn();
  }
}
