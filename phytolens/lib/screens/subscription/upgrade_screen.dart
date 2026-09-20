// lib/screens/subscription/upgrade_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:confetti/confetti.dart';
import 'premium_transformation_screen.dart';
import 'trial_activation_screen.dart';
import '../../providers/app_config_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/supabase_service.dart';
import '../../services/payment_service.dart';
import '../../services/trial_service.dart';
import '../../theme/colors.dart';
import '../../widgets/loading_dots.dart';

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
  bool _featuresExpanded = false;

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

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _processingPlan = null);
      return;
    }

    final appUser = await SupabaseService().getUser(user.id);
    final email = appUser?.email ?? user.email ?? '';

    final cfg = ref.read(appConfigProvider).value ?? const AppConfig();
    final amountInPaise = plan == 'pro' ? cfg.proMonthlyPaise : cfg.farmMonthlyPaise;

    _payment.openCheckout(
      plan: plan,
      userEmail: email,
      userContact: appUser?.phone ?? '',
      customAmountPaise: amountInPaise,
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
    final configAsync = ref.watch(appConfigProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      body: Stack(
        children: [
          configAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (_, __) => _buildContent(const AppConfig()),
            data: (cfg) => _buildContent(cfg),
          ),

          // Confetti overlay on purchase success
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

  Widget _buildContent(AppConfig cfg) {
    final liveUser = ref.watch(currentUserProvider).value;
    final trialInfo = TrialService.getTrialInfo(liveUser, trialDays: cfg.trialDays);

    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Clean Top Navigation Bar ──────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF374151)),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_outlined, size: 14, color: AppColors.primary),
                        SizedBox(width: 5),
                        Text(
                          'No Auto-Debit',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Header Title ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFA7F3D0), width: 1.5),
                    ),
                    child: const Center(
                      child: Text('🌱', style: TextStyle(fontSize: 26)),
                    ),
                  ).animate().scale(duration: 350.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: 12),
                  const Text(
                    'Upgrade PhytoLens',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Simple one-time payment · 30 days access · Zero surprises',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Main Content Body ─────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 1. ₹1 Trial Opportunity Banner (if not yet started)
                if (trialInfo.isNotStarted)
                  _buildTrialOfferCard(cfg).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0)
                else if (trialInfo.isActive)
                  _buildActiveTrialPill(trialInfo, cfg).animate().fadeIn(duration: 300.ms)
                else if (trialInfo.isExpired)
                  _buildExpiredTrialNotice().animate().fadeIn(duration: 300.ms),

                const SizedBox(height: 16),

                // 2. Pro Plan Card
                _buildPlanCard(
                  plan: 'pro',
                  badge: '⚡ MOST POPULAR',
                  badgeColor: const Color(0xFF0284C7),
                  badgeBg: const Color(0xFFE0F2FE),
                  title: 'Pro Plan',
                  subtitle: 'Ideal for home gardens & hobby growers',
                  price: cfg.proPrice,
                  period: '30 days',
                  accentColor: const Color(0xFF0284C7),
                  features: [
                    '${cfg.proScanLabel} Leaf Scans',
                    '${cfg.proAiLabel} AI Plant Doctor Chats',
                    'Detailed Disease & Remedy Reports',
                    'Health Analytics & History',
                  ],
                ).animate().fadeIn(delay: 100.ms, duration: 350.ms).slideY(begin: 0.05, end: 0),

                const SizedBox(height: 16),

                // 3. Farm Pack Card
                _buildPlanCard(
                  plan: 'farm',
                  badge: '🌾 MAXIMUM POWER',
                  badgeColor: const Color(0xFFB45309),
                  badgeBg: const Color(0xFFFEF3C7),
                  title: 'Farm Pack',
                  subtitle: 'For serious farmers, agronomists & plots',
                  price: cfg.farmPrice,
                  period: '30 days',
                  accentColor: const Color(0xFFD97706),
                  isHighlighted: true,
                  features: [
                    '${cfg.farmScanLabel} Leaf Scans',
                    '${cfg.farmAiLabel} AI Plant Doctor Chats',
                    'Multi-plant Garden & Plot Tracking',
                    'Bulk Export & PDF Agronomy Reports',
                    'Priority Leaf Diagnostics Engine',
                  ],
                ).animate().fadeIn(delay: 200.ms, duration: 350.ms).slideY(begin: 0.05, end: 0),

                const SizedBox(height: 20),

                // 4. Clean Feature Comparison Expandable
                _buildExpandableComparison(cfg),

                const SizedBox(height: 24),

                // 5. Peace of Mind Guarantees
                _buildTrustRow(),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick Trial Promo Card ────────────────────────────────────────────────
  Widget _buildTrialOfferCard(AppConfig cfg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFECFDF5), Color(0xFFF0FDF4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF059669).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: const Icon(Icons.bolt_rounded, color: Color(0xFF059669), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cfg.trialPrice <= 0
                      ? 'Start Free Trial (${cfg.trialDays} Days)'
                      : 'Start ₹${cfg.trialPrice.toInt()} Trial (${cfg.trialDays} Days)',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF065F46),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${cfg.freeScanLimit} free scans & AI chats/day · ${cfg.trialPrice <= 0 ? "₹0 / No card" : "₹${cfg.trialPrice.toInt()} Trial"}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF047857)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TrialActivationScreen()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text(
              'Activate',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTrialPill(TrialInfo trialInfo, AppConfig cfg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Free Trial Active · ${trialInfo.remainingDays} day${trialInfo.remainingDays == 1 ? "" : "s"} left (${cfg.freeScanLimit} scans/day)',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E40AF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiredTrialNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: const Row(
        children: [
          Icon(Icons.access_time_rounded, color: Color(0xFFDC2626), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your Free Trial has ended. Choose Pro or Farm Pack below to continue scanning and diagnosing plants.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF991B1B),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Plan Card ─────────────────────────────────────────────────────────────
  Widget _buildPlanCard({
    required String plan,
    required String badge,
    required Color badgeColor,
    required Color badgeBg,
    required String title,
    required String subtitle,
    required String price,
    required String period,
    required Color accentColor,
    required List<String> features,
    bool isHighlighted = false,
  }) {
    final isProcessing = _processingPlan == plan;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isHighlighted ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
          width: isHighlighted ? 1.8 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isHighlighted ? const Color(0xFFD97706) : Colors.black).withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Badge & Period
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                'One-time · $period',
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Price & Title
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                price,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374151),
                ),
              ),
            ],
          ),

          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),

          const SizedBox(height: 16),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 14),

          // Feature list
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: const Icon(Icons.check_rounded, size: 12, color: Color(0xFF059669)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        f,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                  ],
                ),
              )),

          const SizedBox(height: 16),

          // Action Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: isProcessing ? null : () => _subscribe(plan),
              style: ElevatedButton.styleFrom(
                backgroundColor: isHighlighted ? const Color(0xFFD97706) : const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: isProcessing
                  ? const ButtonDots(color: Colors.white)
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Get $title — $price',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Expandable Comparison ─────────────────────────────────────────────────
  Widget _buildExpandableComparison(AppConfig cfg) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _featuresExpanded,
          onExpansionChanged: (v) => setState(() => _featuresExpanded = v),
          title: const Text(
            'Compare all plans side-by-side',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          leading: const Icon(Icons.table_chart_outlined, color: Color(0xFF4B5563), size: 20),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(2.2),
                  1: FlexColumnWidth(1.2),
                  2: FlexColumnWidth(1.2),
                  3: FlexColumnWidth(1.2),
                },
                children: [
                  // Table Header
                  TableRow(
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
                    ),
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Feature', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(child: Text(cfg.trialPrice <= 0 ? 'Free Trial' : '₹${cfg.trialPrice.toInt()} Trial', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF059669)))),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(child: Text('Pro ⚡', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)))),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(child: Text('Farm 🌾', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFD97706)))),
                      ),
                    ],
                  ),
                  _comparisonRow('Period', '${cfg.trialDays} Days (Trial)', '30 Days', '30 Days'),
                  _comparisonRow('Price', cfg.trialPrice <= 0 ? 'Free (₹0)' : '₹${cfg.trialPrice.toInt()} (Trial)', cfg.proPrice, cfg.farmPrice),
                  _comparisonRow('Daily Scans', cfg.freeScanLabel, cfg.proScanLabel, cfg.farmScanLabel),
                  _comparisonRow('AI Chats', cfg.freeAiLabel, cfg.proAiLabel, cfg.farmAiLabel),
                  _comparisonRow('Disease Reports', 'Basic', 'Detailed', 'Full'),
                  _comparisonRow('Farm Limits', '${cfg.farmCreationLimitFree}', '${cfg.farmCreationLimitPro}', '${cfg.farmCreationLimitFarm}'),
                  _comparisonRow('Garden Tracking', '✗', '✗', cfg.gardenEnabled ? '✓' : '✗'),
                  _comparisonRow('PDF Bulk Export', '✗', '✓', cfg.bulkExportEnabled ? '✓' : '✗'),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF475569)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'There is no permanent free tier. The ${cfg.trialPrice <= 0 ? "Free Trial" : "₹${cfg.trialPrice.toInt()} Trial"} provides ${cfg.freeScanLimit} daily scans for ${cfg.trialDays} days. Upgrade to Pro or Farm Pack to keep access.',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  TableRow _comparisonRow(String feature, String free, String pro, String farm) {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(feature, style: const TextStyle(fontSize: 12, color: Color(0xFF374151), fontWeight: FontWeight.w500)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(child: Text(free, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(child: Text(pro, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)))),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(child: Text(farm, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFD97706)))),
        ),
      ],
    );
  }

  // ── Peace of Mind Trust Row ───────────────────────────────────────────────
  Widget _buildTrustRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _TrustItem(icon: Icons.lock_outline_rounded, label: 'Razorpay\nSecure'),
          _TrustItem(icon: Icons.replay_rounded, label: 'No Auto\nRenewal'),
          _TrustItem(icon: Icons.history_rounded, label: 'Lifetime\nData Safe'),
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

class _TrustItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TrustItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF059669)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4B5563),
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
