import 'package:flutter/material.dart';
import '../../providers/language_provider.dart';
import '../../theme/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
class ModelManagerScreen extends ConsumerStatefulWidget {
  const ModelManagerScreen({super.key});

  @override
  ConsumerState<ModelManagerScreen> createState() => _ModelManagerScreenState();
}

class _ModelManagerScreenState extends ConsumerState<ModelManagerScreen> {
  bool _isGemmaDownloaded = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _checkModelStatus();
  }

  Future<void> _checkModelStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isGemmaDownloaded = prefs.getBool('model_gemma_downloaded') ?? false;
    });
  }

  Future<void> _downloadModel() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    // Simulate download for 1.5GB model
    for (int i = 0; i <= 100; i += 5) {
      await Future.delayed(const Duration(milliseconds: 200));
      setState(() {
        _downloadProgress = i / 100;
      });
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('model_gemma_downloaded', true);

    setState(() {
      _isDownloading = false;
      _isGemmaDownloaded = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.tr('offline_ai_ready'))),
      );
    }
  }

  Future<void> _deleteModel() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('model_gemma_downloaded', false);
    setState(() {
      _isGemmaDownloaded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text(ref.tr('offline_ai_setup')),
        backgroundColor: AppColors.cardDark,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
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
                    Icon(Icons.wifi_off, color: AppColors.primary, size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ref.tr('smart_farm_assistant'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(ref.tr('gemma_2b_best'),
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(ref.tr('download_desc'),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.sd_storage_outlined, size: 16, color: Colors.grey),
                    SizedBox(width: 4),
                    Text(ref.tr('size_1_5gb'), style: TextStyle(color: Colors.grey)),
                  ],
                ),
                SizedBox(height: 24),
                if (_isDownloading) ...[
                  LinearProgressIndicator(
                    value: _downloadProgress,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                  SizedBox(height: 8),
                  Center(
                    child: Text(
                      ref.tr('downloading_progress').replaceAll('{progress}', (_downloadProgress * 100).toInt().toString()),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ] else if (_isGemmaDownloaded) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: Icon(Icons.delete_outline, color: Colors.red),
                      label: Text(ref.tr('remove_download'), style: TextStyle(color: Colors.red)),
                      onPressed: _deleteModel,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.download),
                      label: Text(ref.tr('download_now_wifi')),
                      onPressed: _downloadModel,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 24),
          Text(ref.tr('what_you_get'),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          SizedBox(height: 12),
          _buildBenefitItem(Icons.chat_bubble_outline, ref.tr('ask_anywhere')),
          _buildBenefitItem(Icons.bolt, ref.tr('instant_answers')),
          _buildBenefitItem(Icons.signal_cellular_off, ref.tr('offline_reports')),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
