// lib/widgets/model_download_prompt.dart
//
// Farmer-friendly AI model download prompt.
// Designed for uneducated farmers — uses simple icons, large text,
// easy-to-understand language, and visual progress.
// Auto-detects device language for localized messaging.

import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../services/local_llm_service.dart';
import 'bouncing_button.dart';

class ModelDownloadPrompt extends StatefulWidget {
  final VoidCallback? onComplete;
  final VoidCallback? onSkip;

  const ModelDownloadPrompt({
    super.key,
    this.onComplete,
    this.onSkip,
  });

  @override
  State<ModelDownloadPrompt> createState() => _ModelDownloadPromptState();
}

class _ModelDownloadPromptState extends State<ModelDownloadPrompt> {
  final LocalLLMService _llmService = LocalLLMService();
  bool _isDownloading = false;
  bool _isComplete = false;
  bool _hasError = false;
  double _progress = 0.0;
  String _errorMessage = '';

  // ── Simple multi-language messages ─────────────────────────────────────
  // Detects locale and returns farmer-friendly text
  Map<String, String> _getTexts(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;

    switch (locale) {
      case 'hi': // Hindi
        return {
          'title': '🌱 AI मॉडल डाउनलोड करें',
          'subtitle': 'बिना इंटरनेट के फसल की बीमारी जांचें',
          'description': 'एक बार डाउनलोड करें, फिर बिना इंटरनेट के हमेशा इस्तेमाल करें।',
          'size': 'साइज़: लगभग 1.5 GB',
          'wifi_tip': '💡 WiFi पर डाउनलोड करें — मोबाइल डेटा बचाएं',
          'download': '⬇️ डाउनलोड करें',
          'downloading': 'डाउनलोड हो रहा है...',
          'complete': '✅ तैयार है! AI अब ऑफलाइन काम करेगा',
          'skip': 'बाद में करें',
          'error': '❌ डाउनलोड फेल हुआ। दोबारा कोशिश करें।',
          'retry': '🔄 फिर से कोशिश करें',
          'feature1': '📸 फ़ोटो से बीमारी पहचानें',
          'feature2': '💊 इलाज और दवाई की जानकारी',
          'feature3': '🌾 बिना इंटरनेट काम करे',
        };
      case 'bn': // Bengali
        return {
          'title': '🌱 AI মডেল ডাউনলোড করুন',
          'subtitle': 'ইন্টারনেট ছাড়া ফসলের রোগ পরীক্ষা করুন',
          'description': 'একবার ডাউনলোড করুন, তারপর ইন্টারনেট ছাড়াই সবসময় ব্যবহার করুন।',
          'size': 'সাইজ: প্রায় ১.৫ GB',
          'wifi_tip': '💡 WiFi-তে ডাউনলোড করুন — মোবাইল ডেটা বাঁচান',
          'download': '⬇️ ডাউনলোড করুন',
          'downloading': 'ডাউনলোড হচ্ছে...',
          'complete': '✅ তৈরি! AI এখন অফলাইনে কাজ করবে',
          'skip': 'পরে করুন',
          'error': '❌ ডাউনলোড ব্যর্থ হয়েছে। আবার চেষ্টা করুন।',
          'retry': '🔄 আবার চেষ্টা করুন',
          'feature1': '📸 ছবি থেকে রোগ চিহ্নিত করুন',
          'feature2': '💊 চিকিৎসা ও ওষুধের তথ্য',
          'feature3': '🌾 ইন্টারনেট ছাড়া কাজ করে',
        };
      case 'ta': // Tamil
        return {
          'title': '🌱 AI மாடலை பதிவிறக்கம் செய்யுங்கள்',
          'subtitle': 'இணையம் இல்லாமல் பயிர் நோயைக் கண்டறியுங்கள்',
          'description': 'ஒரு முறை பதிவிறக்கம் செய்யுங்கள், பின்னர் இணையம் இல்லாமல் எப்போதும் பயன்படுத்துங்கள்.',
          'size': 'அளவு: சுமார் 1.5 GB',
          'wifi_tip': '💡 WiFi-ல் பதிவிறக்கம் செய்யுங்கள்',
          'download': '⬇️ பதிவிறக்கம்',
          'downloading': 'பதிவிறக்கம் செய்கிறது...',
          'complete': '✅ தயார்! AI இப்போது ஆஃப்லைனில் வேலை செய்யும்',
          'skip': 'பிறகு',
          'error': '❌ பதிவிறக்கம் தோல்வி. மீண்டும் முயற்சிக்கவும்.',
          'retry': '🔄 மீண்டும் முயற்சி',
          'feature1': '📸 படத்தில் நோயைக் கண்டறிதல்',
          'feature2': '💊 சிகிச்சை மற்றும் மருந்து தகவல்',
          'feature3': '🌾 இணையம் இல்லாமல் வேலை செய்யும்',
        };
      case 'te': // Telugu
        return {
          'title': '🌱 AI మోడల్ డౌన్‌లోడ్ చేయండి',
          'subtitle': 'ఇంటర్నెట్ లేకుండా పంట వ్యాధిని తెలుసుకోండి',
          'description': 'ఒకసారి డౌన్‌లోడ్ చేయండి, తర్వాత ఇంటర్నెట్ లేకుండా ఎప్పుడైనా వాడండి.',
          'size': 'సైజ్: సుమారు 1.5 GB',
          'wifi_tip': '💡 WiFi లో డౌన్‌లోడ్ చేయండి',
          'download': '⬇️ డౌన్‌లోడ్',
          'downloading': 'డౌన్‌లోడ్ అవుతోంది...',
          'complete': '✅ సిద్ధం! AI ఇప్పుడు ఆఫ్‌లైన్‌లో పని చేస్తుంది',
          'skip': 'తర్వాత',
          'error': '❌ డౌన్‌లోడ్ విఫలం. మళ్ళీ ప్రయత్నించండి.',
          'retry': '🔄 మళ్ళీ ప్రయత్నం',
          'feature1': '📸 ఫోటో నుండి వ్యాధిని గుర్తించడం',
          'feature2': '💊 చికిత్స మరియు మందుల సమాచారం',
          'feature3': '🌾 ఇంటర్నెట్ లేకుండా పని చేస్తుంది',
        };
      default: // English (default)
        return {
          'title': '🌱 Download AI for Your Farm',
          'subtitle': 'Check crop disease without internet',
          'description': 'Download once, use forever — no internet needed after this.',
          'size': 'Size: About 1.5 GB',
          'wifi_tip': '💡 Use WiFi to save your mobile data',
          'download': '⬇️ Download Now',
          'downloading': 'Downloading...',
          'complete': '✅ Ready! AI will now work without internet',
          'skip': 'Do it later',
          'error': '❌ Download failed. Please try again.',
          'retry': '🔄 Try Again',
          'feature1': '📸 Find disease from photo',
          'feature2': '💊 Get treatment & medicine info',
          'feature3': '🌾 Works without internet',
        };
    }
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _hasError = false;
      _progress = 0.0;
    });

    final success = await _llmService.downloadModel(
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = err;
            _isDownloading = false;
          });
        }
      },
    );

    if (mounted && success) {
      setState(() {
        _isComplete = true;
        _isDownloading = false;
      });
      // Auto-close after showing success
      await Future.delayed(const Duration(seconds: 2));
      widget.onComplete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final texts = _getTexts(context);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header Icon ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.download_rounded,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),

          // ── Title ──
          Text(
            texts['title']!,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          Text(
            texts['subtitle']!,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          Text(
            texts['description']!,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // ── Features ──
          _buildFeaturePill(texts['feature1']!),
          const SizedBox(height: 8),
          _buildFeaturePill(texts['feature2']!),
          const SizedBox(height: 8),
          _buildFeaturePill(texts['feature3']!),
          const SizedBox(height: 20),

          // ── Size & WiFi Tip ──
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.lightCard,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  texts['size']!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  texts['wifi_tip']!,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Progress / Action ──
          if (_isComplete) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.lightSuccessBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success, size: 24),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      texts['complete']!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_isDownloading) ...[
            Column(
              children: [
                Text(
                  texts['downloading']!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 12,
                    backgroundColor: AppColors.lightCard,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_progress * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ] else if (_hasError) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lightErrorBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _errorMessage.isNotEmpty ? _errorMessage : texts['error']!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.error,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            BouncingButton(
              onTap: _startDownload,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    texts['retry']!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ] else ...[
            BouncingButton(
              onTap: _startDownload,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    texts['download']!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // ── Skip Button ──
          if (!_isDownloading && !_isComplete)
            TextButton(
              onPressed: widget.onSkip ?? () => Navigator.pop(context),
              child: Text(
                texts['skip']!,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeaturePill(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
