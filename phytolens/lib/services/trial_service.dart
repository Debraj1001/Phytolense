// lib/services/trial_service.dart
//
// Manages the free-trial lifecycle, providing status checks,
// remaining-day calculations, and UI banner visibility flags.

import '../config/constants.dart';
import '../models/app_user.dart';

enum TrialStatus {
  /// Trial has not been activated yet. (0 limits)
  notStarted,

  /// Trial is active — user has remaining days.
  active,

  /// Trial is expiring soon — ≤ threshold days left.
  expiringSoon,

  /// Trial has ended — user is locked out again.
  expired,

  /// User has upgraded to a paid tier — trial is irrelevant.
  upgraded,
}

class TrialInfo {
  final TrialStatus status;
  final int remainingDays;
  final int totalDays;
  final double progressFraction; // 0.0 (just started) → 1.0 (expired)
  final bool showBanner;
  final bool showExpiredDialog;

  const TrialInfo({
    required this.status,
    required this.remainingDays,
    required this.totalDays,
    required this.progressFraction,
    required this.showBanner,
    required this.showExpiredDialog,
  });

  bool get isNotStarted => status == TrialStatus.notStarted;
  bool get isActive => status == TrialStatus.active || status == TrialStatus.expiringSoon;
  bool get isExpired => status == TrialStatus.expired;
  bool get isUpgraded => status == TrialStatus.upgraded;
  bool get isExpiringSoon => status == TrialStatus.expiringSoon;

  String get bannerMessage {
    switch (status) {
      case TrialStatus.notStarted:
        return 'Start your $totalDays-day Free Trial (15 scans/day)';
      case TrialStatus.active:
        return '$remainingDays day${remainingDays == 1 ? '' : 's'} left in Free Trial';
      case TrialStatus.expiringSoon:
        if (remainingDays <= 0) {
          return 'Last day of your Free Trial';
        }
        return 'Only $remainingDays day${remainingDays == 1 ? '' : 's'} left in Free Trial — upgrade to continue';
      case TrialStatus.expired:
        return 'Free Trial ended — Upgrade to Pro or Farm Pack';
      case TrialStatus.upgraded:
        return '';
    }
  }

  String get shortLabel {
    switch (status) {
      case TrialStatus.notStarted:
        return 'Trial Available';
      case TrialStatus.active:
        return '$remainingDays days left';
      case TrialStatus.expiringSoon:
        return remainingDays <= 0 ? 'Last day' : '$remainingDays days left';
      case TrialStatus.expired:
        return 'Trial ended';
      case TrialStatus.upgraded:
        return 'Active';
    }
  }

  String get badgeLabel => shortLabel;
}

class TrialService {
  /// Computes the trial status for a given user and trial day count.
  static TrialInfo getTrialInfo(AppUser? user, {int trialDays = 2}) {
    if (user == null) {
      return TrialInfo(
        status: TrialStatus.notStarted,
        remainingDays: 0,
        totalDays: trialDays,
        progressFraction: 0.0,
        showBanner: true,
        showExpiredDialog: false,
      );
    }

    // If user has a paid plan that's still valid, trial is irrelevant.
    final tier = user.subscriptionTier.toLowerCase();
    if (tier == AppConstants.tierPro || tier == AppConstants.tierFarm) {
      final isExpired = user.subscriptionExpiry != null &&
          user.subscriptionExpiry!.isBefore(DateTime.now());
      if (!isExpired) {
        return TrialInfo(
          status: TrialStatus.upgraded,
          remainingDays: 0,
          totalDays: 0,
          progressFraction: 0.0,
          showBanner: false,
          showExpiredDialog: false,
        );
      }
      // Paid plan expired — fall through to free-trial logic
    }

    if (user.trialActivatedAt == null) {
      return TrialInfo(
        status: TrialStatus.notStarted,
        remainingDays: trialDays,
        totalDays: trialDays,
        progressFraction: 0.0,
        showBanner: true,
        showExpiredDialog: false,
      );
    }

    final trialEnd = user.trialActivatedAt!.add(Duration(days: trialDays));
    final now = DateTime.now();
    final remaining = trialEnd.difference(now).inDays;
    final elapsed = now.difference(user.trialActivatedAt!).inDays;
    final progress = trialDays > 0 ? (elapsed / trialDays).clamp(0.0, 1.0) : 1.0;

    if (now.isAfter(trialEnd)) {
      return TrialInfo(
        status: TrialStatus.expired,
        remainingDays: 0,
        totalDays: trialDays,
        progressFraction: 1.0,
        showBanner: true,
        showExpiredDialog: true,
      );
    }

    if (remaining <= AppConstants.trialWarningDaysThreshold) {
      return TrialInfo(
        status: TrialStatus.expiringSoon,
        remainingDays: remaining,
        totalDays: trialDays,
        progressFraction: progress,
        showBanner: true,
        showExpiredDialog: false,
      );
    }

    return TrialInfo(
      status: TrialStatus.active,
      remainingDays: remaining,
      totalDays: trialDays,
      progressFraction: progress,
      showBanner: true,
      showExpiredDialog: false,
    );
  }
}
