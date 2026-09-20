// lib/screens/history/scan_history_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../data/local_database.dart';
import '../../models/scan_result.dart';
import '../../theme/colors.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/shimmer_widget.dart';
import '../../widgets/health_score_ring.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../subscription/upgrade_screen.dart';
import 'scan_detail_screen.dart';

class ScanHistoryScreen extends StatefulWidget {
  const ScanHistoryScreen({super.key});

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  final _supabase = SupabaseService();
  final _localDb = LocalDatabase();
  bool _loading = true;
  List<ScanResult> _scans = [];
  List<ScanResult> _filtered = [];
  String _filter = 'all'; // 'all' | 'healthy' | 'diseased'
  String _search = '';
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _load() async {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    _sub?.cancel();

    // 1. Immediately load offline scans from SQLite local database
    try {
      final localScans = await _localDb.getUserScans(uid);
      if (mounted && localScans.isNotEmpty) {
        setState(() {
          _scans = localScans;
          _applyFilter();
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Local DB history load error: $e');
    }

    if (uid.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    // 2. Stream from Supabase if online, and cache new scans
    _sub = _supabase.streamUserScans(uid).listen((scans) async {
      if (mounted) {
        for (final s in scans) {
          await _localDb.upsertScan(s, synced: true);
        }
        setState(() {
          _scans = scans;
          _applyFilter();
          _loading = false;
        });
      }
    }, onError: (e) {
      debugPrint('Supabase stream error (offline): $e');
      if (mounted) setState(() => _loading = false);
    });
  }

  void _applyFilter() {
    _filtered = _scans.where((s) {
      final matchFilter = _filter == 'all' ||
          (_filter == 'healthy' && s.isHealthy) ||
          (_filter == 'diseased' && !s.isHealthy);
      final matchSearch = _search.isEmpty ||
          s.plantName.toLowerCase().contains(_search.toLowerCase()) ||
          s.diseaseName.toLowerCase().contains(_search.toLowerCase());
      return matchFilter && matchSearch;
    }).toList();
  }

  Future<void> _exportReport() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final user = await _supabase.getUser(uid);
    final isPaid = user?.isPro == true || user?.isFarm == true;

    if (!isPaid) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.lightSurface,
          title: const Text('Export Diagnostic Reports', style: TextStyle(color: AppColors.textPrimary)),
          content: const Text(
            'Bulk export and farm diagnostic logs are exclusive to Pro and Farm Pack plans. Upgrade to download your complete farm health records.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                );
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Upgrade Plan'),
            ),
          ],
        ),
      );
      return;
    }

    if (_scans.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No scan records to export yet.')),
        );
      }
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('PHYTOLENS CROP DIAGNOSTIC REPORT');
    buffer.writeln('Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
    buffer.writeln('Total Scans: ${_scans.length}');
    buffer.writeln('--------------------------------------------------');
    for (final s in _scans) {
      buffer.writeln('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(s.scannedAt)}');
      buffer.writeln('Crop: ${s.plantName}');
      buffer.writeln('Diagnosis: ${s.diseaseName}');
      buffer.writeln('Health Score: ${s.healthScore}/100');
      buffer.writeln('Status: ${s.isHealthy ? 'HEALTHY' : 'DISEASE DETECTED'}');
      if (s.remedy != null && s.remedy!.isNotEmpty) {
        buffer.writeln('Treatment: ${s.remedy}');
      }
      buffer.writeln('--------------------------------------------------');
    }

    await SharePlus.instance.share(
      ShareParams(
        text: buffer.toString(),
        subject: 'PhytoLens Farm Diagnostic History Report',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Scan History',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ).animate().fadeIn().slideY(begin: -0.1, end: 0),
                      const SizedBox(height: 4),
                      Text(
                        '${_scans.length} total scans',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ).animate(delay: 100.ms).fadeIn(),
                    ],
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: const Icon(Icons.file_download_outlined, color: AppColors.primaryLight, size: 20),
                    ),
                    tooltip: 'Export Diagnostic Report',
                    onPressed: _exportReport,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (v) {
                  setState(() { _search = v; _applyFilter(); });
                },
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search plants or diseases...',
                  prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ).animate(delay: 150.ms).fadeIn(),

            const SizedBox(height: 12),

            // Filter chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(label: 'All', value: 'all', selected: _filter, onSelected: _setFilter),
                    const SizedBox(width: 8),
                    _FilterChip(label: '✅ Healthy', value: 'healthy', selected: _filter, onSelected: _setFilter),
                    const SizedBox(width: 8),
                    _FilterChip(label: '⚠️ Diseased', value: 'diseased', selected: _filter, onSelected: _setFilter),
                  ],
                ),
              ),
            ).animate(delay: 200.ms).fadeIn(),

            const SizedBox(height: 12),

            // List
            Expanded(
              child: _loading
                  ? const ShimmerScanList(count: 6)
                  : _filtered.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          onRefresh: () async {
                            _load();
                          },
                          color: AppColors.primaryLight,
                          backgroundColor: AppColors.cardDark,
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 110),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) => _ScanHistoryTile(
                              scan: _filtered[i],
                              onDelete: () => _delete(_filtered[i]),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _setFilter(String v) {
    setState(() { _filter = v; _applyFilter(); });
  }

  Future<void> _delete(ScanResult scan) async {
    // Remove locally first for optimistic UI update
    setState(() {
      _scans.removeWhere((s) => s.id == scan.id);
      _applyFilter();
    });
    
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      await _localDb.deleteScan(scan.id);
      await _supabase.deleteScan(scan.id, userId: uid ?? scan.userId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Unable to delete scan. Please check your connection.',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.only(bottom: 90, left: 16, right: 16),
          ),
        );
        _load(); // Reload the data to restore the deleted item
      }
    }
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Icon(
              _search.isNotEmpty ? Icons.search_off_rounded : Icons.eco_outlined,
              size: 64,
              color: AppColors.primaryLight,
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(end: 1.05, duration: 3.seconds),
          const SizedBox(height: 24),
          Text(
            _search.isNotEmpty ? 'No results for "$_search"' : 'No Scans Yet',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _search.isNotEmpty 
                ? 'Try a different search term' 
                : 'Start scanning plants to build your history',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    ).animate().fadeIn();
  }
}

