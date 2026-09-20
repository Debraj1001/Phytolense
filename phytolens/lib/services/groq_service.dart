// lib/services/groq_service.dart
//
// Groq LLM service — TEXT ONLY.
// Used for: AI Chat, Disease Advice Reports, Treatment Recommendations.
// NOT used for plant identification (that's PlantNet + TFLite).

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import '../config/constants.dart';
import 'gemini_service.dart';
import 'sync_service.dart';
import 'local_llm_service.dart';

class GroqService {
  static const String _baseUrl = 'https://api.groq.com/openai/v1';

  final http.Client _client = http.Client();
  final GeminiService _gemini = GeminiService();

  // Multi-key pool: Primary + Fallback keys loaded securely via environment
  static final List<String> _apiKeys = <String>{
    if (Env.groqApiKey.isNotEmpty) Env.groqApiKey,
    if (Env.groqApiKey2.isNotEmpty) Env.groqApiKey2,
    if (Env.groqApiKey3.isNotEmpty) Env.groqApiKey3,
  }.where((k) => k.trim().isNotEmpty).toList();

  static int _currentKeyIndex = 0;

  String get _currentKey => _apiKeys.isNotEmpty ? _apiKeys[_currentKeyIndex % _apiKeys.length] : '';

  void _rotateToNextKey([String? reason]) {
    if (_apiKeys.length <= 1) return;
    final oldIdx = _currentKeyIndex;
    _currentKeyIndex = (_currentKeyIndex + 1) % _apiKeys.length;
    debugPrint('🔄 Groq API Key #$oldIdx exhausted or rate-limited ($reason). Auto-switched to key #${_currentKeyIndex + 1} of ${_apiKeys.length}.');
  }

  static const String _systemPrompt = '''You are PhytoLens AI, an expert plant health advisor.
You help farmers and gardeners understand plant diseases and treatments.
Always respond in simple, practical language.
If the user writes in Hindi, respond in Hindi.
Give actionable, step-by-step advice. Be encouraging and supportive.
Keep responses concise and easy to understand.''';

  // ─── Execute with Automatic Key Rotation & Failover ────────────────────────

