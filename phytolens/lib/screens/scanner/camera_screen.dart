// lib/screens/scanner/camera_screen.dart

import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/scan_limit_provider.dart';
import '../../services/ml_service.dart';
import '../../services/groq_service.dart';
import '../../services/gemini_service.dart';
import '../../services/plantnet_service.dart';
import '../../services/scan_limiter.dart';
import '../../services/sync_service.dart';
import '../../services/permission_service.dart';
import '../../models/scan_result.dart';
import '../../theme/colors.dart';

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../subscription/upgrade_screen.dart';
import '../subscription/trial_activation_screen.dart';
import 'result_screen.dart';
import '../home/home_screen.dart';
import 'supported_crops_screen.dart';
import '../../widgets/bouncing_button.dart';

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

  bool _analyzing = false;
  File? _selectedImage;
  ScanLimitResult? _limitResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ml.initialize();
    _checkConnectivity();
    _refreshLimit();
    _checkFirstLaunch();
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

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenInfo = prefs.getBool('has_seen_model_info_v2') ?? false;
    if (!hasSeenInfo) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showFirstLaunchInfo();
        prefs.setBool('has_seen_model_info_v2', true);
      });
    }
  }

  void _showFirstLaunchInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Smart Plant Scanner', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'PhytoLens uses a multi-model AI pipeline to identify plants:\n\n'
          '🔬 On-device TFLite model for instant offline detection of 14 crop types and 38 diseases.\n\n'
          '🌿 Pl@ntNet botanical engine for 82,000+ plant species identification online.\n\n'
          '🤖 AI fallback for general object recognition.\n\n'
          'For best results, ensure clear, well-lit photos of leaves or flowers.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
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
    });

    try {
      // ── TIER 1: On-device TFLite (instant, offline) ────────────────────
      final mlResult = await _ml.classifyImage(file);

      String plantName = mlResult.plantName;
      String diseaseName = mlResult.diseaseName;
      double confidence = mlResult.confidence;
      int healthScore = mlResult.healthScore;
      String? remedy;
      bool identifiedByPlantNet = false;

      bool isOnline = await _syncService.isOnline();
      final String userTier = limit.tier;

      // ── TIER 2: Pl@ntNet API (online botanical identification) ─────────
      if (isOnline && (confidence < 0.70 || plantName == 'Unknown Plant' || diseaseName == 'Unrecognized')) {
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
      if (isOnline && !identifiedByPlantNet &&
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
      if (isOnline && diseaseName != 'Object (Non-Plant)' &&
          plantName != 'Unknown Plant' && plantName != 'Unrecognized Item') {
        try {
          remedy = await _groq.getTieredAdvice(
            tier: userTier,
            plantName: plantName,
            diseaseName: diseaseName,
            healthScore: healthScore,
          );
        } catch (e) {
          debugPrint('Groq report generation error: $e');
        }
      }

      // ── Prepare ScanResult (User will choose whether to save) ────────
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
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
      );

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
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🥀', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 16),
            Text(
              limit.isExpired ? 'Trial Expired' : 'Your Plant Can\'t Wait',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              limit.isExpired 
                  ? 'Your 2-day trial has expired. Upgrade to Pro for instant, unlimited health analysis and save your plants today.'
                  : (limit.isNotStarted
                      ? 'Activate your 2-Day Trial to start identifying and treating your plants.'
                      : 'You\'ve reached your daily free scan limit. Don\'t let your plants suffer—upgrade to Pro for instant, unlimited health analysis and save them today.'),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (!limit.isExpired) const _MidnightCountdownText(),
            if (!limit.isExpired) const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.flash_on_rounded, size: 18),
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
                limit.isNotStarted ? 'Activate 2-Day Trial (₹1)' : 'Unlock Unlimited Scans Now',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
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

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
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
              child: Container(color: AppColors.backgroundDark),
            ),

          SafeArea(
            child: Column(
              children: [
                // Header (Glassmorphic)
                Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.psychology, color: AppColors.primary, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Plant Scanner',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'AI-Powered Disease Detection',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.menu_book_rounded, color: AppColors.primaryLight),
                        onPressed: _openSupportedCrops,
                        tooltip: 'Supported Crops',
                      ),
                      if (limitDisplay != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: limitDisplay.remaining == -1
                                ? AppColors.primary.withValues(alpha: 0.2)
                                : limitDisplay.remaining > 0
                                    ? AppColors.success.withValues(alpha: 0.2)
                                    : AppColors.error.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: limitDisplay.remaining == -1
                                  ? AppColors.primary.withValues(alpha: 0.5)
                                  : limitDisplay.remaining > 0
                                      ? AppColors.success.withValues(alpha: 0.5)
                                      : AppColors.error.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Text(
                            limitDisplay.remaining == -1
                                ? 'Unlimited'
                                : '${limitDisplay.remaining} Scans Left',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: limitDisplay.remaining == -1
                                  ? AppColors.primaryLight
                                  : limitDisplay.remaining > 0
                                      ? AppColors.success
                                      : AppColors.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ).animate().slideY(begin: -0.2, end: 0).fadeIn(),

                Expanded(
                  child: _selectedImage == null ? _buildPlaceholder() : const SizedBox.shrink(),
                ),

                // Glossy Floating Action Bar with 3 unified buttons
                Container(
                  margin: const EdgeInsets.fromLTRB(28, 0, 28, 16),
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        blurRadius: 28,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        blurRadius: 18,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xE0121A17),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Gallery Button
                            BouncingButton(
                              onTap: _analyzing ? null : () => _pickImage(ImageSource.gallery),
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.08),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.photo_library_outlined,
                                  size: 21,
                                  color: Colors.white,
                                ),
                              ),
                            ),

                            // Camera Capture Button
                            _CameraCaptureButton(
                              onTap: _analyzing ? null : () => _pickImage(ImageSource.camera),
                            ),

                            // Tips / Info Button
                            BouncingButton(
                              onTap: _showTips,
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.08),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.info_outline_rounded,
                                  size: 21,
                                  color: Colors.white,
                                ),
                              ),
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

          // Modern Professional Scanning Overlay
          if (_analyzing)
            Container(
              color: Colors.black.withValues(alpha: 0.85),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 36),
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131A22).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.25), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 36,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Glowing Optics Scanner Icon
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.15),
                          border: Border.all(
                            color: AppColors.primaryLight.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryLight.withValues(alpha: 0.25),
                              blurRadius: 22,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.document_scanner_rounded,
                            color: AppColors.primaryLight,
                            size: 32,
                          ),
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05), duration: 1200.ms),

                      const SizedBox(height: 24),

                      // Single clean prompt text
                      const Text(
                        'wait, while we scan',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Modern Professional Progress Bar
                      Container(
                        height: 6,
                        width: double.infinity,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const LinearProgressIndicator(
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryLight),
                        ),
                      ),
                    ],
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
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _TipsSheet(),
    );
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
