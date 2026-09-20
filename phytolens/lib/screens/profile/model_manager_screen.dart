import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../services/local_llm_service.dart';
import '../../services/supabase_service.dart';
import '../../data/local_database.dart';
import '../../widgets/bouncing_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ModelManagerScreen extends StatefulWidget {
  const ModelManagerScreen({super.key});

  @override
  State<ModelManagerScreen> createState() => _ModelManagerScreenState();
}

class _ModelManagerScreenState extends State<ModelManagerScreen> {
  final LocalLLMService _llmService = LocalLLMService();
  bool _isDownloaded = false;
  int _partialBytes = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _llmService.addListener(_onServiceChanged);
    _checkStatus();
  }

  @override
  void dispose() {
    _llmService.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _checkStatus() async {
    setState(() => _isLoading = true);
    final isDownloaded = await _llmService.isModelDownloaded();
    final partialBytes = isDownloaded ? 0 : await _llmService.getPartialDownloadSizeBytes();
    if (mounted) {
      setState(() {
        _isDownloaded = isDownloaded;
        _partialBytes = partialBytes;
        _isLoading = false;
      });
    }
  }

  Future<void> _startDownload() async {
    final success = await _llmService.downloadModel(
      onProgress: (_) {},
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: AppColors.error),
          );
        }
      },
    );

    if (success) {
      // Auto-feed user context after download
      await _feedContext();
    }
    await _checkStatus();
  }

  Future<void> _feedContext() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final user = await SupabaseService().getUser(uid);
      if (user == null) return;
      final scans = await LocalDatabase().getUserScans(uid, limit: 20);
      await _llmService.feedUserContext(user, scans);
    } catch (e) {
      debugPrint('Feed context error: $e');
    }
  }

  Future<void> _cancelDownload() async {
    _llmService.cancelDownload();
  }

  Future<void> _cleanPartial() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: const Text('Clean Partial Download?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will delete the partially downloaded file. You will need to start the download from scratch.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('Clean'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await _llmService.cleanPartialDownload();
    await _checkStatus();
  }

  Future<void> _deleteModel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: const Text('Delete Offline AI?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will remove the offline AI model and free up space. You can download it again later.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    await _llmService.deleteModel();
    await _checkStatus();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final isDownloading = _llmService.isDownloading;
    final progress = _llmService.downloadProgress;
    final hasPartial = _partialBytes > 0 && !_isDownloaded && !isDownloading;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        title: const Text('Offline AI Model'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Status Card ──
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.cardDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _isDownloaded
                              ? Icons.cloud_done_rounded
                              : (isDownloading
                                  ? Icons.downloading_rounded
                                  : (hasPartial
                                      ? Icons.pause_circle_outline_rounded
                                      : Icons.cloud_download_rounded)),
                          size: 48,
                          color: _isDownloaded
                              ? AppColors.healthGood
                              : (isDownloading ? AppColors.primary : AppColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isDownloaded
                              ? 'AI Model is Ready'
                              : (isDownloading
                                  ? 'Downloading...'
                                  : (hasPartial
                                      ? 'Download Paused'
                                      : 'Offline AI Not Downloaded')),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isDownloaded
                              ? 'You can scan crops and chat without internet.'
                              : (hasPartial
                                  ? '${_formatBytes(_partialBytes)} downloaded of ${_llmService.modelSizeLabel}'
                                  : 'Download the model (${_llmService.modelSizeLabel}) to use offline AI.'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Download Progress ──
                  if (isDownloading) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: AppColors.cardDark,
                        color: AppColors.primary,
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(progress * 100).toStringAsFixed(1)}%',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Cancel button
                    BouncingButton(
                      onTap: _cancelDownload,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cancel_outlined, color: AppColors.error, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Cancel Download',
                              style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // ── Resume + Clean (partial exists) ──
                  if (hasPartial && !isDownloading) ...[
                    BouncingButton(
                      onTap: _startDownload,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.play_arrow_rounded, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'Resume Download (${_formatBytes(_partialBytes)})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    BouncingButton(
                      onTap: _cleanPartial,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cleaning_services_rounded, color: AppColors.textSecondary, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Clean & Start Fresh',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // ── Download Button (no partial, not downloading) ──
                  if (!_isDownloaded && !isDownloading && !hasPartial)
                    BouncingButton(
                      onTap: _startDownload,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.download_rounded, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Download Model',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ── Delete Button (model downloaded) ──
                  if (_isDownloaded && !isDownloading)
                    BouncingButton(
                      onTap: _deleteModel,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_outline_rounded, color: AppColors.error),
                            SizedBox(width: 8),
                            Text(
                              'Delete Model to Free Space',
                              style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),

                  // ── Info Section ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'About Offline AI',
                              style: TextStyle(
                                color: AppColors.primaryLight,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '• Model: Llama 3.2 1B Instruct (${_llmService.modelSizeLabel})\n'
                          '• Downloads can be paused and resumed\n'
                          '• Works completely without internet once downloaded\n'
                          '• Personalized with your scan history & profile',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
