// lib/screens/profile/privacy_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/colors.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        title: const Text('Privacy Policy'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Effective date header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.1)),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_user_outlined, color: AppColors.primaryLight, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PhytoLens Privacy Policy',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Effective: 1 August 2025 · Last updated: 13 August 2026',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(),

          const SizedBox(height: 20),

          const _PrivacySection(
            title: '1. Who We Are',
            body: 'PhytoLens ("we", "our", or "us") is an AI-powered plant health application developed for farmers, gardeners, and agricultural enthusiasts. Our registered contact email is: support@phytolens.app.',
          ),

          const _PrivacySection(
            title: '2. What We Collect',
            body: '• Account Information: Email address, display name, and profile photo (optional) when you register.\n'
                '• Scan Data: The result of each scan — plant name, disease name, health score, and scan timestamp. Camera images are analyzed on-device and are NOT uploaded to our servers.\n'
                '• AI Chat Messages: When you use the AI Advisor, your messages are sent to Groq\'s API to generate responses. We store a count of your daily usage, not the message content.\n'
                '• Payment Data: Payments are processed by Razorpay. We only store your subscription tier and payment transaction ID — no card numbers or bank details.\n'
                '• Device/Usage Data: App version, device type, and anonymous usage events to help us improve the app.',
          ),

          const _PrivacySection(
            title: '3. How We Use Your Data',
            body: '• To provide the core plant scanning and AI advisory features.\n'
                '• To manage your account, subscription, and scan history.\n'
                '• To calculate XP, streaks, and award badges.\n'
                '• To send optional push notifications about plant care reminders (you can opt out at any time in device settings).\n'
                '• To improve the app based on aggregated, anonymized usage patterns.',
          ),

          const _PrivacySection(
            title: '4. On-Device AI Processing',
            body: 'The plant disease classification model runs entirely on your device using TensorFlow Lite. Your plant photos are never uploaded to PhytoLens servers for the purpose of classification. Images may be saved locally on your device based on your settings.',
          ),

          const _PrivacySection(
            title: '5. Data Sharing',
            body: 'We do not sell your personal data. We share data only with:\n'
                '• Supabase (database hosting) — stores your account and scan records securely.\n'
                '• Firebase (authentication) — manages your login and push tokens.\n'
                '• Groq (AI API) — processes AI chat messages you send. Groq\'s privacy policy applies.\n'
                '• Razorpay (payments) — processes payments. Razorpay\'s privacy policy applies.',
          ),

          const _PrivacySection(
            title: '6. Data Retention',
            body: 'We retain your scan history for as long as your account is active. If you delete your account, all your personal data and scan history will be permanently deleted within 30 days.',
          ),

          const _PrivacySection(
            title: '7. Your Rights (GDPR & Regional Laws)',
            body: 'Depending on your location, you may have the right to:\n'
                '• Access the personal data we hold about you.\n'
                '• Request correction of inaccurate data.\n'
                '• Request deletion of your data ("right to be forgotten").\n'
                '• Request a portable copy of your data.\n\n'
                'To exercise these rights, email us at: support@phytolens.app',
          ),

          const _PrivacySection(
            title: '8. Security',
            body: 'All data is transmitted over encrypted HTTPS connections. Database access is protected by row-level security policies. We use Firebase Auth industry-standard authentication.',
          ),

          const _PrivacySection(
            title: '9. Children\'s Privacy',
            body: 'PhytoLens is not directed at children under 13. We do not knowingly collect data from children. If you believe a child has created an account, please contact us so we can delete it.',
          ),

          const _PrivacySection(
            title: '10. Changes to This Policy',
            body: 'We may update this policy from time to time. We will notify you of material changes through the app or by email. Continued use after changes constitutes acceptance of the updated policy.',
          ),

          const _PrivacySection(
            title: '11. Contact',
            body: 'For any privacy concerns, please contact us at:\nEmail: support@phytolens.app\nWebsite: www.phytolens.app/privacy',
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  final String title;
  final String body;

  const _PrivacySection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.65,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.03, end: 0);
  }
}
