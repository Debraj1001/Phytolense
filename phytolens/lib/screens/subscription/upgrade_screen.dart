// lib/screens/subscription/upgrade_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phytolens/screens/subscription/premium_transformation_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:confetti/confetti.dart';
import '../../providers/app_config_provider.dart';
import '../../services/supabase_service.dart';
import '../../services/payment_service.dart';
import '../../services/trial_service.dart';
import '../../theme/colors.dart';
import '../../widgets/loading_dots.dart';
import '../../providers/user_provider.dart';

class UpgradeScreen extends ConsumerStatefulWidget {
  final bool isPro;
  const UpgradeScreen({super.key, this.isPro = false});

  @override
  ConsumerState<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends ConsumerState<UpgradeScreen> {
  late final PaymentService _payment;
  late final ConfettiController _confetti;
  String? _processingPlan;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    _payment = PaymentService()
      ..init(
        onSuccess: (plan) {
          if (mounted) {
            setState(() => _processingPlan = null);
            _confetti.play();
            _showSuccess(plan);
          }
        },
        onError: (e) {
          if (mounted) {
            setState(() => _processingPlan = null);
            final isCancelled = e.toLowerCase().contains('cancel');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(
                      isCancelled ? Icons.info_outline_rounded : Icons.error_outline_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        e,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                backgroundColor: isCancelled ? const Color(0xFF263238) : AppColors.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                duration: Duration(seconds: isCancelled ? 2 : 4),
              ),
            );
          }
        },
      );
  }

  Future<void> _subscribe(String plan) async {
    setState(() => _processingPlan = plan);
    _payment.setPlan(plan);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final appUser = await SupabaseService().getUser(user.uid);
    final email = appUser?.email ?? user.email ?? '';

    final cfg = ref.read(appConfigProvider).value ?? const AppConfig();
    final amountInPaise = plan == 'pro' ? cfg.proMonthlyPaise : cfg.farmMonthlyPaise;

    _payment.openCheckout(
      plan: plan,
      userId: user.uid,
      email: email,
      amountInPaise: amountInPaise,
    );
  }

  void _showSuccess(String plan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PremiumTransformationScreen(tier: plan),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch the live config — rebuilds whenever Supabase pushes an update
    final configAsync = ref.watch(appConfigProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          configAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => _buildBody(const AppConfig()),  // fallback defaults
            data: (cfg) => _buildBody(cfg),
          ),

          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 40,
              colors: const [
                AppColors.primaryLight,
                Color(0xFFFFD700),
                Colors.white,
                Color(0xFF00BCD4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AppConfig cfg) {
    return CustomScrollView(
      slivers: [
        // ── Hero App Bar ────────────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          backgroundColor: AppColors.backgroundDark,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 18, color: Colors.white),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF064E3B), Color(0xFF090D11)],
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.eco_rounded, color: AppColors.primaryLight, size: 38),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Upgrade PhytoLens',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'One-time payment · No auto-renewal',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xB3FFFFFF),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Billing notice
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: AppColors.primaryLight, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pay once, use for 30 days. Renew manually when ready. No surprise charges.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(),

              const SizedBox(height: 14),

              // Trial countdown chip (for free users)
              Builder(builder: (_) {
                final liveUser = ref.watch(currentUserProvider).value;
                final trialInfo = TrialService.getTrialInfo(
                  liveUser,
                  trialDays: cfg.trialDays,
                );
                return _buildTrialStatusCard(trialInfo, cfg);
              }),

              const SizedBox(height: 24),

              // Live features comparison table
              _buildFeaturesTable(cfg).animate(delay: 100.ms).fadeIn(),

              const SizedBox(height: 24),

              // Pro Plan Card (live limits + price)
              if (!widget.isPro)
                _buildPlanCard(
                  plan: 'pro',
                  title: 'Pro',
                  emoji: '⚡',
                  price: cfg.proPrice,
                  period: '30 days',
                  tagline: 'Perfect for home gardeners',
                  accentColor: const Color(0xFF00BCD4),
                  features: [
                    ('${cfg.proScanLabel} scans', true),
                    ('${cfg.proAiLabel} AI chats', true),
                    ('Detailed disease reports', true),
                    ('Analytics & scan history', true),
                    ('Priority support', true),
                  ],
                ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.1, end: 0),

              if (!widget.isPro) const SizedBox(height: 14),

              // Farm Pack Card (live limits + price)
              _buildPlanCard(
                plan: 'farm',
                title: 'Farm Pack',
                emoji: '🌾',
                price: cfg.farmPrice,
                period: '30 days',
                tagline: 'For serious farmers & professionals',
                accentColor: const Color(0xFFFFD700),
                isBestValue: true,
                features: [
                  ('${cfg.farmScanLabel} scans', true),
                  ('${cfg.farmAiLabel} AI chats', true),
                  ('Full disease reports', true),
                  ('Multi-plant garden tracking', cfg.gardenEnabled),
                  ('Bulk export & reports', cfg.bulkExportEnabled),
                  ('Beta features access', true),
                ],
              ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.1, end: 0),

              const SizedBox(height: 24),

              // Trust badges
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TrustBadge(icon: Icons.lock_outline, label: 'Secure\nPayment'),
                  const SizedBox(width: 20),
                  _TrustBadge(icon: Icons.refresh_rounded, label: 'No Auto\nRenewal'),
                  const SizedBox(width: 20),
                  _TrustBadge(icon: Icons.support_agent_rounded, label: '24/7\nSupport'),
                ],
              ).animate(delay: 400.ms).fadeIn(),

              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Powered by Razorpay · Test mode active',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 24),

              // What happens after trial? FAQ
              _buildTrialFaq().animate(delay: 500.ms).fadeIn(),

              const SizedBox(height: 40),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard({
    required String plan,
    required String title,
    required String emoji,
    required String price,
    required String period,
    required String tagline,
    required Color accentColor,
    required List<(String, bool)> features,
    bool isBestValue = false,
  }) {
    final isProcessing = _processingPlan == plan;
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                          ),
                        ),
                        Text(
                          tagline,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        price,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'for $period',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(color: Color(0x1A8FA98D), height: 1),
              const SizedBox(height: 14),

              // Features
              ...features.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: f.$2
                                ? accentColor.withValues(alpha: 0.15)
                                : AppColors.textMuted.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            f.$2 ? Icons.check : Icons.remove,
                            size: 11,
                            color: f.$2 ? accentColor : AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          f.$1,
                          style: TextStyle(
                            fontSize: 13,
                            color: f.$2 ? AppColors.textSecondary : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )),

              const SizedBox(height: 18),

              // CTA
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isProcessing ? null : () => _subscribe(plan),
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                  ),
                  child: isProcessing
                      ? const ButtonDots()
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Get $title for $price',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
        if (isBestValue)
          Positioned(
            top: -1,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: const BoxDecoration(
                color: Color(0xFFFFD700),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
              ),
              child: const Text(
                'BEST VALUE',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1200),
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTrialStatusCard(TrialInfo trialInfo, AppConfig cfg) {
    final isExpired = trialInfo.isExpired;
    final accentColor = isExpired ? AppColors.error : AppColors.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('🌱', style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Free Plan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                    Text(
                      isExpired
                          ? 'Trial ended · Limited to ${cfg.freeScanLimit > 0 ? "1" : cfg.freeScanLabel} scan/day'
                          : 'Trial · ${trialInfo.shortLabel}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                'FREE',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                ),
              ),
            ],
          ),
          if (!isExpired) ...[
            const SizedBox(height: 12),
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
                  style: TextStyle(fontSize: 10, color: accentColor.withValues(alpha: 0.6)),
                ),
                Text(
                  '${trialInfo.remainingDays} days remaining',
                  style: TextStyle(fontSize: 10, color: accentColor.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Divider(color: Color(0x1A8FA98D), height: 1),
          const SizedBox(height: 10),
          // Current limits
          ...['${cfg.freeScanLabel} scans', '${cfg.freeAiLabel} AI chats', 'Basic disease reports'].map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, size: 10, color: AppColors.textMuted),
                  ),
                  const SizedBox(width: 8),
                  Text(f, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05, end: 0);
  }

  Widget _buildTrialFaq() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.help_outline_rounded, color: AppColors.textSecondary, size: 18),
              SizedBox(width: 8),
              Text(
                'What happens after the trial?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _faqItem(
            '📱',
            'Can I still use the app?',
            'Yes! After your trial, you move to a starter plan with 1 scan and 1 AI chat per day. You never lose access.',
          ),
          _faqItem(
            '💰',
            'Will I be charged automatically?',
            'Never. All upgrades are one-time payments for 30 days. No auto-renewal, no surprise charges.',
          ),
          _faqItem(
            '📊',
            'What about my scan history?',
            'All your scans, reports, and data are kept forever, regardless of your plan.',
          ),
        ],
      ),
    );
  }

  Widget _faqItem(String emoji, String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  answer,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Live comparison table — values come from AppConfig
  Widget _buildFeaturesTable(AppConfig cfg) {
    final rows = [
      ('Daily Scans', cfg.freeScanLabel, cfg.proScanLabel, cfg.farmScanLabel),
      ('AI Chats',   cfg.freeAiLabel,   cfg.proAiLabel,   cfg.farmAiLabel),
      ('Disease Reports', 'Basic', 'Detailed', 'Full'),
      ('Analytics', '✗', '✓', '✓'),
      ('Garden Tracking', '✗', '✗', cfg.gardenEnabled ? '✓' : '✗'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.lightCard,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text('Feature', style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600))),
                Expanded(child: Center(child: Text('Free', style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)))),
                Expanded(child: Center(child: Text('Pro ⚡', style: TextStyle(fontSize: 11, color: Color(0xFF00BCD4), fontWeight: FontWeight.w700)))),
                Expanded(child: Center(child: Text('Farm 🌾', style: TextStyle(fontSize: 11, color: Color(0xFFFFD700), fontWeight: FontWeight.w700)))),
              ],
            ),
          ),
          // Data rows
          ...rows.map((r) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Text(r.$1, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
                    Expanded(child: Center(child: Text(r.$2, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)))),
                    Expanded(child: Center(child: Text(r.$3, style: const TextStyle(fontSize: 12, color: Color(0xFF00BCD4), fontWeight: FontWeight.w600)))),
                    Expanded(child: Center(child: Text(r.$4, style: const TextStyle(fontSize: 12, color: Color(0xFFFFD700), fontWeight: FontWeight.w600)))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _payment.dispose();
    _confetti.dispose();
    super.dispose();
  }
}

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TrustBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.15)),
          ),
          child: Icon(icon, color: AppColors.primaryLight, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: AppColors.textMuted, height: 1.3),
        ),
      ],
    );
  }
}
