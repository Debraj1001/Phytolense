// lib/screens/profile/badges_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/app_user.dart';
import '../../models/badge_model.dart';
import '../../theme/colors.dart';
import '../../widgets/badge_card.dart';
import '../../widgets/health_score_ring.dart';

class BadgesScreen extends StatelessWidget {
  final AppUser user;

  const BadgesScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final allBadges = BadgeModel.allBadges
        .map((b) => b.copyWith(isEarned: user.badges.contains(b.id)))
        .toList();

    final earned = allBadges.where((b) => b.isEarned).toList();
    final locked = allBadges.where((b) => !b.isEarned).toList();
    final pct = (earned.length / allBadges.length * 100).round();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        title: const Text('Badges & Achievements'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Progress ring
                  HealthScoreRing(score: pct, size: 120, strokeWidth: 10),
                  const SizedBox(height: 12),
                  Text(
                    '${earned.length} of ${allBadges.length} badges earned',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total XP from badges: ${earned.fold<int>(0, (sum, b) => sum + b.xpReward)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),
          ),

          // Earned section
          if (earned.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  'Earned (${earned.length})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.68,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => BadgeCard(badge: earned[i])
                      .animate(delay: Duration(milliseconds: i * 60))
                      .fadeIn()
                      .scale(begin: const Offset(0.8, 0.8)),
                  childCount: earned.length,
                ),
              ),
            ),
          ],

          // Locked section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                'Locked (${locked.length})',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.68,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => BadgeCard(badge: locked[i])
                    .animate(delay: Duration(milliseconds: i * 40))
                    .fadeIn(),
                childCount: locked.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
