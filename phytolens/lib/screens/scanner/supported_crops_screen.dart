// lib/screens/scanner/supported_crops_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../data/crops_dataset.dart';
import '../../theme/colors.dart';
import 'dart:ui';

class SupportedCropsScreen extends StatelessWidget {
  const SupportedCropsScreen({super.key});

  void _showConditions(BuildContext context, CropData crop) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ConditionsBottomSheet(crop: crop),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        elevation: 0,
        title: const Text(
          'Crop Explorer',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: AppColors.primaryLight),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Browse 24 supported crops. Tap a crop to see offline details and what conditions it can detect.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().slideY(begin: -0.1, end: 0),

          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.85,
              ),
              itemCount: cropsDataset.length,
              itemBuilder: (context, index) {
                final crop = cropsDataset[index];
                return _CropCard(
                  crop: crop,
                  onTap: () => _showConditions(context, crop),
                ).animate().fadeIn(delay: (index * 45).ms).scale(
                  begin: const Offset(0.92, 0.92),
                  end: const Offset(1, 1),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CropCard extends StatelessWidget {
  final CropData crop;
  final VoidCallback onTap;

  const _CropCard({required this.crop, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              // Image section
              Expanded(
                flex: 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: crop.imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        child: Center(
                          child: Text(crop.emoji, style: const TextStyle(fontSize: 52)),
                        ),
                      ),
                      placeholder: (_, __) => Container(
                        color: AppColors.cardDarker,
                        child: Center(
                          child: Text(crop.emoji, style: const TextStyle(fontSize: 40)),
                        ),
                      ),
                    ),
                    // Gradient overlay at bottom
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              AppColors.cardDark.withValues(alpha: 0.7),
                            ],
                            stops: const [0.5, 1],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Info section
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        crop.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.biotech_rounded, size: 10, color: AppColors.primaryLight),
                            const SizedBox(width: 4),
                            Text(
                              '${crop.commonDiseases.length} conditions',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConditionsBottomSheet extends StatelessWidget {
  final CropData crop;

  const _ConditionsBottomSheet({required this.crop});

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardDark.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(
            color: AppColors.textMuted.withValues(alpha: 0.1),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Crop header with image
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: crop.imageUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 56,
                        height: 56,
                        color: AppColors.primary.withValues(alpha: 0.1),
                        child: Center(child: Text(crop.emoji, style: const TextStyle(fontSize: 28))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        crop.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${crop.commonDiseases.length} detectable conditions',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Text(
                crop.description,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),

              const SizedBox(height: 20),
              const Divider(color: Color(0x1A8FA98D)),
              const SizedBox(height: 8),

              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: crop.commonDiseases.length,
                  separatorBuilder: (_, __) => const Divider(color: Color(0x0D8FA98D), height: 1),
                  itemBuilder: (context, index) {
                    final condition = crop.commonDiseases[index];
                    final isHealthy = condition.toLowerCase() == 'healthy';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isHealthy
                              ? AppColors.healthGood.withValues(alpha: 0.1)
                              : AppColors.healthCritical.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isHealthy ? Icons.eco : Icons.coronavirus_outlined,
                          color: isHealthy ? AppColors.healthGood : AppColors.healthCritical,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        condition,
                        style: TextStyle(
                          color: isHealthy ? AppColors.healthGood : AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: isHealthy ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ).animate().fadeIn(delay: (index * 40).ms).slideX(begin: 0.05, end: 0);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
