// lib/screens/scanner/result_screen.dart
// Minimalist, optimistic plant diagnosis result screen

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../ai/chatbot_screen.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

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

  late ScanResult _currentScan;
  late bool _isSaved;
  bool _saving = false;

  String? _aiAdvice;
  bool _loadingAdvice = false;

  @override
  void initState() {
    super.initState();
    _currentScan = widget.scan;
    _isSaved = widget.isSaved || (widget.scan.id.isNotEmpty && !widget.scan.id.startsWith('temp_'));

    _initAdvice();

    // Optimistic Auto-Save: Automatically persist to care log immediately
    if (!_isSaved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoSaveScan();
      });
    }
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _isSaved || _saving) return;

    setState(() => _saving = true);

    try {
      final isOnline = await _syncService.isOnline();
      String? imageUrl = _currentScan.imageUrl;

      if (isOnline && widget.imageFile != null) {
        imageUrl = await _supabase.uploadImage(widget.imageFile!, user.uid);
      }

      final scanToSave = ScanResult(
        id: '',
        userId: user.uid,
        diseaseName: _currentScan.diseaseName,
        diseaseConfidence: _currentScan.diseaseConfidence,
        plantName: _currentScan.plantName,
        healthScore: _currentScan.healthScore,
        remedy: _aiAdvice ?? _currentScan.remedy,
        scannedAt: DateTime.now(),
        imageUrl: imageUrl ?? widget.imageFile?.path,
      );

      ScanResult saved;
      if (isOnline) {
        saved = await _supabase.saveScan(scanToSave);
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
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
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
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Colors.white),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.share_rounded, size: 18, color: Colors.white),
                ),
                onPressed: _shareDiagnosis,
              ),
              const SizedBox(width: 8),
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
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
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
    final statusColor = isHealthy ? AppColors.primaryLight : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
                Text(
                  _currentScan.plantName.isNotEmpty ? _currentScan.plantName : 'Plant Leaf',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.spa_rounded, color: AppColors.primaryLight, size: 18),
              SizedBox(width: 8),
              Text(
                'Care Recommendations',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
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
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                listBullet: const TextStyle(
                  fontSize: 14,
                  color: AppColors.primaryLight,
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
