import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ModelManagerScreen extends StatefulWidget {
  const ModelManagerScreen({super.key});

  @override
  State<ModelManagerScreen> createState() => _ModelManagerScreenState();
}

class _ModelManagerScreenState extends State<ModelManagerScreen> {
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
        const SnackBar(content: Text('Offline AI Assistant is ready!')),
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
        title: const Text('Offline AI Setup'),
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
                    const Icon(Icons.wifi_off, color: AppColors.primary, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Smart Farm Assistant',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Text(
                            'Gemma 2B (Best for Agriculture)',
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
                const SizedBox(height: 16),
                const Text(
                  'Download this package to let the app answer your farming questions and generate scan reports even when you have no internet connection.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.sd_storage_outlined, size: 16, color: Colors.grey),
                    SizedBox(width: 4),
                    Text('Size: ~1.5 GB', style: TextStyle(color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 24),
                if (_isDownloading) ...[
                  LinearProgressIndicator(
                    value: _downloadProgress,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Downloading... ${(_downloadProgress * 100).toInt()}%',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ] else if (_isGemmaDownloaded) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text('Remove Download', style: TextStyle(color: Colors.red)),
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
                      icon: const Icon(Icons.download),
                      label: const Text('Download Now (Wi-Fi Recommended)'),
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
          const SizedBox(height: 24),
          const Text(
            'What you get:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          _buildBenefitItem(Icons.chat_bubble_outline, 'Ask questions about crops anywhere'),
          _buildBenefitItem(Icons.bolt, 'Instant answers without waiting for network'),
          _buildBenefitItem(Icons.signal_cellular_off, 'Full offline crop disease reports'),
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
          const SizedBox(width: 12),
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
