// lib/services/local_llm_service.dart
//
// On-device Offline AI service powered by llama_flutter_android (native C++ llama.cpp)
// with ARM64 NEON and Vulkan GPU acceleration — ported from Rakshak architecture.
//
// 3-tier response fallback:
//   Tier 0: Agronomy Knowledge Base (instant, <30KB, bundled in APK)
//   Tier 1: Native SLM — Qwen 2.5 0.5B/1.5B Instruct (downloaded on demand)
//   Tier 2: Template reports (always available)
//
// The SLM is OPTIONAL — the app works fully offline without it.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_user.dart';
import '../models/scan_result.dart';
import 'agronomy_kb_service.dart';
import 'supabase_service.dart';
import 'language_service.dart';

class LocalLLMService extends ChangeNotifier {
  static final LocalLLMService _instance = LocalLLMService._internal();
  factory LocalLLMService() => _instance;
  LocalLLMService._internal();

  // ── Model Configuration ─────────────────────────────────────────────────
  // Qwen 2.5 0.5B Instruct Q4_K_M — ultra-fast, ideal for basic plant Q&A (~398MB)
  static const String _defaultModelId = 'qwen-2.5-0.5b';
  static const String _defaultModelFileName = 'qwen2.5-0.5b-instruct-q4_k_m.gguf';
  static const String _defaultModelUrl =
      'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf';
  static const int _defaultModelSizeBytes = 398000000; // ~398MB

  // Qwen 2.5 1.5B Instruct Q4_K_M — higher quality, multilingual reasoning (~1.1GB)
  static const String _largeModelId = 'qwen-2.5-1.5b';
  static const String _largeModelFileName = 'qwen2.5-1.5b-instruct-q4_k_m.gguf';
  static const String _largeModelUrl =
      'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf';
  static const int _largeModelSizeBytes = 1120000000; // ~1.1GB

  static const String _modelVersionKey = 'local_llm_version';
  static const String _activeModelKey = 'local_llm_active_model';
  static const String _userContextKey = 'offline_user_context';

  // ── State ───────────────────────────────────────────────────────────────
  LlamaController? _controller;
  bool _isModelLoaded = false;
  bool _isDownloading = false;
  bool _isGenerating = false;
  double _downloadProgress = 0.0;
  String? _modelPath;
  String _activeModelId = _defaultModelId;
  GpuInfo? _cachedGpuInfo;
  http.Client? _httpClient;

  bool get isModelLoaded => _isModelLoaded;
  bool get isDownloading => _isDownloading;
  bool get isGenerating => _isGenerating;
  double get downloadProgress => _downloadProgress;
  bool get isModelAvailable => _modelPath != null && File(_modelPath!).existsSync();
  String get activeModelId => _activeModelId;
  GpuInfo? get cachedGpuInfo => _cachedGpuInfo;

  /// Available model options for the UI
  static const List<Map<String, dynamic>> availableModels = [
    {
      'id': _defaultModelId,
      'name': 'Qwen 2.5 0.5B Instruct',
      'description': 'Ultra-fast plant Q&A. Runs on any phone.',
      'size_mb': 398,
      'fileName': _defaultModelFileName,
      'url': _defaultModelUrl,
      'sizeBytes': _defaultModelSizeBytes,
    },
    {
      'id': _largeModelId,
      'name': 'Qwen 2.5 1.5B Instruct',
      'description': 'Higher quality, multilingual Hindi/Bengali support.',
      'size_mb': 1120,
      'fileName': _largeModelFileName,
      'url': _largeModelUrl,
      'sizeBytes': _largeModelSizeBytes,
    },
  ];

  // ═══════════════════════════════════════════════════════════════════════
  // USER CONTEXT INJECTION
  // ═══════════════════════════════════════════════════════════════════════

  /// Cache user profile + recent scan history for offline LLM context.
  Future<void> feedUserContext(AppUser user, List<ScanResult> recentScans) async {
    final scanSummaries = recentScans.take(20).map((s) {
      return '- ${s.plantName}: ${s.diseaseName} (Health: ${s.healthScore}/100, ${s.scannedAt.toString().substring(0, 10)})';
    }).join('\n');

    final context = {
      'name': user.displayName,
      'tier': user.subscriptionTier,
      'location': user.location ?? 'Unknown',
      'garden_type': user.gardenType ?? 'Unknown',
      'bio': user.bio ?? '',
      'level': user.level,
      'level_title': user.levelTitle,
      'xp': user.xp,
      'scan_count': user.scanCount,
      'badges': user.badges.join(', '),
      'recent_scans': scanSummaries,
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userContextKey, jsonEncode(context));
    debugPrint('📋 Cached user context for offline LLM: ${user.displayName}');
  }

