// lib/screens/profile/about_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/colors.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = 'v${info.version} (${info.buildNumber})');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        title: const Text('About PhytoLens'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Logo & Version
          Center(
            child: Column(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.eco_rounded, color: Colors.white, size: 48),
                ),
                const SizedBox(height: 16),
                const Text(
                  'PhytoLens',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _version.isEmpty ? 'Loading...' : _version,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),

          const SizedBox(height: 32),

          // Mission
          _Section(
            title: 'Our Mission',
            child: const Text(
              'PhytoLens was built to put advanced plant health diagnostics in every farmer\'s pocket. '
              'Using on-device AI trained on thousands of diseased and healthy plant images, we help growers '
              'identify problems early — before they become costly crop losses.\n\n'
              'Our AI model is trained on the PlantVillage dataset and can diagnose 38 conditions across '
              '14 major crops, all without sending your photos to any external server.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.7,
              ),
            ),
          ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.05, end: 0),

          const SizedBox(height: 16),

          // Technology
          _Section(
            title: 'Technology Stack',
            child: Column(
              children: [
                _TechTile(icon: Icons.phone_android_rounded, label: 'Flutter', detail: 'Cross-platform UI'),
                _TechTile(icon: Icons.memory_rounded, label: 'TFLite (PlantVillage)', detail: 'On-device plant AI'),
                _TechTile(icon: Icons.bolt_rounded, label: 'Groq AI', detail: 'AI chat advisor'),
                _TechTile(icon: Icons.storage_rounded, label: 'Supabase', detail: 'Database & auth'),
                _TechTile(icon: Icons.lock_rounded, label: 'Firebase Auth', detail: 'User authentication'),
              ],
            ),
          ).animate(delay: 150.ms).fadeIn().slideY(begin: 0.05, end: 0),

          const SizedBox(height: 16),

          // Links
          _Section(
            title: 'Links',
            child: Column(
              children: [
                _LinkTile(
                  label: 'Privacy Policy',
                  icon: Icons.privacy_tip_outlined,
                  onTap: () => launchUrl(Uri.parse('https://phytolens.app/privacy')),
                ),
                const Divider(height: 1, color: Color(0x1A8FA98D)),
                _LinkTile(
                  label: 'Terms of Service',
                  icon: Icons.gavel_rounded,
                  onTap: () => launchUrl(Uri.parse('https://phytolens.app/terms')),
                ),
                const Divider(height: 1, color: Color(0x1A8FA98D)),
                _LinkTile(
                  label: 'Open Source Licenses',
                  icon: Icons.code_rounded,
                  onTap: () => showLicensePage(context: context),
                ),
              ],
            ),
          ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.05, end: 0),

          const SizedBox(height: 24),

          Center(
            child: Text(
              '© ${DateTime.now().year} PhytoLens. All rights reserved.',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TechTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String detail;
  const _TechTile({required this.icon, required this.label, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.primaryLight),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
          ),
          Text(detail,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _LinkTile({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
            ),
            const Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
