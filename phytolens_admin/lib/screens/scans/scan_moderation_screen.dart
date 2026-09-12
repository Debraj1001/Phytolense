// lib/screens/scans/scan_moderation_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../config/constants.dart';
import '../../models/scan_item.dart';
import '../../providers/admin_providers.dart';

class ScanModerationScreen extends ConsumerWidget {
  const ScanModerationScreen({super.key});

  void _showScanDetail(BuildContext context, WidgetRef ref, ScanItem scan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AdminColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) {
            return SingleChildScrollView(
              controller: controller,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
                  if (scan.imageUrl != null && scan.imageUrl!.isNotEmpty && scan.imageUrl!.startsWith('http'))
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: scan.imageUrl!,
                        height: 220,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          height: 120,
                          color: AdminColors.darkBg,
                          child: const Center(
                            child: Icon(Icons.broken_image_rounded, color: AdminColors.textMuted),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: AdminColors.darkBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Icon(Icons.local_florist_rounded, size: 40, color: AdminColors.primaryLight),
                      ),
                    ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              scan.plantName,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              scan.diseaseName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: scan.isHealthy ? AdminColors.primaryLight : AdminColors.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: (scan.healthScore >= 70 ? AdminColors.primary : AdminColors.warning).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${scan.healthScore}% Health',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: scan.healthScore >= 70 ? AdminColors.primaryLight : AdminColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Text('User ID: ${scan.userId}', style: const TextStyle(fontSize: 12, color: AdminColors.textMuted)),
                  Text(
                    'Scanned at: ${DateFormat('dd MMM yyyy, hh:mm a').format(scan.scannedAt)}',
                    style: const TextStyle(fontSize: 12, color: AdminColors.textMuted),
                  ),

                  const SizedBox(height: 20),

                  if (scan.remedy != null && scan.remedy!.isNotEmpty) ...[
                    const Text('Diagnosis / Remedy Report:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AdminColors.darkBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AdminColors.border),
                      ),
                      child: Text(
                        scan.remedy!,
                        style: const TextStyle(fontSize: 13, color: AdminColors.textSecondary, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Delete Scan Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminColors.error.withOpacity(0.8),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.delete_forever_rounded, size: 18),
                      label: const Text('Delete / Moderate This Scan'),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await ref.read(adminServiceProvider).deleteScan(scan.id);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scansAsync = ref.watch(scansStreamProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live Scan Feed & Moderation',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Real-time stream of crop diagnostics submitted by farmers',
            style: TextStyle(fontSize: 13, color: AdminColors.textSecondary),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: scansAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AdminColors.primary)),
              error: (e, _) => Center(child: Text('Error loading scans: $e', style: const TextStyle(color: AdminColors.error))),
              data: (scans) {
                if (scans.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: AdminColors.darkSurface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text('No scans recorded yet.', style: TextStyle(color: AdminColors.textSecondary)),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: scans.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final s = scans[i];
                    return InkWell(
                      onTap: () => _showScanDetail(context, ref, s),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AdminColors.darkSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AdminColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: s.isHealthy ? AdminColors.primary.withOpacity(0.15) : AdminColors.warning.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                s.isHealthy ? Icons.eco_rounded : Icons.coronavirus_rounded,
                                color: s.isHealthy ? AdminColors.primaryLight : AdminColors.warning,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.plantName,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    s.diseaseName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: s.isHealthy ? AdminColors.primaryLight : AdminColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${s.healthScore}% Health',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: s.healthScore >= 70 ? AdminColors.primaryLight : AdminColors.warning,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat('dd MMM, hh:mm a').format(s.scannedAt),
                                  style: const TextStyle(fontSize: 11, color: AdminColors.textMuted),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right_rounded, color: AdminColors.textMuted),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
