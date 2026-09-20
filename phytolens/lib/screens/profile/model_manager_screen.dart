import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/colors.dart';
import '../../services/local_llm_service.dart';
import '../../widgets/bouncing_button.dart';

class ModelManagerScreen extends StatefulWidget {
  const ModelManagerScreen({super.key});

  @override
  State<ModelManagerScreen> createState() => _ModelManagerScreenState();
}

class _ModelManagerScreenState extends State<ModelManagerScreen> {
  final LocalLLMService _llmService = LocalLLMService();
  bool _isDownloaded = false;
  bool _isDownloading = false;
  double _progress = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() => _isLoading = true);
    final isDownloaded = await _llmService.isModelDownloaded();
    if (mounted) {
      setState(() {
        _isDownloaded = isDownloaded;
        _isLoading = false;
      });
    }
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
    });

    final success = await _llmService.downloadModel(
      onProgress: (progress) {
        if (mounted) {
          setState(() => _progress = progress);
        }
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: AppColors.error),
          );
        }
      },
    );

    if (mounted) {
      setState(() {
        _isDownloading = false;
        _isDownloaded = success;
      });
    }
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

  @override
  Widget build(BuildContext context) {
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
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.cardDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.1)),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _isDownloaded ? Icons.cloud_done_rounded : Icons.cloud_download_rounded,
                          size: 48,
                          color: _isDownloaded ? AppColors.healthGood : AppColors.primary,
                        ).animate().scale(delay: 100.ms),
                        const SizedBox(height: 16),
                        Text(
                          _isDownloaded ? 'AI Model is Ready' : 'Offline AI Not Downloaded',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Size: ${_llmService.modelSizeLabel}\n${_isDownloaded ? "You can scan crops and chat without internet." : "Download the model to scan crops and chat without an internet connection."}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 32),
                  if (_isDownloading) ...[
                    const Text('Downloading...', style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: AppColors.cardDark,
                      color: AppColors.primary,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_progress * 100).toStringAsFixed(1)}%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ] else if (!_isDownloaded)
                    BouncingButton(
                      onTap: _startDownload,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
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
                    ).animate().slideY(begin: 0.5, curve: Curves.easeOut)
                  else
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
                    ).animate().slideY(begin: 0.5, curve: Curves.easeOut),
                ],
              ),
            ),
    );
  }
}
