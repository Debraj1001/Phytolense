import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/plant.dart';
import '../../models/scan_result.dart';
import '../../services/ml_service.dart';
import '../../services/supabase_service.dart';
import '../../services/scan_limiter.dart';
import '../../services/gamification_service.dart';
import '../../services/sync_service.dart';
import '../../services/permission_service.dart';
import '../../theme/colors.dart';
import '../scanner/result_screen.dart';
import '../history/scan_detail_screen.dart';
import '../subscription/upgrade_screen.dart';

class PlantDetailScreen extends StatefulWidget {
  final Plant plant;
  const PlantDetailScreen({super.key, required this.plant});

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen> {
  final _supabase = SupabaseService();
  final _picker = ImagePicker();
  final _ml = MLService();
  final _limiter = ScanLimiter();
  final _gamification = GamificationService();
  final _syncService = SyncService();

  late Plant _currentPlant;
  List<ScanResult> _plantScans = [];
  bool _isLoading = true;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _currentPlant = widget.plant;
    _ml.initialize();
    _loadScans();
  }

  Future<void> _loadScans() async {
    setState(() => _isLoading = true);
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      if (_currentPlant.id.isNotEmpty) {
        final plantScans = await _supabase.getPlantScans(_currentPlant.id);
        if (plantScans.isNotEmpty) {
          _plantScans = plantScans;
        } else {
          final allScans = await _supabase.getUserScans(uid);
          _plantScans = allScans.where((s) =>
              s.plantId == _currentPlant.id ||
              s.plantName.toLowerCase() == _currentPlant.type.toLowerCase() ||
              s.plantName.toLowerCase() == _currentPlant.name.toLowerCase()).toList();
        }
      } else {
        final allScans = await _supabase.getUserScans(uid);
        _plantScans = allScans.where((s) =>
            s.plantName.toLowerCase() == _currentPlant.type.toLowerCase() ||
            s.plantName.toLowerCase() == _currentPlant.name.toLowerCase()).toList();
      }
    } catch (e) {
      debugPrint('Error loading scans: $e');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deletePlant() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Plant?', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to remove ${_currentPlant.name} from your garden?', style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Delete', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _supabase.deletePlant(_currentPlant.id);
      if (mounted) {
        Navigator.pop(context); // Go back to garden
      }
    }
  }

  Future<void> _scanThisPlant(ImageSource source) async {
    if (source == ImageSource.camera) {
      final hasPermission = await PermissionService().requestCameraPermission(context);
      if (!hasPermission) return;
    } else {
      final hasPermission = await PermissionService().requestStoragePermission(context);
      if (!hasPermission) return;
    }

    final limit = await _limiter.checkScanLimit();
    if (!limit.canScan) {
      _showLimitDialog();
      return;
    }

    final xFile = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1024);
    if (xFile == null) return;

    final file = File(xFile.path);
    setState(() => _isScanning = true);

    try {
      final mlResult = await _ml.classifyImage(file);
      final uid = Supabase.instance.client.auth.currentUser!.id;

      final scanResult = ScanResult(
        id: '',
        userId: uid,
        plantId: _currentPlant.id,
        diseaseName: mlResult.diseaseName,
        diseaseConfidence: mlResult.confidence,
        plantName: mlResult.plantName,
        healthScore: mlResult.healthScore,
        scannedAt: DateTime.now(),
      );

      ScanResult saved = scanResult;
      PostScanReward? reward;

      bool isOnline = await _syncService.isOnline();
      if (isOnline) {
        saved = await _supabase.saveScan(scanResult);
        reward = await _gamification.processScanReward(uid);
      } else {
        await _syncService.saveScanOffline(scanResult);
        await _limiter.incrementLocalScanCount();
      }

      // Update the plant in garden
      final updates = {
        'latest_health_score': mlResult.healthScore,
        'latest_disease': mlResult.diseaseName,
        'last_scanned_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (isOnline) {
        await _supabase.updatePlant(_currentPlant.id, updates);
      }

      setState(() {
        _currentPlant = Plant(
          id: _currentPlant.id,
          userId: _currentPlant.userId,
          name: _currentPlant.name,
          type: _currentPlant.type,
          imageUrl: _currentPlant.imageUrl,
          latestHealthScore: mlResult.healthScore,
          latestDisease: mlResult.diseaseName,
          addedAt: _currentPlant.addedAt,
          lastScannedAt: DateTime.now(),
          healthHistory: _currentPlant.healthHistory,
        );
        _plantScans.insert(0, saved);
        _isScanning = false;
      });

      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              scan: saved,
              imageFile: file,
              reward: reward,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isScanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Scan could not be completed. Please ensure good lighting and try again.',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          ),
        );
      }
    }
  }

  void _showLimitDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.lightBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text('🥀', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              const Text('Scan Limit Reached', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 10),
              const Text('Upgrade to Pro for unlimited scans and advanced plant diagnostics.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const UpgradeScreen()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Upgrade Now', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showScanOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.lightBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.mintGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.primaryGreen),
                ),
                title: const Text('Take a Photo', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _scanThisPlant(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.mintGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.primaryGreen),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _scanThisPlant(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(_currentPlant.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            onPressed: _deletePlant,
          ),
        ],
      ),
      body: _isScanning 
        ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
        : RefreshIndicator(
            onRefresh: _loadScans,
            color: AppColors.primaryGreen,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Info
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.lightBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.sageGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _currentPlant.imageUrl != null && _currentPlant.imageUrl!.startsWith('http')
                              ? Image.network(
                                  _currentPlant.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Text('🌱', style: TextStyle(fontSize: 36)),
                                  ),
                                )
                              : const Center(
                                  child: Text('🌱', style: TextStyle(fontSize: 36)),
                                ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentPlant.type,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    _currentPlant.statusEmoji,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _currentPlant.latestDisease ?? 'Healthy',
                                      style: TextStyle(
                                        color: _currentPlant.latestHealthScore >= 90 ? AppColors.primaryGreen : AppColors.error,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_currentPlant.lastScannedAt != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Last scanned: ${timeago.format(_currentPlant.lastScannedAt!)}',
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                ),
                              ]
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn().slideY(begin: 0.2),

                  const SizedBox(height: 24),

                  // Scan CTA
                  ElevatedButton.icon(
                    onPressed: _showScanOptions,
                    icon: const Icon(Icons.document_scanner_rounded, size: 20),
                    label: const Text('Scan This Plant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ).animate().fadeIn(delay: 100.ms).scale(),

                  const SizedBox(height: 32),
                  const Text('Scan History', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  if (_isLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppColors.primaryGreen)))
                  else if (_plantScans.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.lightBorder),
                      ),
                      child: Column(
                        children: [
                          const Text('🌿', style: TextStyle(fontSize: 36)),
                          const SizedBox(height: 12),
                          const Text(
                            'No scans recorded yet',
                            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap "Scan This Plant" above to log health checks and track progress.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.8), fontSize: 13, height: 1.4),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _plantScans.length,
                      itemBuilder: (context, index) {
                        final scan = _plantScans[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.lightBorder),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: scan.isHealthy 
                                    ? AppColors.mintGreen.withValues(alpha: 0.2)
                                    : AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(scan.statusEmoji, style: const TextStyle(fontSize: 24)),
                              ),
                            ),
                            title: Text(
                              scan.diseaseName,
                              style: TextStyle(
                                color: scan.isHealthy ? AppColors.primaryGreen : AppColors.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                timeago.format(scan.scannedAt),
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: scan.isHealthy 
                                    ? AppColors.mintGreen.withValues(alpha: 0.2)
                                    : AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${scan.healthScore}%',
                                style: TextStyle(
                                  color: scan.isHealthy ? AppColors.primaryGreen : AppColors.error,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ScanDetailScreen(scan: scan),
                                ),
                              );
                            },
                          ),
                        ).animate().fadeIn(delay: Duration(milliseconds: 100 + (index * 50)));
                      },
                    ),
                ],
              ),
            ),
          ),
    );
  }
}