  Future<http.Response> _postWithFallback(String endpoint, Map<String, dynamic> body) async {
    int attempts = 0;
    final maxAttempts = _apiKeys.length;

    while (attempts < maxAttempts) {
      final apiKey = _currentKey;
      try {
        final response = await _client.post(
          Uri.parse('$_baseUrl/$endpoint'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'User-Agent': 'PhytoLens/1.0 (dart:io)',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        );

        // If rate limited (429), token invalid/exhausted (401/403), switch key and retry
        if (response.statusCode == 429 || response.statusCode == 401 || response.statusCode == 403) {
          _rotateToNextKey('HTTP ${response.statusCode}');
          attempts++;
          continue;
        }

        return response;
      } catch (e) {
        _rotateToNextKey('Network error: $e');
        attempts++;
        if (attempts >= maxAttempts) rethrow;
      }
    }
    throw GroqException('All ${_apiKeys.length} Groq API keys exhausted or unreachable.');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TIER-AWARE DISEASE REPORTS
  // Free  → Basic   (2-3 sentences only)
  // Pro   → Detailed (5-section treatment report)
  // Farm  → Full     (+ organic remedies, prevention calendar, yield impact)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Basic advice for Free tier — short and actionable.
  Future<String> getBasicAdvice({
    required String plantName,
    required String diseaseName,
    required int healthScore,
  }) async {
    final prompt = '''Plant: $plantName
Disease: $diseaseName
Health Score: $healthScore/100

Give a 2-3 sentence summary: what this disease is and the single most important action to take right now. Keep it very brief.''';

    return await _chat(prompt, maxTokens: 150);
  }

  /// Detailed advice for Pro tier — the standard 5-section report.
  Future<String> getDiseaseAdvice({
    required String plantName,
    required String diseaseName,
    required int healthScore,
  }) async {
    final prompt = '''Plant: $plantName
Disease: $diseaseName
Health Score: $healthScore/100

Please provide:
1. What this disease is (simple explanation)
2. Why it happens
3. How to treat it (step by step, max 5 steps)
4. How to prevent it in the future
5. Any organic/natural remedies

Keep your response concise and practical.''';

    return await _chat(prompt);
  }

  /// Full comprehensive report for Farm tier — everything a professional
  /// farmer needs to protect their crop and maximize yield.
  Future<String> getFullReport({
    required String plantName,
    required String diseaseName,
    required int healthScore,
  }) async {
    final prompt = '''Plant: $plantName
Disease: $diseaseName
Health Score: $healthScore/100

Provide a COMPREHENSIVE professional crop health report covering ALL of the following:

1. **Disease Identification**: What this disease is, pathogen type (fungal/bacterial/viral/pest), and how to confirm it visually.
2. **Root Cause Analysis**: Environmental factors, soil conditions, and common triggers.
3. **Immediate Treatment Plan**: Step-by-step actions ranked by urgency (max 6 steps).
4. **Organic/Natural Remedies**: Home-made sprays, companion planting, and bio-control agents.
5. **Chemical Treatment Options**: Recommended fungicides/pesticides with application schedule.
6. **Prevention Calendar**: Month-by-month actions to prevent recurrence across the growing season.
7. **Yield Impact Assessment**: Estimated crop loss percentage if untreated vs. treated.
8. **Related Conditions**: Other diseases this plant is susceptible to when weakened.

Use clear headers. Be thorough but practical. This is for a professional farmer.''';

    return await _chat(prompt, maxTokens: 1200);
  }

  /// Returns the appropriate report based on user tier.
  Future<String> getTieredAdvice({
    required String tier,
    required String plantName,
    required String diseaseName,
    required int healthScore,
  }) async {
    // If offline, fallback to Local LLM
    final isOnline = await SyncService().isOnline();
    if (!isOnline) {
      return await LocalLLMService().getTieredAdvice(
        tier: tier,
        plantName: plantName,
        diseaseName: diseaseName,
        healthScore: healthScore,
      );
    }

    try {
      switch (tier) {
        case 'farm':
          return await getFullReport(
            plantName: plantName,
            diseaseName: diseaseName,
            healthScore: healthScore,
          );
        case 'pro':
          return await getDiseaseAdvice(
            plantName: plantName,
            diseaseName: diseaseName,
            healthScore: healthScore,
          );
        default:
          return await getBasicAdvice(
            plantName: plantName,
            diseaseName: diseaseName,
            healthScore: healthScore,
          );
      }
    } catch (e) {
      debugPrint('Groq/Gemini cloud report failed, falling back to LocalLLM: $e');
      return await LocalLLMService().getTieredAdvice(
        tier: tier,
        plantName: plantName,
        diseaseName: diseaseName,
        healthScore: healthScore,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FALLBACK VISION — only for non-plant object naming
  // This is the LAST resort when both TFLite and PlantNet fail.
  // ═══════════════════════════════════════════════════════════════════════════

  static const String _fallbackVisionPrompt = '''You are a visual classifier. The image was NOT identified as a plant by botanical models.
Accurately name what is visible (e.g., "Human Hand", "Laptop", "Dog", "Office Desk").

Respond in JSON:
{
  "isPlant": false,
  "objectName": "<Accurate Object Name>",
  "description": "<1-2 sentence description>"
}

If you DO see a plant that was missed, respond with:
{
  "isPlant": true,
  "objectName": "<Plant Name>",
  "description": "<1-2 sentence description of the plant>"
}''';

  /// Last-resort vision fallback — only called when TFLite AND PlantNet fail.
  /// Used to name non-plant objects ("Human Hand", "Laptop") or catch missed plants.
  Future<Map<String, dynamic>> identifyObjectFallback(String base64Image) async {
    final messages = [
      {'role': 'system', 'content': _fallbackVisionPrompt},
      {
        'role': 'user',
        'content': [
          {'type': 'text', 'text': 'What is in this image? Respond in JSON.'},
          {
            'type': 'image_url',
            'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}
          }
        ]
      }
    ];

    try {
      final response = await _postWithFallback(
        'chat/completions',
        {
          'model': 'llama-3.2-11b-vision-preview',
          'messages': messages,
          'temperature': 0.1,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        var content = data['choices'][0]['message']['content'] as String;
        // Strip thinking tokens
        content = content.replaceAll(RegExp(r'<think>[\s\S]*?<\/think>'), '').trim();

        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
        if (jsonMatch != null) {
          try {
            return jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Groq fallback vision error: $e');
    }
    return {
      'isPlant': false,
      'objectName': 'Unrecognized Item',
      'description': 'Could not identify what is in the photo.',
    };
  }

  // ─── Chat with history ────────────────────────────────────────────────────

  Future<String> chat(
    String userMessage,
    List<Map<String, String>> history,
  ) async {
    final isOnline = await SyncService().isOnline();
    if (!isOnline) {
      return await LocalLLMService().chat(userMessage, history);
    }

    try {
      final messages = <Map<String, String>>[
        {'role': 'system', 'content': _systemPrompt},
        ...history,
        {'role': 'user', 'content': userMessage},
      ];

      final response = await _postWithFallback(
        'chat/completions',
        {
          'model': AppConstants.groqModel,
          'messages': messages,
          'max_tokens': 800,
          'temperature': 0.7,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] as String;
      }
    } catch (e) {
      debugPrint('Groq chat error, falling back to Gemini: $e');
    }
    return await _gemini.chat(userMessage, history);
  }

  // ─── Streaming Chat with Automatic Failover ────────────────────────────────

  Stream<String> streamChat(
    String userMessage,
    List<Map<String, String>> history,
  ) async* {
    final isOnline = await SyncService().isOnline();
    if (!isOnline) {
      await for (final chunk in LocalLLMService().streamChat(userMessage, history)) {
        yield chunk;
      }
      return;
    }

    bool hasYielded = false;
    try {
      final messages = <Map<String, String>>[
        {'role': 'system', 'content': _systemPrompt},
        ...history,
        {'role': 'user', 'content': userMessage},
      ];

      int attempts = 0;
      final maxAttempts = _apiKeys.length;

      while (attempts < maxAttempts) {
        final apiKey = _currentKey;
        final request = http.Request('POST', Uri.parse('$_baseUrl/chat/completions'))
          ..headers['Authorization'] = 'Bearer $apiKey'
          ..headers['User-Agent'] = 'PhytoLens/1.0 (dart:io)'
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode({
            'model': AppConstants.groqModel,
            'messages': messages,
            'max_tokens': 800,
            'temperature': 0.7,
            'stream': true,
          });

        http.StreamedResponse response;
        try {
          response = await _client.send(request);
        } catch (e) {
          _rotateToNextKey('Stream connect error: $e');
          attempts++;
          continue;
        }

        if (response.statusCode == 429 || response.statusCode == 401 || response.statusCode == 403) {
          _rotateToNextKey('Stream HTTP ${response.statusCode}');
          attempts++;
          continue;
        }

        if (response.statusCode != 200) {
          break;
        }

        await for (final chunk in response.stream.transform(utf8.decoder)) {
          final lines = chunk.split('\n');
          for (final line in lines) {
            if (line.startsWith('data: ')) {
              final data = line.substring(6);
              if (data == '[DONE]') return;
              try {
                final json = jsonDecode(data);
                final content = json['choices']?[0]?['delta']?['content'];
                if (content != null) {
                  hasYielded = true;
                  yield content as String;
                }
              } catch (_) {
                // Ignore partial chunk parsing errors
              }
            }
          }
        }
        return;
      }
    } catch (e) {
      debugPrint('Groq stream error, falling back to Gemini: $e');
    }

    if (!hasYielded) {
      await for (final chunk in _gemini.streamChat(userMessage, history)) {
        yield chunk;
      }
    }
  }

  // ─── Private helper ───────────────────────────────────────────────────────

  Future<String> _chat(String userMessage, {int maxTokens = 500}) async {
    try {
      final response = await _postWithFallback(
        'chat/completions',
        {
          'model': AppConstants.groqModel,
          'messages': [
            {'role': 'system', 'content': _systemPrompt},
            {'role': 'user', 'content': userMessage},
          ],
          'max_tokens': maxTokens,
          'temperature': 0.7,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] as String;
      }
    } catch (e) {
      debugPrint('Groq _chat error, falling back to Gemini: $e');
    }
    return await _gemini.chat(userMessage, []);
  }

  void dispose() => _client.close();
}

class GroqException implements Exception {
  final String message;
  GroqException(this.message);
  @override
  String toString() => message;
}
