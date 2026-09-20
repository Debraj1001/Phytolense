// lib/widgets/emergency_doctor_pass_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/ai_limit_provider.dart';
import '../providers/app_config_provider.dart';
import '../providers/user_provider.dart';
import '../screens/ai/chatbot_screen.dart';
import '../screens/subscription/upgrade_screen.dart';
import '../screens/subscription/trial_activation_screen.dart';
import '../services/payment_service.dart';
import '../services/supabase_service.dart';
import '../theme/colors.dart';
import 'bouncing_button.dart';

class EmergencyDoctorPassSheet extends ConsumerStatefulWidget {
  const EmergencyDoctorPassSheet({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const EmergencyDoctorPassSheet(),
    );
  }

  @override
  ConsumerState<EmergencyDoctorPassSheet> createState() => _EmergencyDoctorPassSheetState();
}

class _EmergencyDoctorPassSheetState extends ConsumerState<EmergencyDoctorPassSheet> {
  final PaymentService _paymentService = PaymentService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _paymentService.init(
      onSuccess: (plan) {
        if (!mounted) return;
        setState(() => _isLoading = false);

        // Refresh providers so user state updates immediately
        ref.invalidate(currentUserProvider);
        ref.read(aiLimitProvider.notifier).refreshLimit();

        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Emergency Doctor Pass Activated! Opening consultation...',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        // Directly open emergency doctor consultation
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ChatbotScreen(
              initialMessage:
                  '🚨 EMERGENCY CONSULTATION: I need urgent expert diagnosis and treatment guidance for my crop.',
            ),
          ),
        );
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }

  Future<void> _handleBuyPass() async {
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please log in to purchase the Emergency Doctor Pass.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final appUser = await SupabaseService().getUser(authUser.id);
    final email = appUser?.email ?? authUser.email ?? '';
    final phone = appUser?.phone ?? '';

    await _paymentService.openCheckout(
      plan: 'emergency_doctor',
      userEmail: email,
      userContact: phone,
      planName: 'Emergency Doctor Pass — PhytoLens',
      customAmountPaise: 1000, // ₹10.00
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final config = ref.watch(appConfigProvider).value ?? const AppConfig();
    final isAlreadyPro = user?.isPro == true || user?.isFarm == true;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.support_agent_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Emergency Doctor Pass',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDE047),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '₹10 ONLY',
                                style: TextStyle(
                                  color: Color(0xFF713F12),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Instant 1-on-1 Agronomist & AI Doctor Consultation',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Perks List
            _buildPerkRow(
              icon: Icons.flash_on_rounded,
              iconColor: const Color(0xFFF59E0B),
              title: 'Zero Wait Priority Diagnosis',
              subtitle: 'Skip queues with dedicated priority AI agronomist processing.',
            ),
            const SizedBox(height: 12),
            _buildPerkRow(
              icon: Icons.medication_liquid_rounded,
              iconColor: const Color(0xFF10B981),
              title: 'Prescription & Spray Dosage',
              subtitle: 'Exact chemical and organic remedy formulas for critical recovery.',
            ),
            const SizedBox(height: 12),
            _buildPerkRow(
              icon: Icons.chat_bubble_outline_rounded,
              iconColor: const Color(0xFF6366F1),
              title: 'Interactive Question & Answer',
              subtitle: 'Ask follow-up questions and verify symptom improvements.',
            ),
            const SizedBox(height: 12),
            _buildPerkRow(
              icon: Icons.alarm_rounded,
              iconColor: const Color(0xFF0EA5E9),
              title: '24-Hour Active Window',
              subtitle: 'Full 1-day uninterrupted access without subscription commitment.',
            ),

            const SizedBox(height: 20),

            // User already has membership banner
            if (isAlreadyPro) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_rounded, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your membership already includes expert Doctor consultations!',
                        style: TextStyle(
                          color: Color(0xFF065F46),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              BouncingButton(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ChatbotScreen(
                        initialMessage:
                            '🚨 EMERGENCY CONSULTATION: I need urgent expert guidance for my plant.',
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'Start Doctor Consultation',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Purchase CTA button
              BouncingButton(
                onTap: _isLoading ? null : _handleBuyPass,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Activate Emergency Pass — ₹10',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Secondary actions: AI Chat (access-controlled) & Upgrade Screen
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // ── ACCESS CONTROL: No free bypass to chat ──
                        final aiLimit = ref.read(aiLimitProvider).value;
                        final isLocked = aiLimit == null || aiLimit.isExpired || !aiLimit.canUse;
                        
                        Navigator.pop(context);
                        
                        if (aiLimit?.isExpired == true) {
                          // Trial ended → Upgrade
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                          );
                        } else if (aiLimit?.isNotStarted == true) {
                          // Trial not activated yet → Activate Trial
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const TrialActivationScreen()),
                          );
                        } else if (isLocked) {
                          // Daily limit reached or unknown state → Upgrade
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                          );
                        } else {
                          // Active trial or paid tier → allow chat
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ChatbotScreen()),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'AI Doctor Chat',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'View Pro (₹${config.proMonthlyPrice}/mo)',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPerkRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
