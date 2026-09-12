// lib/services/gemini_service.dart
//
// Google Gemini Multimodal Vision Service
// Used for: Accurate non-plant object identification (e.g. Human Hand, Laptop, Cat, etc.)
// and fallback visual classification when botanical models find no match.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import '../config/env.dart';

class GeminiService {
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  final http.Client _client = http.Client();

  // Multi-key pool for automatic failover and rate-limit distribution (loaded via environment)
  static final List<String> _apiKeys = <String>{
    if (Env.geminiApiKey.isNotEmpty) Env.geminiApiKey,
    if (Env.geminiApiKey2.isNotEmpty) Env.geminiApiKey2,
    if (Env.geminiApiKey3.isNotEmpty) Env.geminiApiKey3,
    if (Env.geminiApiKey4.isNotEmpty) Env.geminiApiKey4,
    if (Env.geminiApiKey5.isNotEmpty) Env.geminiApiKey5,
  }.where((k) => k.trim().startsWith('AIzaSy')).toList();

  static int _currentKeyIndex = 0;

  // Supported fast models in order of priority
  static const List<String> _models = [
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-flash',
    'gemini-1.5-flash-8b',
  ];

  String get _currentKey => _apiKeys.isNotEmpty ? _apiKeys[_currentKeyIndex % _apiKeys.length] : '';

  void _rotateToNextKey([String? reason]) {
    if (_apiKeys.length <= 1) return;
    final oldIdx = _currentKeyIndex;
    _currentKeyIndex = (_currentKeyIndex + 1) % _apiKeys.length;
    debugPrint('🔄 Gemini Key #$oldIdx ($reason). Auto-switched to key #${_currentKeyIndex + 1} of ${_apiKeys.length}.');
  }

