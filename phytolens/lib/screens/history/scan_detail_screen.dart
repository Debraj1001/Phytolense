// lib/screens/history/scan_detail_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/scan_result.dart';
import '../../theme/colors.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/health_score_ring.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_provider.dart';
import '../../providers/app_config_provider.dart';
import '../../services/trial_service.dart';
import '../subscription/upgrade_screen.dart';
import '../ai/chatbot_screen.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ScanDetailScreen extends ConsumerStatefulWidget {
  final ScanResult scan;

  const ScanDetailScreen({super.key, required this.scan});

  @override
  ConsumerState<ScanDetailScreen> createState() => _ScanDetailScreenState();
}

class _ScanDetailScreenState extends ConsumerState<ScanDetailScreen> {
  late final String _advice;

  @override
  void initState() {
    super.initState();
    // Use the exact initial summary/report generated at the very first scan time
    if (widget.scan.remedy != null && widget.scan.remedy!.trim().isNotEmpty) {
      _advice = widget.scan.remedy!;
    } else if (widget.scan.isHealthy) {
      _advice = '✅ Your ${widget.scan.plantName} was diagnosed as Healthy (${widget.scan.healthScore}/100). Keep up regular watering, adequate sunlight, and routine pest inspections.';
    } else if (widget.scan.isNonPlant) {
      _advice = '📷 Non-plant subject detected (${widget.scan.plantName}). PhytoLens AI recognized this object. Point your camera at a plant leaf for health analysis.';
    } else {
      _advice = 'Diagnosed: ${widget.scan.diseaseName} on ${widget.scan.plantName} (Health score: ${widget.scan.healthScore}/100).\n\nTap "Ask AI" below to chat with PhytoLens AI and get custom treatment instructions, spray schedules, and organic remedies.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: CustomScrollView(
        slivers: [
          // App Bar with Image
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.lightBg,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: widget.scan.id.isNotEmpty ? widget.scan.id : 'scan_detail_hero',
                child: _buildHeaderImage(),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Time & Status Header
                Text(
                  DateFormat('MMMM d, yyyy • h:mm a').format(widget.scan.scannedAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ).animate().fadeIn(),
                
                const SizedBox(height: 12),

                // Health score + plant info
                _buildResultCard().animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),

                const SizedBox(height: 16),

                // AI Advice / Remedy Card (Saved Summary)
                _buildAdviceCard().animate(delay: 150.ms).fadeIn().slideY(begin: 0.1, end: 0),

                const SizedBox(height: 16),

                // Actions: Ask AI & Share
                _buildActions(context).animate(delay: 250.ms).fadeIn(),

                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderImage() {
    final url = widget.scan.imageUrl;
    if (url != null && url.isNotEmpty) {
      if (url.startsWith('http')) {
        return CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            color: Colors.white,
            child: const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
          ),
          errorWidget: (_, __, ___) => _buildPlaceholder(),
        );
      }
      final file = File(url);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.scan.isNonPlant ? Icons.camera_alt_outlined : Icons.eco_rounded,
              size: 54,
              color: AppColors.primaryLight,
            ),
            const SizedBox(height: 8),
            Text(
              widget.scan.plantName,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Row(
        children: [
          HealthScoreRing(
            score: widget.scan.healthScore,
            size: 90,
            strokeWidth: 8,
            animate: false,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.scan.plantName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      widget.scan.isNonPlant ? '📷' : widget.scan.statusEmoji,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.scan.diseaseName,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Confidence: ${(widget.scan.diseaseConfidence * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdviceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.smart_toy_outlined, color: AppColors.secondary, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'AI Diagnosis & Health Summary',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          MarkdownBody(
            data: _advice,
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
              strong: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
              listBullet: const TextStyle(
                fontSize: 14,
                color: AppColors.primaryDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final config = ref.watch(appConfigProvider).value ?? const AppConfig();
    final trialInfo = TrialService.getTrialInfo(user, trialDays: config.trialDays);
    final isPaid = user?.isPaidActive ?? false;
    final isLocked = !isPaid && trialInfo.isExpired;

    final initialMsg = widget.scan.isHealthy
        ? 'Tell me how to keep my ${widget.scan.plantName} healthy, productive, and growing well.'
        : 'Tell me more about ${widget.scan.diseaseName} on ${widget.scan.plantName}. Health score: ${widget.scan.healthScore}/100. Confidence: ${(widget.scan.diseaseConfidence * 100).round()}%. What are the best treatments, remedies, and prevention tips?';

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: Icon(isLocked ? Icons.lock_outline_rounded : Icons.chat_bubble_outline, size: 18),
            label: Text(isLocked ? 'Ask AI (Locked)' : 'Ask AI'),
            onPressed: () {
              if (isLocked) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatbotScreen(initialMessage: initialMsg),
                  ),
                );
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: isLocked ? AppColors.error : AppColors.primaryDark,
              side: BorderSide(color: isLocked ? AppColors.error : AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            icon: const Icon(Icons.share_outlined, size: 18),
            label: const Text('Share'),
            onPressed: () {
              final text = 'I scanned a ${widget.scan.plantName} with PhytoLens! 🌱\n\n'
                  'Result: ${widget.scan.diseaseName}\n'
                  'Health Score: ${(widget.scan.healthScore * 100).round()}%\n\n'
                  'Get PhytoLens: https://phytolens.app';
              // ignore: deprecated_member_use
              Share.share(text, subject: 'My Plant Scan Result');
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusPill),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
