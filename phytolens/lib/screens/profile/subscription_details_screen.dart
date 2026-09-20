// lib/screens/profile/subscription_details_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../models/app_user.dart';
import '../../providers/app_config_provider.dart';
import '../../theme/colors.dart';
import '../../theme/design_tokens.dart';
import '../../services/supabase_service.dart';
import '../subscription/upgrade_screen.dart';
import '../subscription/trial_activation_screen.dart';

class SubscriptionDetailsScreen extends ConsumerStatefulWidget {
  final AppUser user;

  const SubscriptionDetailsScreen({super.key, required this.user});

  @override
  ConsumerState<SubscriptionDetailsScreen> createState() => _SubscriptionDetailsScreenState();
}

class _SubscriptionDetailsScreenState extends ConsumerState<SubscriptionDetailsScreen> {
  final _supabase = SupabaseService();
  AppUser? _user;
  Map<String, dynamic> _config = {};
  int _todayScans = 0;
  int _todayAi = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final latestUser = await _supabase.getUser(_user!.uid);
      final config = await _supabase.fetchAppConfig();
      final scans = await _supabase.getTodayScanCount(_user!.uid);
      final ai = await _supabase.getTodayAiUsage(_user!.uid);

      if (mounted) {
        setState(() {
          if (latestUser != null) _user = latestUser;
          _config = {
            'free_daily_scan_limit': config.freeScanLimit,
            'pro_daily_scan_limit': config.proScanLimit,
            'farm_daily_scan_limit': config.farmScanLimit,
            'free_daily_ai_limit': config.freeAiLimit,
            'pro_daily_ai_limit': config.proAiLimit,
            'farm_daily_ai_limit': config.farmAiLimit,
            'free_tier_days': config.freeTierDays,
          };
          _todayScans = scans;
          _todayAi = ai;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Live config stream listener
    final liveConfig = ref.watch(appConfigProvider).value;
    final freeTierDays = liveConfig?.trialDays ?? (_config['trial_days'] as num?)?.toInt() ?? 2;

    final tier = _user?.subscriptionTier ?? 'free';
    final isPro = tier == 'pro';
    final isFarm = tier == 'farm';
    final isPaid = isPro || isFarm;
    final isTrialNotStarted = !isPaid && (_user?.trialActivatedAt == null);
    final isTrialExpired = !isPaid && (_user?.trialActivatedAt != null) && _user!.isFreeTrialExpired(freeTierDays);
    final isTrialActive = !isPaid && (_user?.trialActivatedAt != null) && !isTrialExpired;

    final now = DateTime.now();
    final expiry = _user?.subscriptionExpiry;
    final isPaidExpired = isPaid && expiry != null && expiry.isBefore(now);
    final daysRemaining = expiry != null ? expiry.difference(now).inDays : 0;

    // Accurate Trial calculations based on trialActivatedAt
    final trialExpiry = (_user?.trialActivatedAt ?? now).add(Duration(days: freeTierDays));
    final trialDiff = trialExpiry.difference(now);
    final String trialRemainingText;
    if (trialDiff.isNegative) {
      trialRemainingText = 'Expired';
    } else if (trialDiff.inDays > 0) {
      trialRemainingText = '${trialDiff.inDays} day(s) left';
    } else if (trialDiff.inHours > 0) {
      trialRemainingText = '${trialDiff.inHours} hour(s) left';
    } else {
      trialRemainingText = 'Expires today';
    }

    // Dynamic Limits from live config or database config
    final proDailyLimit = liveConfig?.proScanLimit ?? (_config['pro_daily_scan_limit'] as num?)?.toInt() ?? 50;
    final proDailyAiLimit = liveConfig?.proAiLimit ?? (_config['pro_daily_ai_limit'] as num?)?.toInt() ?? 50;

    final scanLimit = isFarm
        ? (liveConfig?.farmScanLimit ?? (_config['farm_daily_scan_limit'] as num?)?.toInt() ?? 100)
        : (isPro
            ? proDailyLimit
            : (liveConfig?.freeScanLimit ?? (_config['free_daily_scan_limit'] as num?)?.toInt() ?? 15));

    final aiLimit = isFarm
        ? (liveConfig?.farmAiLimit ?? (_config['farm_daily_ai_limit'] as num?)?.toInt() ?? 100)
        : (isPro
            ? proDailyAiLimit
            : (liveConfig?.freeAiLimit ?? (_config['free_daily_ai_limit'] as num?)?.toInt() ?? 15));

    // Badge and Colors
    final String planTitle;
    final String planSubtitle;
    final String badgeText;
    final Color tierColor;

    if (isFarm) {
      planTitle = 'Farm Enterprise Pack';
      planSubtitle = isPaidExpired ? 'Subscription Expired' : 'Full Agricultural Suite';
      badgeText = isPaidExpired ? 'EXPIRED' : 'FARM ACTIVE';
      tierColor = const Color(0xFFD97706);
    } else if (isPro) {
      planTitle = 'Pro Plan';
      planSubtitle = isPaidExpired ? 'Subscription Expired' : 'Advanced Diagnostic Tier';
      badgeText = isPaidExpired ? 'EXPIRED' : 'PRO ACTIVE';
      tierColor = AppColors.secondary;
    } else if (isTrialActive) {
      planTitle = 'Free Introductory Trial';
      planSubtitle = '$freeTierDays-Day Trial Period ($trialRemainingText)';
      badgeText = 'TRIAL ACTIVE';
      tierColor = AppColors.primary;
    } else if (isTrialNotStarted) {
      planTitle = 'Free Basic Tier';
      planSubtitle = '$freeTierDays-Day Trial Available • ₹1 Activation';
      badgeText = 'TRIAL AVAILABLE';
      tierColor = AppColors.primary;
    } else {
      planTitle = 'Basic Free Tier';
      planSubtitle = 'Trial Expired • Basic Limits';
      badgeText = 'TRIAL EXPIRED';
      tierColor = AppColors.warning;
    }

    return Scaffold(
      backgroundColor: AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: AppColors.lightSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Subscription Plan',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primaryLight,
              backgroundColor: Colors.white,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Plan Hero Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isFarm
                              ? [const Color(0xFFFFFBEB), Colors.white]
                              : (isPro
                                  ? [const Color(0xFFF0F9FF), Colors.white]
                                  : (isTrialExpired
                                      ? [const Color(0xFFFEF2F2), Colors.white]
                                      : [const Color(0xFFECFDF5), Colors.white])),
                        ),
                        borderRadius: BorderRadius.circular(AppTokens.radiusLG),
                        border: Border.all(color: tierColor.withValues(alpha: 0.35), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: tierColor.withValues(alpha: 0.1),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: tierColor.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isFarm
                                      ? Icons.agriculture_rounded
                                      : (isPro ? Icons.bolt_rounded : Icons.eco_rounded),
                                  color: tierColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      planTitle,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      planSubtitle,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: tierColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (isPaid && !isPaidExpired || isTrialActive || isTrialNotStarted
                                          ? AppColors.primary
                                          : AppColors.warning)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: (isPaid && !isPaidExpired || isTrialActive || isTrialNotStarted
                                            ? AppColors.primary
                                            : AppColors.warning)
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  badgeText,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: isPaid && !isPaidExpired || isTrialActive || isTrialNotStarted
                                        ? AppColors.primaryDark
                                        : AppColors.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),
                          Divider(color: AppColors.lightBorder, height: 1),
                          const SizedBox(height: 14),

                          // Real-time Expiry & Duration Details
                          if (isPaid && expiry != null) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Plan Expiration Date',
                                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  DateFormat('MMMM dd, yyyy').format(expiry),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Time Remaining',
                                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: tierColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isPaidExpired
                                        ? 'Expired'
                                        : (daysRemaining <= 0 ? 'Expires today' : '$daysRemaining days left'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isPaidExpired ? AppColors.error : tierColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ] else if (isTrialActive) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Free Trial Expiry Date',
                                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  DateFormat('MMMM dd, yyyy').format(trialExpiry),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Trial Time Remaining',
                                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    trialRemainingText,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Trial includes $scanLimit daily scans, $aiLimit AI conversations, and basic disease identification. Upgrade to Pro or Farm for detailed treatment protocols, analytics, and full garden tracking.',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                            ),
                          ] else if (isTrialNotStarted) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Trial Status',
                                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Not Started',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Activate your $freeTierDays-day trial for just ₹1 to unlock Tier 1 Pro benefits ($proDailyLimit daily scans, $proDailyAiLimit AI chats, and full crop health features).',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const TrialActivationScreen()),
                                  ).then((_) => _loadData());
                                },
                                icon: const Icon(Icons.bolt_rounded, size: 18, color: Colors.white),
                                label: const Text(
                                  'Activate ₹1 Pro Trial',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ] else ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Trial Status',
                                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Expired',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Your $freeTierDays-day introductory trial has concluded. Upgrade to Pro ($proDailyLimit daily scans) or Farm Pack to continue diagnosing plants and chatting with botanist AI.',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                            ),
                          ],
                        ],
                      ),
                    ).animate().fadeIn().slideY(begin: 0.05, end: 0),

                    const SizedBox(height: 16),

                    // Security & Non-Tamper Notice
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTokens.radiusMD),
                        border: Border.all(color: AppColors.lightBorder),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Subscription validity and usage counts are strictly synchronized from the secure cloud database and cannot be altered locally.',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),


                    const SizedBox(height: 24),

                    // Real-Time Daily Quota Progress
                    const Text(
                      'Today\'s Usage & Quotas',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildQuotaTile(
                      title: 'Daily Disease Scans',
                      used: _todayScans,
                      limit: scanLimit,
                      icon: Icons.camera_alt_rounded,
                      color: AppColors.primary,
                      isTrialNotStarted: isTrialNotStarted,
                      isTrialExpired: isTrialExpired,
                    ),
                    const SizedBox(height: 10),

                    _buildQuotaTile(
                      title: 'Daily AI Agronomist Chats',
                      used: _todayAi,
                      limit: aiLimit,
                      icon: Icons.chat_bubble_rounded,
                      color: AppColors.secondary,
                      isTrialNotStarted: isTrialNotStarted,
                      isTrialExpired: isTrialExpired,
                    ),

                    const SizedBox(height: 24),

                    // Plan Benefits Unlocked - Strictly follows comparison matrix
                    const Text(
                      'Unlocked Plan Privileges',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 1. Daily Scans
                    _buildFeatureCheck(
                      title: isFarm && scanLimit < 0
                          ? 'Unlimited Daily Plant Scans'
                          : (isTrialNotStarted
                              ? '$scanLimit Scans / Day (Available with 2-Day Trial)'
                              : '$scanLimit Scans per Day'),
                      isUnlocked: !isTrialNotStarted,
                    ),

                    // 2. Daily AI Chats
                    _buildFeatureCheck(
                      title: isFarm && aiLimit < 0
                          ? 'Unlimited AI Agronomist Chats'
                          : (isTrialNotStarted
                              ? '$aiLimit AI Chats / Day (Available with 2-Day Trial)'
                              : '$aiLimit AI Chats per Day'),
                      isUnlocked: !isTrialNotStarted,
                    ),

                    // 3. Basic Disease Reports (Free has Basic, Pro has Detailed, Farm has Full)
                    _buildFeatureCheck(
                      title: isFarm
                          ? 'Full Diagnostic & Agronomy Reports'
                          : (isPro
                              ? 'Detailed Disease Reports & Treatment Plans'
                              : 'Basic Disease Identification'),
                      isUnlocked: true,
                    ),

                    // 4. Detailed Treatment Protocols (Pro & Farm only)
                    _buildFeatureCheck(
                      title: 'Detailed Disease Treatment & Prevention Protocols',
                      isUnlocked: isPaid,
                    ),

                    // 5. Analytics & Deep Scan History (Pro & Farm only)
                    _buildFeatureCheck(
                      title: 'Analytics & Full Diagnostic Scan History',
                      isUnlocked: isPaid,
                    ),

                    // 6. Garden Tracking (Farm only)
                    _buildFeatureCheck(
                      title: 'Multi-Plant Garden Tracking & Reminders',
                      isUnlocked: isFarm,
                    ),

                    // 7. Priority AI & Beta Access (Farm only)
                    _buildFeatureCheck(
                      title: 'Priority AI Processing & Beta Access',
                      isUnlocked: isFarm,
                    ),

                    const SizedBox(height: 32),

                    // Action buttons
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => UpgradeScreen(isPro: isPro)),
                          ).then((_) => _loadData());
                        },
                        icon: const Icon(Icons.upgrade_rounded, size: 20),
                        label: Text(
                          isPaid && !isPaidExpired
                              ? 'Change / Renew Subscription'
                              : 'Upgrade to Pro / Farm Pack',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusPill)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 70),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildQuotaTile({
    required String title,
    required int used,
    required int limit,
    required IconData icon,
    required Color color,
    bool isTrialNotStarted = false,
    bool isTrialExpired = false,
  }) {
    final isUnlimited = limit < 0;
    final progress = isUnlimited ? 0.0 : (limit > 0 ? (used / limit).clamp(0.0, 1.0) : 1.0);
    final remaining = isUnlimited ? -1 : (limit - used).clamp(0, limit);

    final String statusText;
    if (isTrialNotStarted) {
      statusText = '$used / $limit (Trial Needed)';
    } else if (isTrialExpired) {
      statusText = '$used / $limit (Trial Ended)';
    } else if (isUnlimited) {
      statusText = '$used used (Unlimited ∞)';
    } else {
      statusText = '$used / $limit ($remaining left)';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTokens.radiusMD),
        border: Border.all(color: AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: isUnlimited ? 0.15 : progress,
              backgroundColor: AppColors.lightSurface,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCheck({required String title, required bool isUnlocked}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            isUnlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
            color: isUnlocked ? AppColors.primaryLight : AppColors.textMuted,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: isUnlocked ? AppColors.textPrimary : AppColors.textMuted,
                fontWeight: isUnlocked ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