  /// Build an enriched system prompt with cached user context.
  Future<String> _buildSystemPrompt() async {
    String userBlock = 'User Tier: Free';

    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(_userContextKey);

    if (cachedJson != null) {
      try {
        final ctx = jsonDecode(cachedJson) as Map<String, dynamic>;
        final name = ctx['name'] ?? 'User';
        final tier = ctx['tier'] ?? 'free';
        final location = ctx['location'] ?? 'Unknown';
        final gardenType = ctx['garden_type'] ?? 'Unknown';
        final level = ctx['level_title'] ?? 'Seedling';
        final scanCount = ctx['scan_count'] ?? 0;
        final recentScans = ctx['recent_scans'] ?? 'No recent scans';

        userBlock = '''User Profile:
Name: $name
Subscription: $tier
Location: $location
Garden Type: $gardenType
Experience: $level ($scanCount total scans)

Recent Scan History:
$recentScans''';
      } catch (_) {}
    } else {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        try {
          final user = await SupabaseService().getUser(uid);
          if (user != null) {
            final isFarm = user.isFarm;
            final isPro = user.isPro;
            String tier = isFarm ? 'Farm' : (isPro ? 'Pro' : 'Free (Basic)');
            userBlock = 'User Tier: $tier\nDisplay Name: ${user.displayName}';
          }
        } catch (_) {}
      }
    }