  /// High-speed identification from file with client-side downsampling (<30KB payload)
  Future<Map<String, dynamic>> identifyImageFile(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        // Resize to max 384px for ultra-low latency upload
        final maxDim = decoded.width > decoded.height ? decoded.width : decoded.height;
        final resized = maxDim > 384 
            ? (decoded.width >= decoded.height
                ? img.copyResize(decoded, width: 384)
                : img.copyResize(decoded, height: 384))
            : decoded;
        final jpgBytes = img.encodeJpg(resized, quality: 75);
        final base64Image = base64Encode(jpgBytes);
        return identifyObject(base64Image: base64Image, mimeType: 'image/jpeg');
      }
    } catch (e) {
      debugPrint('Gemini image compression fallback: $e');
    }
    final bytes = await imageFile.readAsBytes();
    return identifyObject(base64Image: base64Encode(bytes));
  }

  /// Identifies any visual object in an image with intelligent key & model rotation.
  Future<Map<String, dynamic>> identifyObject({
    required String base64Image,
    String mimeType = 'image/jpeg',
  }) async {
    const prompt = '''Analyze this image with high precision.
1. If this is NOT a plant or flower, accurately identify the primary object (e.g. "Human Hand", "Laptop", "Keyboard", "Smartphone", "Cat", "Dog", "Car", "Coffee Cup", "Desk") and describe what is visible in 1-2 concise sentences.
2. If it IS a plant, leaf, or flower that was missed, provide the plant name.

Respond strictly in valid JSON format:
{
  "objectName": "<Exact Object Name>",
  "isPlant": false,
  "description": "<Clear 1-2 sentence visual description>"
}''';

    int totalAttempts = 0;
    const maxTotalAttempts = 3;

    // Try fast models and rotate keys on rate limit
    for (final model in _models) {
      if (totalAttempts >= maxTotalAttempts) break;

      final key = _currentKey;
      try {
        final uri = Uri.parse('$_baseUrl/$model:generateContent?key=$key');
        final response = await _client.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt},
                  {
                    'inline_data': {
                      'mime_type': mimeType,
                      'data': base64Image,
                    }
                  }
                ]
              }
            ],
            'generationConfig': {
              'responseMimeType': 'application/json',
              'temperature': 0.1,
            }
          }),
        ).timeout(const Duration(seconds: 6));

        totalAttempts++;

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final text = data['candidates']?[0]?['content']?['parts']?[0]?['text']?.toString() ?? '';
          
          final parsed = _extractJson(text);
          if (parsed != null) {
            return parsed;
          }
        }

        // Handle rate limit (429), unauthorized (401/403), high demand (503)
        if (response.statusCode == 429 || response.statusCode == 403 || response.statusCode == 503) {
          _rotateToNextKey('HTTP ${response.statusCode} on $model');
          continue;
        } else if (response.statusCode == 404) {
          // Model not supported, switch to next model
          continue;
        }
      } catch (e) {
        debugPrint('Gemini vision network error ($model): $e');
        _rotateToNextKey('Network error');
        totalAttempts++;
      }
    }

    // Graceful fallback if all keys/models are exhausted or offline
    return {
      'isPlant': false,
      'objectName': 'Unrecognized Item',
      'description': 'Could not identify what is in the photo. Point your camera at a plant leaf or object for health analysis.',
    };
  }

  /// Extracts and parses JSON from model response text
  Map<String, dynamic>? _extractJson(String text) {
    if (text.trim().isEmpty) return null;
    try {
      // First try direct decode
      return jsonDecode(text.trim()) as Map<String, dynamic>;
    } catch (_) {
      // Regex match for JSON block inside markdown or text
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      if (match != null) {
        try {
          return jsonDecode(match.group(0)!) as Map<String, dynamic>;
        } catch (_) {}
      }
    }
    return null;
  }

  /// AI Text Chat with Gemini
  Future<String> chat(String userMessage, List<Map<String, String>> history) async {
    for (final model in _models) {
      for (int i = 0; i < _apiKeys.length; i++) {
        final key = _currentKey;
        final url = '$_baseUrl/$model:generateContent?key=$key';
        try {
          final contents = <Map<String, dynamic>>[];
          for (final h in history) {
            final role = h['role'] == 'assistant' ? 'model' : 'user';
            contents.add({
              'role': role,
              'parts': [{'text': h['content'] ?? ''}],
            });
          }
          contents.add({
            'role': 'user',
            'parts': [{'text': userMessage}],
          });

          final response = await _client.post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'systemInstruction': {
                'parts': [{'text': 'You are PhytoLens AI, an expert botanical and agricultural health advisor. Answer practical plant questions clearly and concisely.'}],
              },
              'contents': contents,
              'generationConfig': {
                'maxOutputTokens': 800,
                'temperature': 0.7,
              },
            }),
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
            if (text != null) return text as String;
          }

          if (response.statusCode == 429 || response.statusCode == 403) {
            _rotateToNextKey('HTTP ${response.statusCode}');
            continue;
          }
        } catch (e) {
          debugPrint('Gemini chat error: $e');
          _rotateToNextKey('Network');
        }
      }
    }
    throw Exception('Gemini chat failed across all keys');
  }

  /// AI Text Streaming Chat with Gemini
  Stream<String> streamChat(String userMessage, List<Map<String, String>> history) async* {
    for (final model in _models) {
      for (int i = 0; i < _apiKeys.length; i++) {
        final key = _currentKey;
        final url = '$_baseUrl/$model:streamGenerateContent?alt=sse&key=$key';
        try {
          final contents = <Map<String, dynamic>>[];
          for (final h in history) {
            final role = h['role'] == 'assistant' ? 'model' : 'user';
            contents.add({
              'role': role,
              'parts': [{'text': h['content'] ?? ''}],
            });
          }
          contents.add({
            'role': 'user',
            'parts': [{'text': userMessage}],
          });

          final request = http.Request('POST', Uri.parse(url))
            ..headers['Content-Type'] = 'application/json'
            ..body = jsonEncode({
              'systemInstruction': {
                'parts': [{'text': 'You are PhytoLens AI, an expert botanical and agricultural health advisor. Answer practical plant questions clearly and concisely.'}],
              },
              'contents': contents,
              'generationConfig': {
                'maxOutputTokens': 800,
                'temperature': 0.7,
              },
            });

          final streamedResponse = await _client.send(request);

          if (streamedResponse.statusCode == 200) {
            await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
              final lines = chunk.split('\n');
              for (final line in lines) {
                if (line.startsWith('data: ')) {
                  final jsonStr = line.substring(6).trim();
                  if (jsonStr.isEmpty) continue;
                  try {
                    final data = jsonDecode(jsonStr);
                    final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
                    if (text != null) {
                      yield text as String;
                    }
                  } catch (_) {}
                }
              }
            }
            return;
          }

          if (streamedResponse.statusCode == 429 || streamedResponse.statusCode == 403) {
            _rotateToNextKey('HTTP ${streamedResponse.statusCode}');
            continue;
          }
        } catch (e) {
          debugPrint('Gemini stream error: $e');
          _rotateToNextKey('Network');
        }
      }
    }
  }

  void dispose() => _client.close();
}
