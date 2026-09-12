// lib/widgets/subscription_gate.dart
// Paywall gating widget for feature access control

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/colors.dart';
import '../theme/design_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_provider.dart';
import '../services/trial_service.dart';
import '../providers/app_config_provider.dart';
import '../screens/subscription/upgrade_screen.dart';
import '../screens/subscription/trial_activation_screen.dart';

class SubscriptionGate extends StatelessWidget {
  final Widget child;
  final bool hasAccess;
  final String featureName;
  final String? description;
  final VoidCallback? onUpgrade;

  const SubscriptionGate({
    super.key,
    required this.child,
    required this.hasAccess,
    required this.featureName,
    this.description,
    this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    if (hasAccess) return child;
    return Consumer(
      builder: (context, ref, _) {
        final user = ref.watch(currentUserProvider).value;
        final config = ref.watch(appConfigProvider).value;
        
        bool isNotStarted = false;
        if (user != null && config != null) {
          final trialInfo = TrialService.getTrialInfo(user, trialDays: config.trialDays);
          isNotStarted = trialInfo.isNotStarted;
        }

        return PaywallOverlay(
          featureName: featureName,
          description: description,
          isNotStarted: isNotStarted,
          onUpgrade: onUpgrade ?? () {
            if (isNotStarted) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const TrialActivationScreen()));
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const UpgradeScreen()));
            }
          },
        );
      }
    );
  }
}

class PaywallOverlay extends StatelessWidget {
  final String featureName;
  final String? description;
  final VoidCallback? onUpgrade;
  final bool isNotStarted;

  const PaywallOverlay({
    super.key,
    required this.featureName,
    this.description,
    this.onUpgrade,
    this.isNotStarted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(AppTokens.radiusXL),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.cardDark,
            AppColors.primary.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.star_rounded,
              color: AppColors.primaryLight,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Unlock $featureName',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            description ??
                (isNotStarted 
                    ? 'Activate your 2-Day Trial to access this feature.'
                    : 'Upgrade to Pro or Farm Pack to access this feature.'),
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          // Features list
          ...[
            ('✅', 'Unlimited AI chats'),
            ('✅', 'Detailed analytics'),
            ('✅', 'Export reports'),
            ('✅', 'Priority support'),
          ].map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(item.$1, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 10),
                  Text(
                    item.$2,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onUpgrade,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              ),
            ),
            child: Text(
              isNotStarted ? 'Activate 2-Day Trial (₹1)' : 'Upgrade to Pro — ₹49/month',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }
}

/// Inline usage limit warning bar
class LimitWarningBar extends StatelessWidget {
  final int used;
  final int total;
  final String label;
  final VoidCallback? onUpgrade;

  const LimitWarningBar({
    super.key,
    required this.used,
    required this.total,
    required this.label,
    this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (used / total).clamp(0.0, 1.0);
    final remaining = total - used;
    final isWarning = remaining <= 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isWarning
            ? AppColors.error.withValues(alpha: 0.1)
            : AppColors.cardDark,
        border: Border.all(
          color: isWarning
              ? AppColors.error.withValues(alpha: 0.3)
              : AppColors.textMuted.withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(AppTokens.radiusSM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$label: $used/$total used',
                style: TextStyle(
                  fontSize: 12,
                  color: isWarning
                      ? AppColors.error
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (isWarning && onUpgrade != null)
                GestureDetector(
                  onTap: onUpgrade,
                  child: const Text(
                    'Upgrade ↗',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 4,
              backgroundColor: AppColors.textMuted.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(
                isWarning ? AppColors.error : AppColors.primaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