    return '''You are PhytoLens AI, an expert plant health advisor.
You are given the user's app data, database records, and profile below. You MUST read this data carefully and use it to personalize your advice and suggestions.

CRITICAL INSTRUCTIONS:
1. Provide actionable advice and tailored suggestions based on the user's specific garden type, location, and recent scan history.
2. Be extremely brief and concise. Keep responses to 1-3 sentences unless specifically asked for details.
3. NEVER output code, programming syntax, HTML tags, or technical markup.
4. NEVER wrap your response in code fences or backticks.
5. Use simple, conversational language. Write like a friendly expert, not a computer.
6. Use Markdown formatting (bolding **, bullet points -, numbered lists) to make your response highly organized and easy to read. Highlight key terms.
7. ${LanguageService().aiLanguageDirective}

USER DATABASE & APP CONTEXT:
$userBlock

Give actionable advice and personalized suggestions. Be encouraging. Use simple words.''';
  }

  // ═══════════════════════════════════════════════════════════════════════
  // RESPONSE CLEANING
  // ═══════════════════════════════════════════════════════════════════════

  /// Clean raw LLM output to remove code leakage and formatting artifacts.
  static String cleanResponse(String raw) {
    var text = raw;

    // Strip <think>...</think> blocks (reasoning model leakage)
    text = text.replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'</?think>', caseSensitive: false), '');

    // Strip stray HTML-like tags (but preserve markdown bold/italic)
    text = text.replaceAll(RegExp(r'<(?!/?(?:b|i|em|strong)>)[^>]+>', caseSensitive: false), '');

    // Strip code fences wrapping non-code text
    text = text.replaceAllMapped(
      RegExp(r'```(?:\w*)\n?([\s\S]*?)```'),
      (match) {
        final content = match.group(1) ?? '';
        final looksLikeCode = RegExp(r'(?:def |class |import |function |var |const |let |return |if \(|for \()').hasMatch(content);
        return looksLikeCode ? match.group(0)! : content;
      },
    );

    // Strip lone backticks wrapping normal words
    text = text.replaceAllMapped(
      RegExp(r'`([^`\n]{1,50})`'),
      (match) {
        final inner = match.group(1) ?? '';
        final isTechnical = RegExp(r'[_\.\(\)\[\]{}=<>]').hasMatch(inner);
        return isTechnical ? match.group(0)! : inner;
      },
    );

    // Clean up excessive whitespace
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    text = text.trim();

    return text;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // GPU DETECTION
  // ═══════════════════════════════════════════════════════════════════════

  /// Detect GPU capabilities via Vulkan for hardware acceleration
  Future<GpuInfo?> detectGpu() async {
    try {
      _controller ??= LlamaController();
      _cachedGpuInfo = await _controller!.detectGpu();
      return _cachedGpuInfo;
    } catch (_) {
      return null;
    }
  }

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

  /// Get model config by ID
  Map<String, dynamic> _getModelConfig(String modelId) {
    return availableModels.firstWhere(
      (m) => m['id'] == modelId,
      orElse: () => availableModels.first,
    );
  }

  /// Returns the full path to a model file
  Future<String> _getModelFilePath(String modelId) async {
    final dir = await _getModelDir();
    final config = _getModelConfig(modelId);
    return '${dir.path}/${config['fileName']}';
  }

  /// Check if a specific model is downloaded and valid
  Future<bool> isModelDownloaded({String? modelId}) async {
    final id = modelId ?? _activeModelId;
    try {
      final path = await _getModelFilePath(id);
      final file = File(path);
      if (await file.exists()) {
        final size = await file.length();
        final config = _getModelConfig(id);
        // Model should be at least 90% of expected size to be valid
        if (size >= (config['sizeBytes'] as int) * 0.90) {
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

  /// Check if a partial download exists and return its size in bytes.
  Future<int> getPartialDownloadSizeBytes({String? modelId}) async {
    final id = modelId ?? _activeModelId;
    try {
      final filePath = await _getModelFilePath(id);
      final tempFile = File('$filePath.download');
      if (await tempFile.exists()) {
        return await tempFile.length();
      }
    } catch (_) {}
    return 0;
  }

  /// Download a model with progress callback.
  /// Supports resumption from partial downloads automatically.
  Future<bool> downloadModel({
    String? modelId,
    required Function(double progress) onProgress,
    Function(String error)? onError,
  }) async {
    if (_isDownloading) return false;
    final id = modelId ?? _activeModelId;
    final config = _getModelConfig(id);

    _isDownloading = true;
    _downloadProgress = 0.0;
    notifyListeners();

    try {
      final filePath = await _getModelFilePath(id);
      final tempPath = '$filePath.download';
      final tempFile = File(tempPath);

      // Resume download if partial file exists
      int downloadedBytes = 0;
      if (await tempFile.exists()) {
        downloadedBytes = await tempFile.length();
        debugPrint('📥 Resuming download from ${(downloadedBytes / 1024 / 1024).toStringAsFixed(1)} MB');
      }

      _httpClient = http.Client();
      final request = http.Request('GET', Uri.parse(config['url'] as String));
      if (downloadedBytes > 0) {
        request.headers['Range'] = 'bytes=$downloadedBytes-';
      }

      final response = await _httpClient!.send(request);

      // Check if server supports range requests
      if (downloadedBytes > 0 && response.statusCode == 200) {
        downloadedBytes = 0;
        if (await tempFile.exists()) await tempFile.delete();
      }

      final expectedSize = config['sizeBytes'] as int;
      final totalBytes = downloadedBytes +
          (response.contentLength ?? (expectedSize - downloadedBytes));

      final sink = tempFile.openWrite(
        mode: downloadedBytes > 0 && response.statusCode == 206
            ? FileMode.append
            : FileMode.write,
      );

      await for (final chunk in response.stream) {
        if (!_isDownloading) {
          await sink.flush();
          await sink.close();
          notifyListeners();
          return false;
        }
        sink.add(chunk);
        downloadedBytes += chunk.length;
        _downloadProgress = (downloadedBytes / totalBytes).clamp(0.0, 1.0);
        onProgress(_downloadProgress);
        notifyListeners();
      }

      await sink.flush();
      await sink.close();
      _httpClient?.close();
      _httpClient = null;

      // Validate downloaded file
      final downloadedSize = await tempFile.length();
      if (downloadedSize < expectedSize * 0.90) {
        await tempFile.delete();
        onError?.call('Download incomplete. Please try again.');
        _isDownloading = false;
        notifyListeners();
        return false;
      }

      // Move temp file to final location
      await tempFile.rename(filePath);
      _modelPath = filePath;
      _activeModelId = id;

      // Save version tag
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modelVersionKey, 'qwen-v1');
      await prefs.setString(_activeModelKey, id);

      _isDownloading = false;
      _downloadProgress = 1.0;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Model download error: $e');
      onError?.call('Download failed. Check your internet connection.');
      _isDownloading = false;
      _httpClient?.close();
      _httpClient = null;
      notifyListeners();
      return false;
    }
  }

  /// Cancel an in-progress download
  void cancelDownload() {
    if (!_isDownloading) return;
    _isDownloading = false;
    _httpClient?.close();
    _httpClient = null;
    debugPrint('⏹️ Download cancelled. Partial file preserved for resume.');
    notifyListeners();
  }

  /// Delete the partial download file to start fresh
  Future<void> cleanPartialDownload({String? modelId}) async {
    final id = modelId ?? _activeModelId;
    try {
      final filePath = await _getModelFilePath(id);
      final tempFile = File('$filePath.download');
      if (await tempFile.exists()) {
        await tempFile.delete();
        debugPrint('🧹 Cleaned partial download file.');
      }
    } catch (e) {
      debugPrint('Clean partial error: $e');
    }
    notifyListeners();
  }

  /// Get the model file size label for display
  String get modelSizeLabel {
    final config = _getModelConfig(_activeModelId);
    return '${((config['sizeBytes'] as int) / (1024 * 1024)).round()} MB';
  }

  /// Delete a downloaded model
  Future<void> deleteModel({String? modelId}) async {
    final id = modelId ?? _activeModelId;
    if (_isModelLoaded && _activeModelId == id) {
      await unloadModel();
    }
    try {
      final path = await _getModelFilePath(id);
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      await cleanPartialDownload(modelId: id);
      if (id == _activeModelId) {
        _modelPath = null;
      }
    } catch (e) {
      debugPrint('Model delete error: $e');
    }
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // MODEL LOADING (Native C++ llama.cpp via LlamaController)
  // ═══════════════════════════════════════════════════════════════════════

  /// Load the model into native C++ llama.cpp memory.
  Future<bool> loadModel({String? modelId}) async {
    final id = modelId ?? _activeModelId;
    if (_isModelLoaded && _activeModelId == id) return true;

    try {
      final downloaded = await isModelDownloaded(modelId: id);
      if (!downloaded) return false;

      // Unload previous model if switching
      if (_isModelLoaded) {
        await unloadModel();
      }

      _controller ??= LlamaController();

      // Auto-detect GPU layers for hardware acceleration
      int? gpuLayers;
      try {
        final gpu = await detectGpu();
        if (gpu != null && gpu.vulkanSupported && gpu.recommendedGpuLayers > 0) {
          gpuLayers = gpu.recommendedGpuLayers;
          debugPrint('🖥️ Vulkan GPU detected, using $gpuLayers layers');
        }
      } catch (_) {}

      await _controller!.loadModel(
        modelPath: _modelPath!,
        threads: Platform.numberOfProcessors ~/ 2,
        contextSize: 2048,
        gpuLayers: gpuLayers,
      );

      _isModelLoaded = true;
      _activeModelId = id;
      debugPrint('✅ Native LLM loaded: $_modelPath (Vulkan: ${gpuLayers != null})');

      // Persist active model preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeModelKey, id);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Model load error: $e');
      _isModelLoaded = false;
      return false;
    }
  }

  /// Unload the model from native memory
  Future<void> unloadModel() async {
    if (!_isModelLoaded || _controller == null) return;
    try {
      await _controller?.dispose();
    } catch (_) {}
    _controller = null;
    _isModelLoaded = false;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TIER-AWARE DISEASE REPORTS (Offline)
  // Priority: Agronomy KB (instant) → SLM (if loaded) → Template fallback
  // ═══════════════════════════════════════════════════════════════════════

  final AgronomyKBService _agronomyKB = AgronomyKBService();

  /// Generate an offline disease report based on the user's subscription tier.
  Future<String> getTieredAdvice({
    required String tier,
    required String plantName,
    required String diseaseName,
    required int healthScore,
    int? severityPercent,
    String? tfliteLabel,
  }) async {
    final String reportType;
    switch (tier.toLowerCase()) {
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

    final hasKBEntry = tfliteLabel != null
        ? _agronomyKB.lookup(tfliteLabel) != null
        : _agronomyKB.lookupByNames(plantName, diseaseName) != null;

    if (hasKBEntry) {
      debugPrint('📚 Agronomy KB: Instant offline report for $diseaseName');
      return kbReport;
    }

    // ── TIER 1: Native SLM (if loaded) ───────────────────────────────────
    if (_isModelLoaded) {
      debugPrint('🤖 Native SLM: Generating freeform report for unknown disease');
      final severity = severityPercent != null ? '\nSeverity: $severityPercent%' : '';
      final String prompt;

      final lang = LanguageService().language.nativeName;
      switch (reportType) {
        case 'full':
          prompt = 'Plant: $plantName\nDisease: $diseaseName\nHealth Score: $healthScore/100$severity\n\nProvide a COMPREHENSIVE crop health report with disease identification, treatment steps, organic remedies, chemical options, prevention calendar, and yield impact. Use clear markdown tables and bullet points. (You are generating a FARM tier report, be extremely comprehensive and professional).\n\nIMPORTANT: Respond EXCLUSIVELY in $lang.';
          break;
        case 'detailed':
          prompt = 'Plant: $plantName\nDisease: $diseaseName\nHealth Score: $healthScore/100$severity\n\nExplain this disease, why it happens, treatment steps, prevention, and organic remedies. Use clear markdown headers and bullet points. (You are generating a PRO tier report, be detailed and structured).\n\nIMPORTANT: Respond EXCLUSIVELY in $lang.';
          break;
        default:
          prompt = 'Plant: $plantName\nDisease: $diseaseName\nHealth Score: $healthScore/100$severity\n\nGive a 2-3 sentence summary and the most important action to take now. (You are generating a FREE tier report, keep it brief and simple).\n\nIMPORTANT: Respond EXCLUSIVELY in $lang.';
      }

      try {
        final raw = await _runInference(prompt);
        return cleanResponse(raw);
      } catch (e) {
        debugPrint('SLM inference failed, using KB fallback: $e');
      }
    }

    // ── TIER 2: Template / Generic KB fallback ───────────────────────────
    return kbReport;
  }

  /// Run actual LLM inference via native llama.cpp
  Future<String> _runInference(String userPrompt) async {
    if (!_isModelLoaded || _controller == null) {
      return 'AI model not loaded. Please download the AI model from Settings.';
    }

    _isGenerating = true;

    try {
      final sysPrompt = await _buildSystemPrompt();

      final buffer = StringBuffer();
      final stream = _controller!.generateChat(
        messages: [
          ChatMessage(role: 'system', content: sysPrompt),
          ChatMessage(role: 'user', content: userPrompt),
        ],
        maxTokens: 512,
        temperature: 0.7,
        topP: 0.9,
      );

      await for (final token in stream) {
        buffer.write(token);
      }

      final text = buffer.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }

      return _templateReport(
        plantName: 'Plant',
        diseaseName: 'Disease',
        healthScore: 50,
        reportType: 'basic',
      );
    } catch (e) {
      debugPrint('Native LLM inference error: $e');
      return 'Could not generate report. The AI model may need more memory.';
    } finally {
      _isGenerating = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STREAMING CHAT (Offline) — Native C++ token streaming
  // ═══════════════════════════════════════════════════════════════════════

  /// Stream chat responses token-by-token for real-time UI
  Stream<String> streamChat(
    String userMessage,
    List<Map<String, String>> history,
  ) async* {
    if (!_isModelLoaded || _controller == null) {
      yield '📱 The AI model is not ready yet. ';
      yield 'Please download it from the Settings page. ';
      yield 'Once downloaded, you can chat offline anytime!';
      return;
    }

    _isGenerating = true;

    try {
      final sysPrompt = await _buildSystemPrompt();

      // Build messages list for generateChat
      final messages = <ChatMessage>[
        ChatMessage(role: 'system', content: sysPrompt),
      ];

      // Add conversation history
      for (final msg in history) {
        final role = msg['role'] ?? 'user';
        final content = msg['content'] ?? '';
        if (content.isNotEmpty) {
          messages.add(ChatMessage(
            role: role == 'assistant' ? 'assistant' : 'user',
            content: content,
          ));
        }
      }

      // Add current user message
      final lang = LanguageService().language.nativeName;
      messages.add(ChatMessage(role: 'user', content: '$userMessage\n\n[Respond EXCLUSIVELY in $lang]'));

      // Stream tokens directly from native C++ llama.cpp
      final stream = _controller!.generateChat(
        messages: messages,
        maxTokens: 512,
        temperature: 0.7,
        topP: 0.9,
      );

      await for (final token in stream) {
        yield token;
      }
    } catch (e) {
      debugPrint('Native LLM stream error: $e');
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
    return cleanResponse(buffer.toString());
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TEMPLATE FALLBACK REPORTS
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
  Future<double> getModelSizeMB({String? modelId}) async {
    final id = modelId ?? _activeModelId;
    try {
      final path = await _getModelFilePath(id);
      final file = File(path);
      if (await file.exists()) {
        return (await file.length()) / (1024 * 1024);
      }
    } catch (_) {}
    return 0;
  }

  @override
  void dispose() {
    unloadModel();
    _httpClient?.close();
    super.dispose();
  }
}
