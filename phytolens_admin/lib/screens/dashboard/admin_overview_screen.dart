// lib/screens/dashboard/admin_overview_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/constants.dart';
import '../../providers/admin_providers.dart';

class AdminOverviewScreen extends ConsumerWidget {
  const AdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(globalStatsProvider);
    final configAsync = ref.watch(appConfigStreamProvider);
    final scansAsync = ref.watch(scansStreamProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(globalStatsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'System Overview',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Live telemetry and platform performance',
                      style: TextStyle(
                        fontSize: 13,
                        color: AdminColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Refresh Stats',
                  icon: const Icon(Icons.refresh_rounded, color: AdminColors.primaryLight),
                  onPressed: () => ref.invalidate(globalStatsProvider),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // KPI Grid
            statsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AdminColors.primary),
                ),
              ),
              error: (err, _) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AdminColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Error loading stats: $err', style: const TextStyle(color: AdminColors.error)),
              ),
              data: (stats) {
                final totalUsers = stats['totalUsers'] ?? 0;
                final totalScans = stats['totalScans'] ?? 0;
                final activePro = stats['activePro'] ?? 0;
                final activeFarm = stats['activeFarm'] ?? 0;
                final todayScans = stats['todayScans'] ?? 0;

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final crossAxisCount = width > 1100 ? 5 : (width > 700 ? 3 : 2);

                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.4,
                      children: [
                        _StatCard(
                          title: 'Total Users',
                          value: '$totalUsers',
                          icon: Icons.people_alt_rounded,
                          color: AdminColors.primary,
                        ),
                        _StatCard(
                          title: 'Pro Users',
                          value: '$activePro',
                          icon: Icons.star_rounded,
                          color: AdminColors.warning,
                        ),
                        _StatCard(
                          title: 'Farm Pack Users',
                          value: '$activeFarm',
                          icon: Icons.agriculture_rounded,
                          color: AdminColors.accent,
                        ),
                        _StatCard(
                          title: 'Total Scans',
                          value: '$totalScans',
                          icon: Icons.qr_code_scanner_rounded,
                          color: AdminColors.secondary,
                        ),
                        _StatCard(
                          title: "Today's Scans",
                          value: '$todayScans',
                          icon: Icons.today_rounded,
                          color: Colors.pinkAccent,
                        ),
                      ],
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 28),

            // Live Config Status Card
            configAsync.when(
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
              data: (cfg) => Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AdminColors.darkSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AdminColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.tune_rounded, color: AdminColors.primaryLight, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Active System Limits & Pricing',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (cfg.maintenanceMode ? AdminColors.error : AdminColors.primary).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (cfg.maintenanceMode ? AdminColors.error : AdminColors.primary).withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            cfg.maintenanceMode ? 'MAINTENANCE MODE' : 'SYSTEM HEALTHY',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: cfg.maintenanceMode ? AdminColors.error : AdminColors.primaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 24,
                      runSpacing: 12,
                      children: [
                        _ConfigChip(label: 'Trial Duration', value: '${cfg.freeTierDays} Days'),
                        _ConfigChip(label: 'Free Daily Scans', value: '${cfg.freeDailyScanLimit}/day'),
                        _ConfigChip(label: 'Pro Daily Scans', value: '${cfg.proDailyScanLimit}/day'),
                        _ConfigChip(
                          label: 'Farm Daily Scans',
                          value: cfg.farmDailyScanLimit <= 0 ? 'Unlimited' : '${cfg.farmDailyScanLimit}/day',
                        ),
                        _ConfigChip(label: 'Pro Monthly Price', value: '₹${cfg.proMonthlyPrice}'),
                        _ConfigChip(label: 'Farm Monthly Price', value: '₹${cfg.farmMonthlyPrice}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Recent Scans Mini Feed
            const Text(
              'Recent Plant Scans Feed',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),

            scansAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AdminColors.primary)),
              error: (e, _) => Text('Error loading scans: $e', style: const TextStyle(color: AdminColors.error)),
              data: (scans) {
                if (scans.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AdminColors.darkSurface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text('No scans recorded yet.', style: TextStyle(color: AdminColors.textSecondary)),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: scans.take(5).length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final s = scans[i];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AdminColors.darkSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AdminColors.border.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: s.isHealthy ? AdminColors.primary.withOpacity(0.15) : AdminColors.warning.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              s.isHealthy ? Icons.eco_rounded : Icons.coronavirus_rounded,
                              color: s.isHealthy ? AdminColors.primaryLight : AdminColors.warning,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.plantName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
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
                                '${s.scannedAt.hour.toString().padLeft(2, '0')}:${s.scannedAt.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontSize: 11, color: AdminColors.textMuted),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: AdminColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfigChip extends StatelessWidget {
  final String label;
  final String value;

  const _ConfigChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AdminColors.textMuted)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ],
    );
  }
}
