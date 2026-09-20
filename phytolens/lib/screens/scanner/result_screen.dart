// lib/screens/scanner/result_screen.dart
// Minimalist, optimistic plant diagnosis result screen

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../providers/scan_limit_provider.dart';
import '../../providers/ai_limit_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/scan_result.dart';
import '../../services/groq_service.dart';
import '../../services/gamification_service.dart';
import '../../services/supabase_service.dart';
import '../../services/sync_service.dart';
import '../../services/scan_limiter.dart';
import '../../theme/colors.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/subscription_gate.dart';
import '../../widgets/health_score_ring.dart';
import '../../widgets/loading_dots.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/glass_button.dart';
import '../ai/chatbot_screen.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../data/local_database.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final ScanResult scan;
  final File? imageFile;
  final PostScanReward? reward;
  final String userTier;
  final bool isSaved;

  const ResultScreen({
    super.key,
    required this.scan,
    this.imageFile,
    this.reward,
    this.userTier = 'free',
    this.isSaved = false,
  });

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  final _groq = GroqService();
  final _supabase = SupabaseService();
  final _syncService = SyncService();
  final _limiter = ScanLimiter();
  final _localDb = LocalDatabase();
  final FlutterTts _tts = FlutterTts();

  late ScanResult _currentScan;
  late bool _isSaved;
  bool _saving = false;

  String? _aiAdvice;
  bool _loadingAdvice = false;
  bool _addedToGarden = false;
  bool _addingToGarden = false;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _currentScan = widget.scan;
    _isSaved = widget.isSaved;

    _initAdvice();
    _initTts();

    // Optimistic Auto-Save: Automatically persist to care log immediately
    if (!_isSaved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoSaveScan();
      });
    }
  }

  void _initTts() async {
    await _tts.setLanguage('en-IN');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  Future<void> _speak(String text) async {
    // Strip markdown formatting for cleaner TTS
    final clean = text
        .replaceAll(RegExp(r'[#*_`~>]'), '')
        .replaceAll(RegExp(r'\[.*?\]\(.*?\)'), '')
        .replaceAll(RegExp(r'\|.*?\|'), '')
        .replaceAll(RegExp(r'---+'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    if (_isSpeaking) {
      await _tts.stop();
      if (mounted) setState(() => _isSpeaking = false);
      return;
    }

    setState(() => _isSpeaking = true);
    await _tts.speak(clean);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  void _initAdvice() {
    if (_currentScan.remedy != null && _currentScan.remedy!.trim().isNotEmpty) {
      _aiAdvice = _currentScan.remedy;
      _loadingAdvice = false;
      return;
    }

    if (_currentScan.isUnknownPlant) {
      _aiAdvice = null;
      _loadingAdvice = false;
      return;
    }

    if (_currentScan.isHealthy) {
      _aiAdvice = 'Your plant looks healthy and vibrant! Keep providing adequate sunlight, maintain your regular watering routine, and check weekly for pests.';
      _loadingAdvice = false;
      return;
    }

    _fetchFallbackAdvice();
  }

  Future<void> _fetchFallbackAdvice() async {
    setState(() => _loadingAdvice = true);
    try {
      final advice = await _groq.getTieredAdvice(
        tier: widget.userTier,
        plantName: _currentScan.plantName,
        diseaseName: _currentScan.diseaseName,
        healthScore: _currentScan.healthScore,
      );
      if (mounted) {
        setState(() {
          _aiAdvice = advice;
          _currentScan = ScanResult(
            id: _currentScan.id,
            userId: _currentScan.userId,
            diseaseName: _currentScan.diseaseName,
            diseaseConfidence: _currentScan.diseaseConfidence,
            plantName: _currentScan.plantName,
            healthScore: _currentScan.healthScore,
            remedy: advice,
            scannedAt: _currentScan.scannedAt,
            imageUrl: _currentScan.imageUrl,
          );
          _loadingAdvice = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAdvice = false);
    }
  }

  Future<void> _autoSaveScan() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _isSaved || _saving) return;

    setState(() => _saving = true);

    try {
      final isOnline = await _syncService.isOnline();

      final scanToSave = ScanResult(
        id: '',
        userId: user.id,
        diseaseName: _currentScan.diseaseName,
        diseaseConfidence: _currentScan.diseaseConfidence,
        plantName: _currentScan.plantName,
        healthScore: _currentScan.healthScore,
        remedy: _aiAdvice ?? _currentScan.remedy,
        scannedAt: DateTime.now(),
        imageUrl: widget.imageFile?.path ?? _currentScan.imageUrl,
      );

      ScanResult saved;
      if (isOnline) {
        try {
          saved = await _supabase.saveScan(scanToSave);
          // Delete temporary scan from local DB if it existed
          if (_currentScan.id.startsWith('temp_')) {
            await _localDb.deleteScan(_currentScan.id);
          }
          await _localDb.upsertScan(saved, synced: true);
          await _limiter.incrementLocalScanCount();
        } catch (e) {
          debugPrint('Supabase saveScan notice, falling back to local DB: $e');
          await _syncService.saveScanOffline(scanToSave);
          await _limiter.incrementLocalScanCount();
          saved = scanToSave;
        }
      } else {
        await _syncService.saveScanOffline(scanToSave);
        await _limiter.incrementLocalScanCount();
        saved = scanToSave;
      }

      if (mounted) {
        setState(() {
          _currentScan = saved;
          _isSaved = true;
          _saving = false;
        });

        ref.read(scanLimitProvider.notifier).recordScan();
        ref.invalidate(currentUserProvider);
      }

      // Background upload image to cloud storage if online, then attach URL
      if (isOnline && widget.imageFile != null && saved.id.isNotEmpty && !saved.id.startsWith('temp_')) {
        _uploadAndAttachImage(widget.imageFile!, user.id, saved.id);
      }
    } catch (e) {
      debugPrint('Error auto-saving scan: $e');
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _uploadAndAttachImage(File file, String userId, String scanId) async {
    try {
      final cloudUrl = await _supabase.uploadImage(file, userId);
      if (cloudUrl != null && cloudUrl.isNotEmpty) {
        await _supabase.updateScan(scanId, {'image_url': cloudUrl});
        await _localDb.updateImageUrl(scanId, cloudUrl);
      }
    } catch (e) {
      debugPrint('Background image upload notice: $e');
    }
  }

  Future<void> _addToGarden() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _addingToGarden || _addedToGarden) return;

    setState(() => _addingToGarden = true);
    try {
      final plant = await _supabase.addPlant(
        user.id,
        _currentScan.plantName,
        _currentScan.plantName,
        imageUrl: _currentScan.imageUrl,
        latestHealthScore: _currentScan.healthScore,
        latestDisease: _currentScan.diseaseName,
      );

      // If we already saved this scan, link it to the new plant ID in Supabase
      if (_currentScan.id.isNotEmpty) {
        try {
          await _supabase.updateScan(_currentScan.id, {'plant_id': plant.id});
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _addingToGarden = false;
          _addedToGarden = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_currentScan.plantName} added to your Garden! 🌱'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _addingToGarden = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not add to garden: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: CustomScrollView(
        slivers: [
          // ── App Bar with Plant Photo ──────────────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.lightBg,
            leading: Center(
              child: GlassButton.back(
                style: GlassButtonStyle.dark,
                onTap: () => Navigator.pop(context),
              ),
            ),
            actions: [
              Center(
                child: GlassButton(
                  style: GlassButtonStyle.dark,
                  icon: Icons.share_rounded,
                  iconSize: 18,
                  onTap: _shareDiagnosis,
                ),
              ),
              const SizedBox(width: 14),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: widget.imageFile != null
                  ? Image.file(
                      widget.imageFile!,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.white,
                      child: Center(
                        child: Text(_currentScan.statusEmoji, style: const TextStyle(fontSize: 80)),
                      ),
                    ),
            ),
          ),

          // ── Body Content ──────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 70),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Auto-save notification pill
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isSaved ? Icons.check_circle_rounded : Icons.sync_rounded,
                            size: 13,
                            color: AppColors.primaryLight,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isSaved ? 'Saved to Care Log' : 'Syncing to Care Log...',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Diagnosis Summary Card
                _buildDiagnosisCard(),

                const SizedBox(height: 16),

                // Care Guide / Treatment Card
                Consumer(
                  builder: (context, ref, child) {
                    final aiState = ref.watch(aiLimitProvider);
                    final isNotStarted = aiState.value?.isNotStarted ?? false;
                    
                    return SubscriptionGate(
                      featureName: 'Care Recommendations & AI Specialist',
                      hasAccess: !isNotStarted,
                      child: Column(
                        children: [
                          _buildCareGuideCard(),
                          const SizedBox(height: 24),
                          _buildActionButtons(),
                        ],
                      ),
                    );
                  }
                ),

                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosisCard() {
    final isHealthy = _currentScan.isHealthy;
    final statusColor = isHealthy ? AppColors.primaryDark : AppColors.warning;

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
            score: _currentScan.healthScore,
            size: 80,
            strokeWidth: 7,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _currentScan.plantName.isNotEmpty ? _currentScan.plantName : 'Plant Leaf',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    if (_currentScan.aiSource == 'offline')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('OFFLINE AI', style: TextStyle(fontSize: 9, color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
                      )
                    else if (_currentScan.aiSource == 'cloud')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('CLOUD AI', style: TextStyle(fontSize: 9, color: AppColors.secondary, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _currentScan.diseaseName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${(_currentScan.diseaseConfidence * 100).round()}% match confidence',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                if (!isHealthy) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Severity:', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _currentScan.severityPercent / 100,
                            minHeight: 6,
                            backgroundColor: AppColors.lightBorder,
                            color: _currentScan.severityPercent > 75 ? AppColors.error : (_currentScan.severityPercent > 40 ? AppColors.warning : AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${_currentScan.severityPercent}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCareGuideCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.spa_rounded, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Care Recommendations',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              // ── Voice Read-Aloud Button ──────────────────────────────
              if (_aiAdvice != null && !_loadingAdvice)
                GestureDetector(
                  onTap: () => _speak(_aiAdvice!),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _isSpeaking
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isSpeaking
                          ? Icons.stop_rounded
                          : Icons.volume_up_rounded,
                      color: _isSpeaking
                          ? AppColors.primary
                          : const Color(0xFF64748B),
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_loadingAdvice)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: TypingIndicator(),
              ),
            )
          else if (_aiAdvice != null)
            MarkdownBody(
              data: _aiAdvice!,
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
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            const Text(
              'No specific treatment needed. Keep maintaining consistent watering and sunlight conditions.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final prompt = _currentScan.isHealthy
        ? 'My ${_currentScan.plantName} is healthy (${_currentScan.healthScore}% health score). What are the best care practices and watering schedules to keep it flourishing?'
        : 'My ${_currentScan.plantName} was diagnosed with ${_currentScan.diseaseName} (Health Score: ${_currentScan.healthScore}%). Please provide step-by-step organic remedies, fungicide advice, and prevention tips.';

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: BouncingButton(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatbotScreen(initialMessage: prompt),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Ask AI Plant Specialist',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!_currentScan.isNonPlant) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: BouncingButton(
              onTap: _addingToGarden || _addedToGarden ? null : _addToGarden,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: _addedToGarden
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _addedToGarden
                        ? AppColors.primary
                        : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_addingToGarden)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      )
                    else
                      Icon(
                        _addedToGarden ? Icons.check_circle_rounded : Icons.yard_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    const SizedBox(width: 8),
                    Text(
                      _addedToGarden ? 'Added to Your Garden' : 'Add to My Garden',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: BouncingButton(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              child: const Text(
                'Back to Plants',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _shareDiagnosis() {
    final text = 'I diagnosed my ${_currentScan.plantName} using PhytoLens! 🌱\n\n'
        'Condition: ${_currentScan.diseaseName}\n'
        'Health Score: ${_currentScan.healthScore}%\n\n'
        'Check your plants with PhytoLens.';
    // ignore: deprecated_member_use
    Share.share(text, subject: 'PhytoLens Plant Diagnosis');
  }
}