class _ScanHistoryTile extends StatelessWidget {
  final ScanResult scan;
  final VoidCallback onDelete;

  const _ScanHistoryTile({required this.scan, required this.onDelete});

  Future<bool?> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: const Text('Delete scan?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'This will permanently delete the ${scan.plantName} scan.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(scan.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await _confirmDelete(context);
      },
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ScanDetailScreen(scan: scan)),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTokens.radiusMD),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
            // Status icon / Thumbnail
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scan.isHealthy
                      ? AppColors.success.withValues(alpha: 0.3)
                      : AppColors.warning.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10.5),
                child: _buildThumbnailImage(scan),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scan.plantName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    scan.diseaseName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, yyyy · HH:mm').format(scan.scannedAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            HealthScoreRing(
              score: scan.healthScore,
              size: 44,
              strokeWidth: 4,
              animate: false,
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 22),
              onPressed: () async {
                final confirm = await _confirmDelete(context);
                if (confirm == true) onDelete();
              },
            ),
          ],
        ),
      ),
    ),
  ).animate(delay: const Duration(milliseconds: 50)).fadeIn().slideX(begin: 0.05, end: 0);
  }

  Widget _buildThumbnailImage(ScanResult scan) {
    if (scan.imageUrl == null || scan.imageUrl!.isEmpty) {
      return Center(
        child: Icon(
          scan.isHealthy ? Icons.eco_rounded : Icons.bug_report_rounded,
          color: scan.isHealthy ? AppColors.success : AppColors.warning,
          size: 26,
        ),
      );
    }

    final url = scan.imageUrl!;
    if (url.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: AppColors.surfaceDark,
          child: const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
          ),
        ),
        errorWidget: (_, __, ___) => Center(
          child: Icon(
            scan.isHealthy ? Icons.eco_rounded : Icons.bug_report_rounded,
            color: scan.isHealthy ? AppColors.success : AppColors.warning,
            size: 26,
          ),
        ),
      );
    }

    try {
      final file = File(url);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
            child: Icon(
              scan.isHealthy ? Icons.eco_rounded : Icons.bug_report_rounded,
              color: scan.isHealthy ? AppColors.success : AppColors.warning,
              size: 26,
            ),
          ),
        );
      }
    } catch (_) {}

    return Center(
      child: Icon(
        scan.isHealthy ? Icons.eco_rounded : Icons.bug_report_rounded,
        color: scan.isHealthy ? AppColors.success : AppColors.warning,
        size: 26,
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onSelected;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isSel = selected == value;
    return GestureDetector(
      onTap: () => onSelected(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSel ? AppColors.primary.withValues(alpha: 0.15) : Colors.white,
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          border: Border.all(
            color: isSel ? AppColors.primary : Colors.white.withValues(alpha: 0.08),
            width: isSel ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
            color: isSel ? AppColors.primaryLight : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
