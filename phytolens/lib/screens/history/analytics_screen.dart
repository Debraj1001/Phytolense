// lib/screens/history/analytics_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/supabase_service.dart';
import '../../models/scan_result.dart';
import '../../theme/colors.dart';
import '../../theme/design_tokens.dart';
import '../subscription/upgrade_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _supabase = SupabaseService();
  bool _loading = true;
  bool _isPaid = false;
  List<ScanResult> _scans = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final user = await _supabase.getUser(uid);
      final scans = await _supabase.getUserScans(uid, limit: 100);

      if (mounted) {
        setState(() {
          _isPaid = user?.isPro == true || user?.isFarm == true;
          _scans = scans;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: AppColors.lightSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Crop Health Analytics',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primaryLight,
              backgroundColor: Colors.white,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_isPaid)
                      _buildLockedAnalyticsHero()
                    else
                      _buildUnlockedAnalytics(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLockedAnalyticsHero() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTokens.radiusLG),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.insights_rounded, color: AppColors.primaryLight, size: 36),
              ),
              const SizedBox(height: 16),
              const Text(
                'Farm & Crop Analytics (Pro & Farm)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Unlock deep disease recurrence graphs, seasonal health indices, and vulnerability breakdowns to maximize crop yields.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                    ).then((_) => _loadData());
                  },
                  icon: const Icon(Icons.lock_open_rounded, size: 18),
                  label: const Text('Unlock Analytics for ₹49', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusPill)),
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(),

        const SizedBox(height: 24),

        // Blurred Preview Sample
        Opacity(
          opacity: 0.35,
          child: IgnorePointer(
            child: _buildSampleCharts(),
          ),
        ),
      ],
    );
  }

  Widget _buildUnlockedAnalytics() {
    final healthyCount = _scans.where((s) => s.isHealthy).length;
    final diseasedCount = _scans.length - healthyCount;
    final avgHealth = _scans.isEmpty
        ? 85
        : (_scans.fold<int>(0, (sum, s) => sum + s.healthScore) / _scans.length).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary Cards Row
        Row(
          children: [
            Expanded(
              child: _buildStatCard('Health Average', '$avgHealth%', Icons.favorite_rounded, AppColors.healthGood),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard('Healthy Scans', '$healthyCount', Icons.check_circle_rounded, AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard('Issues Detected', '$diseasedCount', Icons.warning_rounded, AppColors.warning),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Health Score Trend Chart
        const Text(
          'Crop Health Score Trend',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        Container(
          height: 200,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTokens.radiusMD),
            border: Border.all(color: AppColors.lightBorder),
          ),
          child: _scans.isEmpty
              ? const Center(child: Text('Scan more plants to populate trend charts', style: TextStyle(color: AppColors.textMuted)))
              : LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: _scans.take(12).toList().asMap().entries.map((e) {
                          return FlSpot(e.key.toDouble(), e.value.healthScore.toDouble());
                        }).toList(),
                        isCurved: true,
                        color: AppColors.primaryLight,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                    ],
                  ),
                ),
        ),

        const SizedBox(height: 24),

        // Disease Breakdown
        const Text(
          'Condition & Disease Distribution',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTokens.radiusMD),
            border: Border.all(color: AppColors.lightBorder),
          ),
          child: Column(
            children: [
              _buildDistributionRow('Healthy Crops', healthyCount, _scans.length, AppColors.healthGood),
              const SizedBox(height: 12),
              _buildDistributionRow('Diseased / Stressed', diseasedCount, _scans.length, AppColors.warning),
            ],
          ),
        ),

        const SizedBox(height: 70),
      ],
    );
  }

  Widget _buildSampleCharts() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTokens.radiusMD),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Weekly Crop Health Score Index', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 70),
                      FlSpot(1, 82),
                      FlSpot(2, 78),
                      FlSpot(3, 90),
                      FlSpot(4, 88),
                      FlSpot(5, 95),
                    ],
                    isCurved: true,
                    color: AppColors.primaryLight,
                    barWidth: 3,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTokens.radiusMD),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildDistributionRow(String title, int count, int total, Color color) {
    final pct = total > 0 ? (count / total) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            Text('$count scans (${(pct * 100).round()}%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: AppColors.lightCardElevated,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
