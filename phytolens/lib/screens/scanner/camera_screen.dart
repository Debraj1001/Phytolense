// lib/screens/scanner/camera_screen.dart

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/scan_limit_provider.dart';
import '../../services/ml_service.dart';
import '../../services/groq_service.dart';
import '../../services/gemini_service.dart';
import '../../services/plantnet_service.dart';
import '../../services/scan_limiter.dart';
import '../../services/sync_service.dart';
import '../../services/permission_service.dart';
import '../../data/local_database.dart';
import '../../models/scan_result.dart';
import '../../theme/colors.dart';

import 'dart:async';
import '../../providers/app_config_provider.dart';
import '../../providers/ai_settings_provider.dart';
import '../subscription/upgrade_screen.dart';
import '../../widgets/glass_button.dart';
import '../subscription/trial_activation_screen.dart';
import 'result_screen.dart';
import '../home/home_screen.dart';
import 'supported_crops_screen.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/emergency_doctor_pass_sheet.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> with WidgetsBindingObserver {
  final _picker = ImagePicker();
  final _ml = MLService();
  final _groq = GroqService();
  final _gemini = GeminiService();
  final _plantNet = PlantNetService();
  final _limiter = ScanLimiter();
  final _syncService = SyncService();
  final _localDb = LocalDatabase();

  bool _analyzing = false;
  File? _selectedImage;
  ScanLimitResult? _limitResult;
  String _scanStage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ml.initialize();
    _checkConnectivity();
    _refreshLimit();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ml.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshLimit();
    }
  }

  Future<void> _checkConnectivity() async {
    // Only check online status internally if needed, removed UI bindings.
  }

  void _openSupportedCrops() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SupportedCropsScreen()),
    );
  }

  Future<void> _refreshLimit() async {
    final limit = await _limiter.checkScanLimit();
    if (mounted) setState(() => _limitResult = limit);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3-TIER IDENTIFICATION PIPELINE
  //
  //  Tier 1: TFLite (offline, instant, 14 crops / 38 diseases)
  //          → if confidence ≥ 0.70 → DONE
  //
  //  Tier 2: Pl@ntNet API (online, 82,000+ species, free 500/day)
  //          → if identified → DONE
  //
  //  Tier 3: Groq LLM Vision Fallback (non-plant object naming only)
  //          → names "Human Hand", "Laptop", etc.
  //
  //  After identification: Groq generates TIER-AWARE disease report
  //  (Free=basic, Pro=detailed, Farm=full)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _pickImage(ImageSource source) async {
    // Request runtime camera/storage permission
    if (source == ImageSource.camera) {
      final hasPermission = await PermissionService().requestCameraPermission(context);
      if (!hasPermission) return;
    } else {
      final hasPermission = await PermissionService().requestStoragePermission(context);
      if (!hasPermission) return;
    }

    // Check scan limit
    final limit = await _limiter.checkScanLimit();
    if (!limit.canScan) {
      _showLimitDialog(limit);
      return;
    }

    final xFile = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (xFile == null) return;

    final file = File(xFile.path);
    setState(() {
      _selectedImage = file;
      _analyzing = true;
      _scanStage = 'Analyzing leaf...';
    });

    try {
      // ── TIER 1: On-device TFLite (instant, offline) ────────────────────
      final mlResult = await _ml.classifyImage(file);

      String plantName = mlResult.plantName;
      String diseaseName = mlResult.diseaseName;
      double confidence = mlResult.confidence;
      int healthScore = mlResult.healthScore;
      String? remedy;
      String aiSource = 'cloud'; // Track where AI analysis came from
      bool identifiedByPlantNet = false;

      bool isOnline = await _syncService.isOnline();
      final isAiEngineEnabled = ref.read(aiEngineProvider);
      final String userTier = limit.tier;

      if (mounted) setState(() => _scanStage = 'Identifying plant...');

      // ── TIER 2: Pl@ntNet API (online botanical identification) ─────────
      if (isOnline && isAiEngineEnabled && (confidence < 0.70 || plantName == 'Unknown Plant' || diseaseName == 'Unrecognized')) {
        try {
          final plantNetResult = await _plantNet.identifyPlant(file);

          if (plantNetResult != null && plantNetResult.confidence >= 0.15) {
            plantName = plantNetResult.commonName;
            confidence = plantNetResult.confidence;
            identifiedByPlantNet = true;
            diseaseName = 'Identified Species';
            healthScore = 85;

            // If TFLite detected a disease with moderate confidence, keep it
            if (mlResult.confidence >= 0.40 && !mlResult.isUnknown && !mlResult.isHealthy) {
              diseaseName = mlResult.diseaseName;
              healthScore = mlResult.healthScore;
            }
          }
        } catch (e) {
          debugPrint('PlantNet identification error: $e');
        }
      }

      // ── TIER 3: Fast Gemini Vision Fallback (non-plant objects & edge cases) ──
      if (isOnline && isAiEngineEnabled && !identifiedByPlantNet &&
          (confidence < 0.70 || plantName == 'Unknown Plant' || diseaseName == 'Unrecognized')) {
        try {
          final visionData = await _gemini.identifyImageFile(file);

          final isPlant = visionData['isPlant'] == true;
          final objName = visionData['objectName']?.toString() ?? 'Unrecognized Item';
          final objDesc = visionData['description']?.toString() ?? '';

          if (!isPlant) {
            plantName = objName;
            diseaseName = 'Object (Non-Plant)';
            confidence = 0.95;
            healthScore = 100;
            remedy = '$objDesc\n\nPhytoLens specializes in plant leaf diagnostics. '
                'Point your camera at a plant or flower for health analysis.';
          } else {
            plantName = objName;
            diseaseName = 'Identified Plant';
            confidence = 0.85;
            healthScore = 85;
            remedy = objDesc;
          }
        } catch (e) {
          debugPrint('Gemini vision error: $e');
        }
      }

      // ── Generate tier-aware disease report via Groq (TEXT only) ────────
      if (diseaseName != 'Object (Non-Plant)' &&
          plantName != 'Unknown Plant' && plantName != 'Unrecognized Item') {
        if (mounted) setState(() => _scanStage = 'Generating report...');
        try {
          if (isOnline && isAiEngineEnabled) {
            remedy = await _groq.getTieredAdvice(
              tier: userTier,
              plantName: plantName,
              diseaseName: diseaseName,
              healthScore: healthScore,
            );
          } else {
            throw Exception(isOnline ? 'AI Cloud Engine Disabled by User' : 'Offline mode active');
          }
        } catch (e) {
          debugPrint('Online report skipped/failed: $e');
          aiSource = 'offline';
          if (mlResult.treatmentData != null) {
            final td = mlResult.treatmentData!;
            remedy = "### Offline Diagnosis: ${td['status']}\n\n"
                     "**Severity:** ${td['severity']}\n"
                     "**Immediate Action:** ${td['action']}\n\n"
                     "**Bio-Organic Remedy:** ${td['bio_remedy']}\n\n"
                     "**Chemical Alternative:** ${td['chemical_remedy']}";
          }
        }
      }

      // Ensure remedy is never null
      remedy ??= 'Scan complete. $plantName detected with $diseaseName. '
          'Connect to the internet for a detailed AI treatment report.';

      // ── Prepare ScanResult (User will choose whether to save) ────────
      final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
      final scanResult = ScanResult(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        userId: uid,
        diseaseName: diseaseName,
        diseaseConfidence: confidence,
        plantName: plantName,
        healthScore: healthScore,
        remedy: remedy,
        scannedAt: DateTime.now(),
        imageUrl: file.path,
        aiSource: aiSource,
      );

      // ── Save to local DB immediately (offline-first, marked unsynced until saved) ──
      await _localDb.upsertScan(scanResult, synced: false);

      if (mounted) {
        setState(() => _analyzing = false);
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              scan: scanResult,
              imageFile: file,
              userTier: userTier,
              isSaved: false,
            ),
          ),
        );
        _refreshLimit();
        ref.read(scanLimitProvider.notifier).refreshLimit();
        if (mounted) {
          setState(() {
            _selectedImage = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _analyzing = false);
        final errStr = e.toString();
        final String friendlyMessage;
        final bool isWarning;
        if (errStr.contains('NOT_A_PLANT')) {
          friendlyMessage = 'No plant leaf detected. Please take a clear photo of the leaf.';
          isWarning = true;
        } else if (errStr.contains('SocketException') || errStr.contains('network') || errStr.contains('Failed host lookup')) {
          friendlyMessage = 'Network connection issue. Please check your internet and try again.';
          isWarning = false;
        } else if (errStr.contains('limit') || errStr.contains('quota')) {
          friendlyMessage = 'Daily scan limit reached. Please check back tomorrow.';
          isWarning = true;
        } else {
          friendlyMessage = 'Unable to analyze image. Please try again with clear lighting.';
          isWarning = false;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isWarning ? Icons.info_outline_rounded : Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    friendlyMessage,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: isWarning ? AppColors.warning : AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showLimitDialog(ScanLimitResult limit) {
    final cfg = ref.read(appConfigProvider).value ?? const AppConfig();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(limit.isNotStarted ? '🌱' : (limit.isExpired ? '🥀' : '⏳'), style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 16),
            Text(
              limit.isExpired
                  ? 'Free Trial Concluded'
                  : (limit.isNotStarted
                      ? (cfg.trialPrice <= 0 ? 'Start ${cfg.trialDays}-Day Free Trial' : 'Start ₹${cfg.trialPrice.toInt()} Trial')
                      : 'Daily Scan Limit Reached'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: limit.isExpired ? AppColors.error : AppColors.warning,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              limit.isExpired
                  ? 'Your ${cfg.trialDays}-day Free Trial has ended. There is no permanent free tier. Upgrade to Pro (${cfg.proPrice}/mo) or Farm Pack (${cfg.farmPrice}/mo) to continue scanning plants.'
                  : (limit.isNotStarted
                      ? 'Activate your ${cfg.trialDays}-Day Trial (${cfg.trialPrice <= 0 ? "Free" : "₹${cfg.trialPrice.toInt()}"}) to enjoy ${limit.limit} AI leaf scans per day, remedies, and treatment guides.'
                      : 'You\'ve reached your daily limit of ${limit.limit} scans on your plan. Resets at midnight, or upgrade for higher daily allowances.'),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
              textAlign: TextAlign.center,
            ),
            if (!limit.isExpired) ...[
              const SizedBox(height: 16),
              const _MidnightCountdownText(),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: Icon(limit.isNotStarted ? Icons.stars_rounded : Icons.flash_on_rounded, size: 18),
              onPressed: () {
                Navigator.pop(context);
                if (limit.isNotStarted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TrialActivationScreen()),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                  );
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
              ),
              label: Text(
                limit.isExpired
                    ? 'Upgrade to Pro or Farm'
                    : (limit.isNotStarted ? (cfg.trialPrice <= 0 ? 'Start Free Trial' : 'Activate ₹${cfg.trialPrice.toInt()} Trial') : 'Upgrade Plan'),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrialExpiredPaywall(BuildContext context, ScanLimitResult limit) {
    final cfg = ref.watch(appConfigProvider).value ?? const AppConfig();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_clock_rounded, size: 16, color: AppColors.error),
                  SizedBox(width: 6),
                  Text(
                    'FREE TRIAL CONCLUDED',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.error, letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.no_photography_rounded, color: AppColors.error, size: 40),
            ),
            const SizedBox(height: 20),
            const Text(
              'Plant Diagnosis Locked',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your ${cfg.trialDays}-Day Free Trial has ended. There is no permanent free tier. To diagnose crop pathologies and access tailored agronomic prescriptions, please upgrade to an active plan.',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.45),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  _buildPlanHighlightRow(
                    title: 'Pro Plan (${cfg.proPrice}/30d)',
                    subtitle: '${cfg.proScanLimit} scans & ${cfg.proAiLimit} AI chats/day · Organic & chemical recipes',
                    isHighlighted: true,
                  ),
                  const Divider(height: 20),
                  _buildPlanHighlightRow(
                    title: 'Farm Pack (${cfg.farmPrice}/30d)',
                    subtitle: '${cfg.farmScanLimit} scans/day · Multi-farm plot tracker · B2B retailers directory',
                    isHighlighted: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UpgradeScreen())),
              icon: const Icon(Icons.flash_on_rounded, size: 20, color: Colors.white),
              label: const Text('UPGRADE TO PRO OR FARM', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => EmergencyDoctorPassSheet.show(context),
              icon: const Icon(Icons.medical_services_rounded, size: 16, color: Color(0xFF4F46E5)),
              label: const Text('Emergency Doctor Pass (₹10 / 24h)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF6366F1), width: 1.2),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanHighlightRow({
    required String title,
    required String subtitle,
    required bool isHighlighted,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isHighlighted ? AppColors.primary : AppColors.secondary).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isHighlighted ? Icons.workspace_premium_rounded : Icons.agriculture_rounded,
            color: isHighlighted ? AppColors.primary : AppColors.secondary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(navIndexProvider, (prev, next) {
      if (next == 1) {
        _refreshLimit();
      }
    });

    final scanLimitState = ref.watch(scanLimitProvider);
    final limitDisplay = scanLimitState.value ?? _limitResult;

    if (limitDisplay != null && limitDisplay.isExpired) {
      return Scaffold(
        backgroundColor: AppColors.lightBg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: Center(
            child: GlassButton.back(
              onTap: () => ref.read(navIndexProvider.notifier).state = 0,
            ),
          ),
          title: const Text('PhytoLens Scanner', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18)),
        ),
        body: SafeArea(
          child: _buildTrialExpiredPaywall(context, limitDisplay),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: Stack(
        children: [
          // Edge-to-edge Image preview / placeholder
          if (_selectedImage != null)
            Positioned.fill(
              child: Image.file(
                _selectedImage!,
                fit: BoxFit.cover,
              ).animate().fadeIn(),
            )
          else
            Positioned.fill(
              child: Container(color: AppColors.lightBg),
            ),

          SafeArea(
            child: Column(
              children: [
                // Clean header bar
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.lightBorder.withValues(alpha: 0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Scan limit chip
                      if (limitDisplay != null)
                        GestureDetector(
                          onTap: () {
                            if (limitDisplay.isNotStarted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const TrialActivationScreen()),
                              );
                            } else if (!limitDisplay.isUnlimited) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _getLimitColor(limitDisplay).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _getLimitText(limitDisplay),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _getLimitColor(limitDisplay),
                              ),
                            ),
                          ),
                        ),
                      const Spacer(),
                      // Supported crops
                      IconButton(
                        icon: const Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 22),
                        onPressed: _openSupportedCrops,
                        tooltip: 'Supported Crops',
                        visualDensity: VisualDensity.compact,
                      ),
                      // Tips
                      IconButton(
                        icon: const Icon(Icons.lightbulb_outline_rounded, color: AppColors.lightTextSecondary, size: 22),
                        onPressed: _showTips,
                        tooltip: 'Tips',
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ).animate().slideY(begin: -0.15, end: 0, duration: 250.ms, curve: Curves.easeOutCubic).fadeIn(duration: 200.ms),

                Expanded(
                  child: _selectedImage == null ? _buildPlaceholder() : const SizedBox.shrink(),
                ),

                // Light Frosted Floating Action Bar with 3 unified buttons
                Container(
                  margin: const EdgeInsets.fromLTRB(28, 0, 28, 16),
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        spreadRadius: 1,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Gallery Button
                            GlassButton(
                              size: 46,
                              icon: Icons.photo_library_outlined,
                              iconSize: 22,
                              tooltip: 'Gallery',
                              onTap: _analyzing ? null : () => _pickImage(ImageSource.gallery),
                            ),

                            // Camera Capture Button
                            _CameraCaptureButton(
                              onTap: _analyzing ? null : () => _pickImage(ImageSource.camera),
                            ),

                            // Tips / Info Button
                            GlassButton(
                              size: 46,
                              icon: Icons.info_outline_rounded,
                              iconSize: 22,
                              tooltip: 'Tips',
                              onTap: _showTips,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2, end: 0),
              ],
            ),
          ),

          // Modern Professional Scanning Overlay with pipeline stages (Option A Light Theme)
          if (_analyzing)
            Container(
              color: Colors.black.withValues(alpha: 0.35),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 36),
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 30,
                          spreadRadius: 2,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Glowing Scanner Icon
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFD1FAE5),
                            border: Border.all(
                              color: AppColors.primaryLight,
                              width: 1.5,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.document_scanner_rounded,
                              color: AppColors.primary,
                              size: 28,
                            ),
                          ),
                        )
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05), duration: 1200.ms),

                        const SizedBox(height: 20),

                        // Pipeline stage text
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            _scanStage,
                            key: ValueKey(_scanStage),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.lightTextPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Progress Bar
                        Container(
                          height: 4,
                          width: double.infinity,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const LinearProgressIndicator(
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 200.ms),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.1),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.energy_savings_leaf_rounded,
              color: AppColors.primaryLight,
              size: 42,
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(end: 1.05, duration: 2.seconds),
          const SizedBox(height: 24),
          const Text(
            'Ready to Scan',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Point your camera at a plant leaf\nto identify diseases',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  void _showTips() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _TipsSheet(),
    );
  }

  // ── Helper methods for clean scan limit display ────────────────────────
  Color _getLimitColor(ScanLimitResult limit) {
    if (limit.isExpired) return AppColors.lightError;
    if (limit.isNotStarted) return AppColors.primary;
    if (limit.isUnlimited) return AppColors.primary;
    if (limit.remaining > 0) return AppColors.lightSuccess;
    return AppColors.lightError;
  }

  String _getLimitText(ScanLimitResult limit) {
    if (limit.isExpired) return 'Trial Ended';
    if (limit.isNotStarted) return 'Start Trial';
    if (limit.isUnlimited) return '∞ Unlimited';
    return '${limit.remaining}/${limit.limit} left';
  }


}

