// lib/services/local_llm_service.dart
//
// On-device Offline AI service with 2-tier fallback:
//   Tier 0: Agronomy Knowledge Base (instant, <30KB, bundled in APK)
//   Tier 1: Optional SLM — Gemma 2B Q4_K_M (~1.5GB, downloaded on demand)
//
// The SLM is OPTIONAL — the app works fully offline without it.
// The SLM enhances chat and provides freeform answers beyond the KB.

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:fllama/fllama.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'agronomy_kb_service.dart';

class LocalLLMService {
  static final LocalLLMService _instance = LocalLLMService._internal();
  factory LocalLLMService() => _instance;
  LocalLLMService._internal();

  // ── Model Configuration ─────────────────────────────────────────────────
  // Gemma 2B Instruct Q4_K_M — best quality/size ratio for agriculture
  static const String _modelFileName = 'gemma-2b-it-q4_k_m.gguf';
  static const String _modelUrl =
      'https://huggingface.co/google/gemma-2b-it-GGUF/resolve/main/gemma-2b-it-q4_k_m.gguf';
  static const int _modelSizeBytes = 1500000000; // ~1.5GB approximate
  static const String _modelVersionKey = 'local_llm_version';
  static const String _currentVersion = 'gemma-2b-it-q4_k_m-v1';

  // ── State ───────────────────────────────────────────────────────────────
  bool _isModelLoaded = false;
  bool _isDownloading = false;
  bool _isGenerating = false;
  double _downloadProgress = 0.0;
  String? _modelPath;
  double? _contextId;

  bool get isModelLoaded => _isModelLoaded;
  bool get isDownloading => _isDownloading;
  bool get isGenerating => _isGenerating;
  double get downloadProgress => _downloadProgress;
  bool get isModelAvailable => _modelPath != null && File(_modelPath!).existsSync();

  // ── System Prompt ───────────────────────────────────────────────────────
  static const String _systemPrompt = '''You are PhytoLens AI, an expert plant health advisor.
You help farmers and gardeners understand plant diseases and treatments.
Always respond in simple, practical language that an uneducated farmer can understand.
If the user writes in Hindi, respond in Hindi. If in any other language, respond in that language.
Give actionable, step-by-step advice. Be encouraging and supportive.
Keep responses concise and easy to understand.
Use simple words, avoid technical jargon. Think of explaining to a friend who grows crops.''';

  // ═══════════════════════════════════════════════════════════════════════
  // MODEL MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════

