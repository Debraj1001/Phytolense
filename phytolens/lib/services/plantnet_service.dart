// lib/services/plantnet_service.dart
//
// Pl@ntNet REST API integration for accurate plant species identification.
// Free tier: 500 identifications/day across 82,000+ species.
// This is the PRIMARY online identification service — Groq is NOT used
// for identification. Groq is only for text reports/advice/chat.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/env.dart';

class PlantNetService {
  static const String _baseUrl = 'https://my-api.plantnet.org/v2';

  // Daily quota tracking (500/day free) — we track locally to avoid
  // hitting the API unnecessarily when we know we've exceeded the limit.
  static const int _dailyQuota = 500;
  static const String _quotaDateKey = 'plantnet_quota_date';
  static const String _quotaCountKey = 'plantnet_quota_count';

  // ─── Identify a plant from an image file ─────────────────────────────────

  /// Returns a [PlantNetResult] with species info, or null if identification
  /// failed or confidence is too low.
  Future<PlantNetResult?> identifyPlant(File imageFile) async {
    final apiKey = Env.plantnetApiKey;
    if (apiKey.isEmpty) {
      debugPrint('⚠️ PlantNet API key not configured');
      return null;
    }

    // Check local quota before making the call
    if (!await _hasQuotaRemaining()) {
      debugPrint('⚠️ PlantNet daily quota exhausted (500/day)');
      return null;
    }

    try {
      final uri = Uri.parse(
        '$_baseUrl/identify/all'
        '?include-related-images=false'
        '&no-reject=false'
        '&nb-results=3'
        '&lang=en'
        '&type=kt'
        '&api-key=$apiKey',
      );

      final request = http.MultipartRequest('POST', uri);

      // Add image as multipart file
      request.files.add(
        await http.MultipartFile.fromPath('images', imageFile.path),
      );

      // Default organ to "auto" — PlantNet will detect the best match
      request.fields['organs'] = 'auto';

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 15),
      );
      final response = await http.Response.fromStream(streamedResponse);

      // Increment local quota counter
      await _incrementQuotaCount();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return _parseResponse(data);
      } else if (response.statusCode == 404) {
        // 404 = no match found — valid response, not an error
        debugPrint('🌿 PlantNet: No plant match found in image');
        return null;
      } else if (response.statusCode == 429) {
        debugPrint('🚫 PlantNet: Rate limit exceeded');
        return null;
      } else {
        debugPrint('❌ PlantNet error ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ PlantNet API call failed: $e');
      return null;
    }
  }

  // ─── Parse the PlantNet JSON response ────────────────────────────────────

  PlantNetResult? _parseResponse(Map<String, dynamic> data) {
    final results = data['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) return null;

    final bestMatch = results[0] as Map<String, dynamic>;
    final score = (bestMatch['score'] as num?)?.toDouble() ?? 0.0;

    // Reject very low-confidence matches
    if (score < 0.10) {
      debugPrint('🌿 PlantNet: Best match score too low ($score)');
      return null;
    }

    final species = bestMatch['species'] as Map<String, dynamic>?;
    if (species == null) return null;

    final scientificName = species['scientificNameWithoutAuthor'] as String? ?? '';
    final family = (species['family'] as Map<String, dynamic>?)?['scientificNameWithoutAuthor'] as String? ?? '';

    // Common names — pick the first English one
    final commonNames = species['commonNames'] as List<dynamic>?;
    String commonName = '';
    if (commonNames != null && commonNames.isNotEmpty) {
      commonName = commonNames[0].toString();
    }

    // Build a user-friendly display name
    final displayName = commonName.isNotEmpty
        ? commonName
        : scientificName.isNotEmpty
            ? scientificName
            : 'Unknown Plant';

    // Collect alternative matches for the UI
    final alternatives = <String>[];
    for (int i = 1; i < results.length && i < 3; i++) {
      final alt = results[i] as Map<String, dynamic>;
      final altSpecies = alt['species'] as Map<String, dynamic>?;
      if (altSpecies != null) {
        final altNames = altSpecies['commonNames'] as List<dynamic>?;
        final altSci = altSpecies['scientificNameWithoutAuthor'] as String? ?? '';
        if (altNames != null && altNames.isNotEmpty) {
          alternatives.add(altNames[0].toString());
        } else if (altSci.isNotEmpty) {
          alternatives.add(altSci);
        }
      }
    }

    return PlantNetResult(
      commonName: displayName,
      scientificName: scientificName,
      family: family,
      confidence: score,
      alternatives: alternatives,
    );
  }

  // ─── Local quota tracking ────────────────────────────────────────────────
  // We maintain a local counter so we don't send requests when we know
  // the free daily limit is exhausted. Resets at midnight local time.

  Future<bool> _hasQuotaRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final storedDate = prefs.getString(_quotaDateKey);

    if (storedDate != today) {
      // New day — reset counter
      await prefs.setString(_quotaDateKey, today);
      await prefs.setInt(_quotaCountKey, 0);
      return true;
    }

    final count = prefs.getInt(_quotaCountKey) ?? 0;
    return count < _dailyQuota;
  }

  Future<void> _incrementQuotaCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final storedDate = prefs.getString(_quotaDateKey);

    if (storedDate != today) {
      await prefs.setString(_quotaDateKey, today);
      await prefs.setInt(_quotaCountKey, 1);
    } else {
      final count = prefs.getInt(_quotaCountKey) ?? 0;
      await prefs.setInt(_quotaCountKey, count + 1);
    }
  }

  /// Returns the approximate number of PlantNet API calls remaining today.
  Future<int> getRemainingQuota() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final storedDate = prefs.getString(_quotaDateKey);

    if (storedDate != today) return _dailyQuota;
    final count = prefs.getInt(_quotaCountKey) ?? 0;
    return (_dailyQuota - count).clamp(0, _dailyQuota);
  }
}

// ─── Result Model ──────────────────────────────────────────────────────────

class PlantNetResult {
  final String commonName;
  final String scientificName;
  final String family;
  final double confidence;
  final List<String> alternatives;

  const PlantNetResult({
    required this.commonName,
    required this.scientificName,
    required this.family,
    required this.confidence,
    this.alternatives = const [],
  });

  @override
  String toString() =>
      'PlantNetResult($commonName [$scientificName], family=$family, confidence=${(confidence * 100).toStringAsFixed(1)}%)';
}