class _CameraCaptureButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _CameraCaptureButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BouncingButton(
      scaleFactor: 0.90,
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.primaryGradient,
          border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.45),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.camera_alt_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}

class _TipsSheet extends StatelessWidget {
  const _TipsSheet();

  @override
  Widget build(BuildContext context) {
    const tips = [
      ('📸', 'Close-up shots', 'Get within 30cm of the leaf for best results'),
      ('☀️', 'Natural light', 'Outdoor light or bright indoor light works best'),
      ('🍃', 'Single leaf', 'Focus on one leaf with visible symptoms'),
      ('🔍', 'Sharp focus', 'Make sure the image is not blurry'),
      ('⚠️', 'Affected area', 'Include the diseased part clearly in frame'),
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Scanning Tips',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          ...tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tip.$1, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tip.$2,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          tip.$3,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _MidnightCountdownText extends StatefulWidget {
  const _MidnightCountdownText();
  @override
  State<_MidnightCountdownText> createState() => _MidnightCountdownTextState();
}

class _MidnightCountdownTextState extends State<_MidnightCountdownText> {
  late Timer _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    setState(() => _timeLeft = tomorrow.difference(now));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = _timeLeft.inHours.toString().padLeft(2, '0');
    final m = (_timeLeft.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_timeLeft.inSeconds % 60).toString().padLeft(2, '0');
    return Text(
      'Free scans reset in $h:$m:$s',
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
