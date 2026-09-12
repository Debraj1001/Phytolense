// lib/screens/profile/help_support_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/colors.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const _faqs = [
    _Faq(
      q: 'Which plants can PhytoLens detect?',
      a: 'PhytoLens uses an on-device AI model trained on 14 crops: Apple, Blueberry, Cherry, Corn, Grape, Orange, Peach, Pepper, Potato, Raspberry, Soybean, Squash, Strawberry, and Tomato. It can detect 38 different conditions (diseases + healthy) across these crops.',
    ),
    _Faq(
      q: 'What does the confidence percentage mean?',
      a: 'Confidence shows how certain the AI model is about its diagnosis. A score above 75% is reliable. Scores below 45% indicate the plant may not be in the supported crop list — use the "Ask AI" button in those cases for help.',
    ),
    _Faq(
      q: 'How do scans count against my daily limit?',
      a: 'Free accounts get 15 scans per day. Pro accounts get 50 scans per day. Farm accounts get up to 100 scans per day. Your scan count resets at midnight every day.',
    ),
    _Faq(
      q: 'How does the AI chat (Ask AI) work?',
      a: 'The AI Advisor uses cloud AI to answer plant health questions. Free users get 15 AI messages per day. Pro users get 50, and Farm users get up to 100 per day. AI requires an internet connection.',
    ),
    _Faq(
      q: 'Is my scan data private?',
      a: 'Yes. Scan images are only used for on-device analysis and are not sent to any server for classification. Your scan results (plant name, disease, score) are stored securely in our database under your user account.',
    ),
    _Faq(
      q: 'How does the billing work?',
      a: 'PhytoLens uses one-time payments — there is no automatic renewal. When you purchase Pro (₹49) or Farm (₹199), you get access for 30 days. When the period ends, you\'ll need to manually renew to continue.',
    ),
    _Faq(
      q: 'What is the Garden feature?',
      a: 'My Garden lets you track specific plants you\'re growing. Add your plants by name, then scan them directly from the garden to build a health history for each plant over time.',
    ),
    _Faq(
      q: 'How do I earn XP and badges?',
      a: 'You earn XP by scanning plants (10 XP per scan), maintaining daily streaks, and discovering diseases early. Badges are awarded for milestones like "First Scan", "5-Day Streak", and "Disease Detector".',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        title: const Text('Help & Support'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.support_agent_rounded,
                      color: AppColors.primaryLight, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'We\'re here to help',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Browse FAQs or contact us directly.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(),

          const SizedBox(height: 24),

          const Text(
            'Frequently Asked Questions',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          ..._faqs.asMap().entries.map((e) =>
            _FaqTile(faq: e.value)
                .animate(delay: Duration(milliseconds: 50 * e.key))
                .fadeIn()
                .slideY(begin: 0.05, end: 0),
          ),

          const SizedBox(height: 24),

          // Contact
          const Text(
            'Contact Us',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          _ContactTile(
            icon: Icons.email_outlined,
            title: 'Email Support',
            subtitle: 'support@phytolens.app',
            onTap: () => launchUrl(Uri.parse('mailto:support@phytolens.app?subject=PhytoLens%20Support')),
          ).animate(delay: 100.ms).fadeIn(),

          const SizedBox(height: 8),

          _ContactTile(
            icon: Icons.language_outlined,
            title: 'Visit our website',
            subtitle: 'www.phytolens.app',
            onTap: () => launchUrl(Uri.parse('https://phytolens.app')),
          ).animate(delay: 150.ms).fadeIn(),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _Faq {
  final String q;
  final String a;
  const _Faq({required this.q, required this.a});
}

class _FaqTile extends StatefulWidget {
  final _Faq faq;
  const _FaqTile({required this.faq});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _open
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.textMuted.withValues(alpha: 0.1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.faq.q,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.keyboard_arrow_down,
                          color: AppColors.textMuted, size: 20),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: _open
                      ? Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            widget.faq.a,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.6,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ContactTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardDark,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primaryLight, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new_rounded,
                  size: 16, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