  /// Returns the directory where models are stored
  Future<Directory> _getModelDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${appDir.path}/ai_models');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    return modelDir;
  }

  /// Returns the full path to the model file (whether it exists or not)
  Future<String> _getModelFilePath() async {
    final dir = await _getModelDir();
    return '${dir.path}/$_modelFileName';
  }

  /// Check if the model is already downloaded and valid
  Future<bool> isModelDownloaded() async {
    try {
      final path = await _getModelFilePath();
      final file = File(path);
      if (await file.exists()) {
        final size = await file.length();
        // Model should be at least 1GB to be valid
        if (size > 1000000000) {
          _modelPath = path;
          return true;
        }
        // Corrupted / incomplete download — delete it
        await file.delete();
      }
      return false;
    } catch (e) {
      debugPrint('Model check error: $e');
      return false;
    }
  }

  /// Download the model with progress callback
  /// [onProgress] receives a value between 0.0 and 1.0
  Future<bool> downloadModel({
    required Function(double progress) onProgress,
    Function(String error)? onError,
  }) async {
    if (_isDownloading) return false;
    _isDownloading = true;
    _downloadProgress = 0.0;

    try {
      final filePath = await _getModelFilePath();
      final tempPath = '$filePath.download';
      final tempFile = File(tempPath);

      // Resume download if partial file exists
      int downloadedBytes = 0;
      if (await tempFile.exists()) {
        downloadedBytes = await tempFile.length();
      }

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(_modelUrl));
      if (downloadedBytes > 0) {
        request.headers['Range'] = 'bytes=$downloadedBytes-';
      }

      final response = await client.send(request);

      // Get total size
      final totalBytes = downloadedBytes +
          (response.contentLength ?? (_modelSizeBytes - downloadedBytes));

      final sink = tempFile.openWrite(mode: FileMode.append);

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        _downloadProgress = (downloadedBytes / totalBytes).clamp(0.0, 1.0);
        onProgress(_downloadProgress);
      }

      await sink.flush();
      await sink.close();
      client.close();

      // Validate downloaded file
      final downloadedSize = await tempFile.length();
      if (downloadedSize < 1000000000) {
        await tempFile.delete();
        onError?.call('Download incomplete. Please try again.');
        _isDownloading = false;
        return false;
      }

      // Move temp file to final location
      await tempFile.rename(filePath);
      _modelPath = filePath;

      // Save version tag
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modelVersionKey, _currentVersion);

      _isDownloading = false;
      _downloadProgress = 1.0;
      return true;
    } catch (e) {
      debugPrint('Model download error: $e');
      onError?.call('Download failed. Check your internet connection.');
      _isDownloading = false;
      return false;
    }
  }

  /// Get the model file size for display (in MB)
  String get modelSizeLabel => '${(_modelSizeBytes / (1024 * 1024)).round()} MB';

  /// Delete the downloaded model to free storage
  Future<void> deleteModel() async {
    _isModelLoaded = false;
    _modelPath = null;
    try {
      final path = await _getModelFilePath();
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_modelVersionKey);
    } catch (e) {
      debugPrint('Model delete error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // MODEL LOADING (simulated until fllama package integration)
  // ═══════════════════════════════════════════════════════════════════════

  /// Load the model into memory for inference.
  /// This should be called once at app startup after confirming download.
  Future<bool> loadModel() async {
    if (_isModelLoaded) return true;

    try {
      final downloaded = await isModelDownloaded();
      if (!downloaded) return false;

      final context = await Fllama.instance()?.initContext(
        _modelPath!,
        nCtx: 2048,
        nThreads: Platform.numberOfProcessors ~/ 2,
      );
      
      _contextId = double.tryParse(context?["contextId"]?.toString() ?? "");
      
      if (_contextId != null) {
        _isModelLoaded = true;
        debugPrint('✅ Local LLM loaded: $_modelPath, Context ID: $_contextId');
        return true;
      }
      
      debugPrint('Model load failed: Invalid context ID');
      return false;
    } catch (e) {
      debugPrint('Model load error: $e');
      _isModelLoaded = false;
      return false;
    }
  }

  /// Unload the model from memory to free resources
  void unloadModel() {
    if (_contextId != null) {
      Fllama.instance()?.releaseContext(_contextId!);
      _contextId = null;
    }
    _isModelLoaded = false;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TIER-AWARE DISEASE REPORTS (Offline)
  // Priority: Agronomy KB (instant) → SLM (if loaded) → Template fallback
  // ═══════════════════════════════════════════════════════════════════════

  final AgronomyKBService _agronomyKB = AgronomyKBService();

  /// Generate an offline disease report based on the user's subscription tier.
  /// Uses Agronomy KB first (instant), SLM second (if loaded), template last.
  Future<String> getTieredAdvice({
    required String tier,
    required String plantName,
    required String diseaseName,
    required int healthScore,
    int? severityPercent,
    String? tfliteLabel,
  }) async {
    final String reportType;
    switch (tier) {
      case 'farm':
        reportType = 'full';
        break;
      case 'pro':
        reportType = 'detailed';
        break;
      default:
        reportType = 'basic';
    }

    return _generateReport(
      plantName: plantName,
      diseaseName: diseaseName,
      healthScore: healthScore,
      severityPercent: severityPercent,
      reportType: reportType,
      tfliteLabel: tfliteLabel,
    );
  }

  Future<String> _generateReport({
    required String plantName,
    required String diseaseName,
    required int healthScore,
    int? severityPercent,
    required String reportType,
    String? tfliteLabel,
  }) async {
    // ── TIER 0: Agronomy Knowledge Base (instant, <1ms) ──────────────────
    final kbReport = _agronomyKB.generateReport(
      plantName: plantName,
      diseaseName: diseaseName,
      healthScore: healthScore,
      severityPercent: severityPercent,
      reportType: reportType,
      tfliteLabel: tfliteLabel,
    );

    // If Agronomy KB has a verified entry, use it directly — it's faster
    // and more accurate than SLM for known diseases.
    final hasKBEntry = tfliteLabel != null
        ? _agronomyKB.lookup(tfliteLabel) != null
        : _agronomyKB.lookupByNames(plantName, diseaseName) != null;

    if (hasKBEntry) {
      debugPrint('📚 Agronomy KB: Instant offline report for $diseaseName');
      return kbReport;
    }

    // ── TIER 1: SLM (optional, if model is downloaded and loaded) ────────
    if (_isModelLoaded) {
      debugPrint('🤖 SLM: Generating freeform report for unknown disease');
      final severity = severityPercent != null ? '\nSeverity: $severityPercent%' : '';
      final String prompt;

      switch (reportType) {
        case 'full':
          prompt = 'Plant: $plantName\nDisease: $diseaseName\nHealth Score: $healthScore/100$severity\n\nProvide a COMPREHENSIVE crop health report with disease identification, treatment steps, organic remedies, chemical options, prevention calendar, and yield impact. Use simple language.';
          break;
        case 'detailed':
          prompt = 'Plant: $plantName\nDisease: $diseaseName\nHealth Score: $healthScore/100$severity\n\nExplain this disease, why it happens, treatment steps, prevention, and organic remedies. Be concise and practical.';
          break;
        default:
          prompt = 'Plant: $plantName\nDisease: $diseaseName\nHealth Score: $healthScore/100$severity\n\nGive a 2-3 sentence summary and the most important action to take now.';
      }

      try {
        return await _runInference(prompt);
      } catch (e) {
        debugPrint('SLM inference failed, using KB fallback: $e');
      }
    }

    // ── TIER 2: Template / Generic KB fallback ───────────────────────────
    return kbReport;
  }

  /// Run actual LLM inference
  Future<String> _runInference(String userPrompt) async {
    if (!_isModelLoaded) {
      return 'AI model not loaded. Please download the AI model from Settings.';
    }

    _isGenerating = true;

    try {
      final prompt = '<start_of_turn>system\\n$_systemPrompt<end_of_turn>\\n'
                     '<start_of_turn>user\\n$userPrompt<end_of_turn>\\n'
                     '<start_of_turn>model\\n';
                     
      final result = await Fllama.instance()?.completion(
        _contextId!,
        prompt: prompt,
        temperature: 0.7,
        topP: 0.9,
        stop: ['<end_of_turn>'],
      );
      
      final text = result?['text'] as String?;
      if (text != null && text.isNotEmpty) {
        return text;
      }

      return _templateReport(
        plantName: 'Plant',
        diseaseName: 'Disease',
        healthScore: 50,
        reportType: 'basic',
      );
    } catch (e) {
      debugPrint('Local LLM inference error: $e');
      return 'Could not generate report. The AI model may need more memory.';
    } finally {
      _isGenerating = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STREAMING CHAT (Offline)
  // ═══════════════════════════════════════════════════════════════════════

  /// Stream chat responses token-by-token for real-time UI
  Stream<String> streamChat(
    String userMessage,
    List<Map<String, String>> history,
  ) async* {
    if (!_isModelLoaded) {
      yield '📱 The AI model is not ready yet. ';
      yield 'Please download it from the Settings page. ';
      yield 'Once downloaded, you can chat offline anytime!';
      return;
    }

    _isGenerating = true;

    try {
      // Build conversation context
      final StringBuffer conversationBuf = StringBuffer();
      conversationBuf.writeln('<start_of_turn>system');
      conversationBuf.writeln(_systemPrompt);
      conversationBuf.writeln('<end_of_turn>');

      for (final msg in history) {
        final role = msg['role'] == 'assistant' ? 'model' : 'user';
        conversationBuf.writeln('<start_of_turn>$role');
        conversationBuf.writeln(msg['content'] ?? '');
        conversationBuf.writeln('<end_of_turn>');
      }

      conversationBuf.writeln('<start_of_turn>user');
      conversationBuf.writeln(userMessage);
      conversationBuf.writeln('<end_of_turn>');
      conversationBuf.writeln('<start_of_turn>model');

      final controller = StreamController<String>();
      StreamSubscription? fllamaSub;

      fllamaSub = Fllama.instance()?.onTokenStream?.listen((data) {
        if (data['function'] == 'completion') {
          final token = data['result']['token'];
          if (token == '<end_of_turn>' || token == null) {
            fllamaSub?.cancel();
            controller.close();
          } else {
            controller.add(token);
          }
        }
      });

      Fllama.instance()?.completion(
        _contextId!,
        prompt: conversationBuf.toString(),
        temperature: 0.7,
        topP: 0.9,
        emitRealtimeCompletion: true,
        stop: ['<end_of_turn>'],
      ).then((_) {
        if (!controller.isClosed) {
          controller.close();
          fllamaSub?.cancel();
        }
      });
      
      yield* controller.stream;
    } catch (e) {
      debugPrint('Local LLM stream error: $e');
      yield '⚠️ Sorry, the on-device AI ran into an issue. ';
      yield 'This may happen if your phone is low on memory. ';
      yield 'Try closing other apps and trying again.';
    } finally {
      _isGenerating = false;
    }
  }

  /// Non-streaming chat (for simple queries)
  Future<String> chat(
    String userMessage,
    List<Map<String, String>> history,
  ) async {
    final buffer = StringBuffer();
    await for (final chunk in streamChat(userMessage, history)) {
      buffer.write(chunk);
    }
    return buffer.toString();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TEMPLATE FALLBACK REPORTS
  // Used when LLM model is not yet downloaded — still provides value.
  // ═══════════════════════════════════════════════════════════════════════

  String _templateReport({
    required String plantName,
    required String diseaseName,
    required int healthScore,
    int? severityPercent,
    required String reportType,
  }) {
    final isHealthy = diseaseName.toLowerCase().contains('healthy');
    final severity = severityPercent != null ? ' (Severity: $severityPercent%)' : '';

    if (isHealthy) {
      return '✅ **$plantName** looks healthy! Health score: $healthScore/100.\n\n'
          'Keep doing what you\'re doing — good watering, sunlight, and soil care. '
          'Scan regularly to catch any issues early.';
    }

    if (reportType == 'basic') {
      return '⚠️ **$plantName** may have **$diseaseName**$severity. '
          'Health score: $healthScore/100.\n\n'
          '**What to do now:** Remove affected leaves carefully. '
          'Keep the plant well-spaced for air circulation. '
          'Consider an organic fungicide spray if condition worsens.\n\n'
          '_Connect to the internet for a detailed AI-powered treatment plan._';
    }

    if (reportType == 'detailed') {
      return '## $diseaseName on $plantName$severity\n\n'
          '**Health Score:** $healthScore/100\n\n'
          '### What is this?\n'
          '$diseaseName is a common plant disease that affects $plantName. '
          'It typically appears as spots, discoloration, or wilting on leaves.\n\n'
          '### Why it happens\n'
          '- Excess moisture or humidity\n'
          '- Poor air circulation between plants\n'
          '- Contaminated soil or water\n'
          '- Stress from temperature changes\n\n'
          '### Treatment Steps\n'
          '1. **Remove** affected leaves immediately and dispose safely (don\'t compost)\n'
          '2. **Improve** spacing between plants for better airflow\n'
          '3. **Water** at the base — avoid wetting leaves\n'
          '4. **Apply** neem oil or baking soda spray (1 tsp per litre water)\n'
          '5. **Monitor** daily for 7 days\n\n'
          '### Prevention\n'
          '- Rotate crops each season\n'
          '- Use disease-resistant varieties\n'
          '- Maintain good drainage\n\n'
          '### Organic Remedies\n'
          '- **Neem oil spray**: 5ml per litre, spray every 7 days\n'
          '- **Baking soda**: 1 tsp + few drops dish soap per litre\n'
          '- **Garlic extract**: Natural antifungal\n\n'
          '_📱 This is an offline report. Connect to the internet for AI-enhanced analysis._';
    }

    // Full (Farm tier)
    return '# Comprehensive Crop Health Report\n\n'
        '## $diseaseName on $plantName$severity\n'
        '**Health Score:** $healthScore/100\n\n'
        '---\n\n'
        '### 1. Disease Identification\n'
        '$diseaseName is a plant disease affecting $plantName. '
        'Look for characteristic spots, lesions, or discoloration on leaves. '
        'Confirm by checking if symptoms match on multiple leaves.\n\n'
        '### 2. Root Cause Analysis\n'
        '- **Environmental:** High humidity, poor ventilation, excessive rainfall\n'
        '- **Soil:** Poor drainage, nutrient deficiency, contaminated compost\n'
        '- **Spread:** Wind, water splash, contaminated tools, insects\n\n'
        '### 3. Immediate Treatment Plan\n'
        '1. ⚡ **Isolate** affected plants from healthy ones\n'
        '2. ✂️ **Prune** all diseased leaves/branches — sterilize tools between cuts\n'
        '3. 💧 **Adjust watering** — water at base only, reduce frequency\n'
        '4. 🧴 **Apply treatment** — see organic or chemical options below\n'
        '5. 📋 **Monitor** — check daily for 14 days\n'
        '6. 🔄 **Re-assess** — if no improvement in 7 days, escalate treatment\n\n'
        '### 4. Organic/Natural Remedies\n'
        '- **Neem oil**: 5ml/litre water, spray every 5-7 days\n'
        '- **Baking soda mix**: 1 tsp soda + 1 tsp oil + few drops soap per litre\n'
        '- **Turmeric paste**: Mix with water, apply to stems\n'
        '- **Companion planting**: Marigold, basil, garlic near affected crops\n'
        '- **Bio-agents**: Trichoderma (available at agri stores)\n\n'
        '### 5. Chemical Treatment Options\n'
        '- **Copper fungicide**: Follow package directions, apply every 10 days\n'
        '- **Mancozeb**: For persistent fungal infections\n'
        '- **Neem-based insecticide**: If pest-driven\n'
        '- ⚠️ Always follow safety guidelines and withdrawal periods\n\n'
        '### 6. Prevention Calendar\n'
        '| Season | Action |\n'
        '|--------|--------|\n'
        '| Pre-season | Treat soil, choose resistant varieties |\n'
        '| Early growth | Mulch, space plants, install drip irrigation |\n'
        '| Mid-season | Weekly inspection, preventive neem spray |\n'
        '| Harvest | Remove all plant debris, compost safely |\n'
        '| Off-season | Soil testing, crop rotation planning |\n\n'
        '### 7. Yield Impact Assessment\n'
        '- **If untreated**: 30-70% crop loss possible\n'
        '- **If treated early**: <10% loss expected\n'
        '- **Key**: Early detection is critical — you\'ve already taken the first step by scanning!\n\n'
        '### 8. Related Conditions\n'
        'When $plantName is weakened by $diseaseName, watch for:\n'
        '- Secondary fungal infections\n'
        '- Pest infestations (aphids, whiteflies attracted to stressed plants)\n'
        '- Nutrient deficiency symptoms\n\n'
        '---\n'
        '_📱 This is an offline report. Connect to the internet for AI-enhanced analysis with the latest disease database._';
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STORAGE INFO
  // ═══════════════════════════════════════════════════════════════════════

  /// Get the size of the downloaded model in MB
  Future<double> getModelSizeMB() async {
    try {
      final path = await _getModelFilePath();
      final file = File(path);
      if (await file.exists()) {
        return (await file.length()) / (1024 * 1024);
      }
    } catch (_) {}
    return 0;
  }

  void dispose() {
    unloadModel();
  }
}
