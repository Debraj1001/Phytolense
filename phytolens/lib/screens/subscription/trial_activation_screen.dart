// lib/screens/subscription/trial_activation_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/colors.dart';
import '../../widgets/bouncing_button.dart';
import '../../services/payment_service.dart';
import '../../services/trial_service.dart';
import '../../providers/user_provider.dart';
import '../../providers/app_config_provider.dart';
import '../../services/supabase_service.dart';
import '../../config/constants.dart';
import 'upgrade_screen.dart';

class TrialActivationScreen extends ConsumerStatefulWidget {
  final bool fromOnboarding;
  const TrialActivationScreen({super.key, this.fromOnboarding = false});

  @override
  ConsumerState<TrialActivationScreen> createState() => _TrialActivationScreenState();
}

class _TrialActivationScreenState extends ConsumerState<TrialActivationScreen> {
  final PaymentService _paymentService = PaymentService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _paymentService.init(
      onSuccess: (response) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Tier 1 Pro Trial Activated Successfully!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          if (widget.fromOnboarding) {
            Navigator.pushNamedAndRemoveUntil(context, AppConstants.routeHome, (_) => false);
          } else {
            Navigator.pop(context);
          }
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }

  void _startTrial(AppConfig cfg) async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    setState(() => _isLoading = true);
    
    final trialPaise = (cfg.trialPrice * 100).toInt();
    if (trialPaise <= 0) {
      try {
        await SupabaseService().activateTrial(user.uid);
        ref.invalidate(currentUserProvider);
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${cfg.trialDays}-Day Free Trial Activated Successfully!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          if (widget.fromOnboarding) {
            Navigator.pushNamedAndRemoveUntil(context, AppConstants.routeHome, (_) => false);
          } else {
            Navigator.pop(context);
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to activate trial: $e'), backgroundColor: AppColors.error),
          );
        }
      }
      return;
    }

    _paymentService.openCheckout(
      plan: 'trial',
      userEmail: user.email,
      userContact: user.phone ?? '',
      customAmountPaise: trialPaise,
    );
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(appConfigProvider);
    final cfg = configAsync.value ?? const AppConfig();
    final user = ref.watch(currentUserProvider).value;
    final trialInfo = TrialService.getTrialInfo(user, trialDays: cfg.trialDays);

    // If trial is already expired, direct the user to UpgradeScreen
    if (trialInfo.isExpired) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: AppColors.surfaceDark,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            onPressed: () {
              if (widget.fromOnboarding) {
                Navigator.pushNamedAndRemoveUntil(context, AppConstants.routeHome, (_) => false);
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: const Text('Trial Concluded', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_clock_rounded, size: 52, color: AppColors.warning),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Your Pro Trial Has Concluded',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your ${cfg.trialDays}-day Pro trial has ended. To continue scanning plant leaves and accessing botanist AI chats, please choose a plan below.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 32),
                BouncingButton(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        'View Plans (From ${cfg.proPrice}/month)',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // If trial is already active, acknowledge it
    if (trialInfo.isActive) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: AppColors.surfaceDark,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            onPressed: () {
              if (widget.fromOnboarding) {
                Navigator.pushNamedAndRemoveUntil(context, AppConstants.routeHome, (_) => false);
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: const Text('Pro Trial Active', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, size: 52, color: AppColors.primary),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Your Pro Trial is Active!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You are enjoying Tier 1 (Pro) benefits with ${trialInfo.remainingDays} day${trialInfo.remainingDays == 1 ? "" : "s"} remaining (${cfg.proScanLabel} scans & ${cfg.proAiLabel} AI chats).',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 32),
                BouncingButton(
                  onTap: () {
                    Navigator.pushNamedAndRemoveUntil(context, AppConstants.routeHome, (_) => false);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text(
                        'Go to Dashboard',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppColors.surfaceDark,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
              onPressed: () {
                if (widget.fromOnboarding) {
                  Navigator.pushNamedAndRemoveUntil(context, AppConstants.routeHome, (_) => false);
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Hero Gradient Background
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.15),
                          AppColors.primary.withValues(alpha: 0.02),
                          AppColors.backgroundDark,
                        ],
                      ),
                    ),
                  ),
                  // Background Pattern / Icon
                  Positioned(
                    right: -40,
                    top: -20,
                    child: Icon(
                      Icons.eco_rounded,
                      size: 260,
                      color: AppColors.primary.withValues(alpha: 0.05),
                    ),
                  ),
                  // Content
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          size: 48,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Start Free Trial',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cfg.trialPrice <= 0
                            ? 'Enjoy ${cfg.trialDays} days of plant diagnosis for ₹0 (Free)'
                            : 'Start your ${cfg.trialDays}-Day Trial for just ₹${cfg.trialPrice.toInt()}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Free Trial Benefits Included',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'FREE TRIAL',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryLight,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildFeatureRow(
                    icon: Icons.qr_code_scanner_rounded,
                    title: '${cfg.freeScanLimit} Plant Scans / Day',
                    subtitle: 'Scan up to ${cfg.freeScanLimit} plant leaves daily with AI precision',
                  ),
                  const SizedBox(height: 18),
                  _buildFeatureRow(
                    icon: Icons.smart_toy_rounded,
                    title: '${cfg.freeAiLimit} Botanist AI Diagnostics',
                    subtitle: 'Ask our botanist AI up to ${cfg.freeAiLimit} questions every day',
                  ),
                  const SizedBox(height: 18),
                  _buildFeatureRow(
                    icon: Icons.monitor_heart_rounded,
                    title: 'Disease & Remedy Diagnosis',
                    subtitle: 'Comprehensive health reports, causes & organic/chemical remedies',
                  ),
                  const SizedBox(height: 18),
                  _buildFeatureRow(
                    icon: Icons.yard_rounded,
                    title: '1 Farm / Plot Setup',
                    subtitle: 'Organize and monitor your primary plot',
                  ),
                  const SizedBox(height: 18),
                  _buildFeatureRow(
                    icon: Icons.verified_rounded,
                    title: '100% Free & No Card Needed',
                    subtitle: 'Zero charges, no auto-renewal, and no surprise debits',
                  ),
                  
                  const SizedBox(height: 36),

                  // Price Tag
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.lightBorder),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Trial Activation Fee',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '₹',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              '${cfg.trialPrice.toInt()}',
                              style: const TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Valid for ${cfg.trialDays} days. No auto-renewal.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  BouncingButton(
                    onTap: _isLoading ? null : () => _startTrial(cfg),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                cfg.trialPrice <= 0
                                    ? 'Start ${cfg.trialDays}-Day Free Trial'
                                    : 'Activate ${cfg.trialDays}-Day Trial (₹${cfg.trialPrice.toInt()})',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  
                  if (widget.fromOnboarding) ...[
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppConstants.routeHome,
                          (_) => false,
                        ),
                        child: const Text(
                          'Explore PhytoLens first',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  const Center(
                    child: Text(
                      'Powered by Razorpay · Secure Checkout',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.lightBorder),
          ),
          child: Icon(icon, color: AppColors.primary, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
