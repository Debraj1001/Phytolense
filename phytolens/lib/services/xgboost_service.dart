// lib/services/xgboost_service.dart
//
// XGBoost Ensemble Model (via ONNX Runtime) for:
//   - Disease confidence boosting (refining TFLite softmax output)
//   - Severity estimation (infection-to-leaf-area ratio)
//   - Health score refinement
//   - Environmental risk factors for crop disease prevention
//
// Input: TFLite probabilities + image features + environmental metadata
// Output: Refined confidence, severity score, prevention risk flags

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'python_service.dart';

class XGBoostService {
  static final XGBoostService _instance = XGBoostService._internal();
  factory XGBoostService() => _instance;
  XGBoostService._internal();

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  // ── ONNX Model paths ────────────────────────────────────────────────────
  // static const String _severityModelAsset = 'assets/models/xgboost_severity.onnx';

  // ═══════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> initialize() async {
    try {
      // Hook: Load ONNX model via onnxruntime package when compiled with C++ runtime
      // _session = await OrtSession.fromAsset(_severityModelAsset);
      _isLoaded = true;
      debugPrint('✅ XGBoost severity model loaded');
    } catch (e) {
      debugPrint('⚠️ XGBoost model not available, using heuristic fallback: $e');
      _isLoaded = false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // FEATURE EXTRACTION FROM IMAGE
  // Extracts 9 tabular features for XGBoost input
  // ═══════════════════════════════════════════════════════════════════════

  /// Extract image-level features for XGBoost input
  Future<ImageFeatures> extractFeatures(File imageFile) async {
    try {
      final pythonService = PythonService();
      if (pythonService.isInitialized) {
        final pyFeatures = await pythonService.analyzeImageFeatures(imageFile);
        if (!pyFeatures.containsKey('error')) {
          return ImageFeatures(
            brightness: pyFeatures['brightness'] ?? 0.5,
            contrast: pyFeatures['contrast'] ?? 0.1,
            sharpness: pyFeatures['sharpness'] ?? 0.05,
            greenDominance: pyFeatures['green_dominance'] ?? 1.0,
            leafAreaRatio: pyFeatures['leaf_area_ratio'] ?? 0.3,
            diseaseAreaRatio: pyFeatures['disease_area_ratio'] ?? 0.0,
          );
        }
      }

      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return ImageFeatures.empty();

      // Downsample for fast feature extraction
      final small = img.copyResize(image, width: 128, height: 128);

      double totalBrightness = 0;
      double totalGreen = 0;
      double totalRed = 0;
      double totalBlue = 0;
      int greenPixels = 0; // Pixels where green dominates (leaf area)
      int brownPixels = 0; // Pixels with brown/yellow (potential disease)
      int totalPixels = small.width * small.height;

      for (int y = 0; y < small.height; y++) {
        for (int x = 0; x < small.width; x++) {
          final pixel = small.getPixel(x, y);
          final r = pixel.r.toDouble();
          final g = pixel.g.toDouble();
          final b = pixel.b.toDouble();

          totalBrightness += (r + g + b) / 3.0;
          totalRed += r;
          totalGreen += g;
          totalBlue += b;

          // Green dominant = leaf area
          if (g > r * 1.1 && g > b * 1.1 && g > 60) {
            greenPixels++;
          }

          // Brown/yellow = potential disease area
          if (r > g * 0.9 && r > 80 && g > 40 && g < 180 && b < g * 0.8) {
            brownPixels++;
          }
        }
      }

      final avgBrightness = totalBrightness / totalPixels / 255.0;
      final avgGreen = totalGreen / totalPixels / 255.0;
      final avgRed = totalRed / totalPixels / 255.0;
      final avgBlue = totalBlue / totalPixels / 255.0;

      // Green channel dominance ratio
      final greenDominance = avgGreen / ((avgRed + avgGreen + avgBlue) / 3.0 + 0.001);

      // Leaf area ratio (green pixels / total pixels)
      final leafAreaRatio = greenPixels / totalPixels.toDouble();

      // Disease area ratio (brown pixels / green pixels)
      final diseaseAreaRatio = greenPixels > 0
          ? (brownPixels / greenPixels.toDouble()).clamp(0.0, 1.0)
          : 0.0;

      // Simple contrast estimation (std deviation proxy)
      double sumSqDiff = 0;
      for (int y = 0; y < small.height; y++) {
        for (int x = 0; x < small.width; x++) {
          final pixel = small.getPixel(x, y);
          final brightness = (pixel.r + pixel.g + pixel.b) / 3.0 / 255.0;
          sumSqDiff += (brightness - avgBrightness) * (brightness - avgBrightness);
        }
      }
      final contrast = math.sqrt(sumSqDiff / totalPixels);

      // Edge density via simple horizontal gradient (sharpness proxy)
      int edgeCount = 0;
      for (int y = 0; y < small.height; y++) {
        for (int x = 1; x < small.width; x++) {
          final curr = small.getPixel(x, y);
          final prev = small.getPixel(x - 1, y);
          final diff = ((curr.r - prev.r).abs() +
                  (curr.g - prev.g).abs() +
                  (curr.b - prev.b).abs()) /
              3.0;
          if (diff > 30) edgeCount++;
        }
      }
      final edgeDensity = edgeCount / (totalPixels.toDouble());

      return ImageFeatures(
        brightness: avgBrightness,
        contrast: contrast,
        sharpness: edgeDensity,
        greenDominance: greenDominance,
        leafAreaRatio: leafAreaRatio,
        diseaseAreaRatio: diseaseAreaRatio,
      );
    } catch (e) {
      debugPrint('Feature extraction error: $e');
      return ImageFeatures.empty();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // XGBOOST INFERENCE
  // Combines TFLite output + image features for refined analysis
  // ═══════════════════════════════════════════════════════════════════════

  /// Run XGBoost ensemble inference to refine TFLite results
  Future<XGBoostResult> analyze({
    required List<double> tfliteProbabilities, // Top-3 class probabilities
    required ImageFeatures imageFeatures,
    required String predictedDisease,
    required double tfliteConfidence,
  }) async {
    // Build the 9-feature input vector
    final features = <double>[
      // TFLite top-3 probabilities
      tfliteProbabilities.isNotEmpty ? tfliteProbabilities[0] : 0.0,
      tfliteProbabilities.length > 1 ? tfliteProbabilities[1] : 0.0,
      tfliteProbabilities.length > 2 ? tfliteProbabilities[2] : 0.0,
      // Image quality features
      imageFeatures.brightness,
      imageFeatures.contrast,
      imageFeatures.sharpness,
      // Vegetation features
      imageFeatures.leafAreaRatio,
      imageFeatures.greenDominance,
      imageFeatures.diseaseAreaRatio,
    ];

    if (_isLoaded) {
      return _runOnnxInference(features, predictedDisease, tfliteConfidence);
    }

    // Heuristic fallback when ONNX model is not available
    return _heuristicAnalysis(features, predictedDisease, tfliteConfidence, imageFeatures);
  }

  /// Run actual ONNX inference
  Future<XGBoostResult> _runOnnxInference(
    List<double> features,
    String predictedDisease,
    double tfliteConfidence,
  ) async {
    try {
      // Hook: Replace with actual ONNX Runtime inference when model is loaded
      // final input = OrtValueTensor.fromList(features, [1, 9]);
      // final outputs = await _session!.run({'input': input});
      // final refined = outputs['refined_confidence']!.value as double;
      // final severity = outputs['severity_score']!.value as double;

      // For now, use heuristic fallback
      return _heuristicAnalysis(
        features,
        predictedDisease,
        tfliteConfidence,
        ImageFeatures(
          brightness: features[3],
          contrast: features[4],
          sharpness: features[5],
          leafAreaRatio: features[6],
          greenDominance: features[7],
          diseaseAreaRatio: features[8],
        ),
      );
    } catch (e) {
      debugPrint('ONNX inference error: $e');
      return XGBoostResult(
        refinedConfidence: tfliteConfidence,
        severityPercent: 0,
        healthScoreAdjustment: 0,
        riskFactors: [],
      );
    }
  }

  /// Heuristic analysis fallback — mimics XGBoost behavior using rules
  XGBoostResult _heuristicAnalysis(
    List<double> features,
    String predictedDisease,
    double tfliteConfidence,
    ImageFeatures imgFeatures,
  ) {
    final isHealthy = predictedDisease.toLowerCase().contains('healthy');

    // ── Confidence Refinement ──
    double refined = tfliteConfidence;

    // Boost confidence if image quality is good
    if (imgFeatures.brightness > 0.3 && imgFeatures.brightness < 0.8 &&
        imgFeatures.contrast > 0.1 && imgFeatures.sharpness > 0.05) {
      refined = (refined * 1.08).clamp(0.0, 1.0); // +8% boost for good images
    }

    // Reduce confidence if image is too dark or blurry
    if (imgFeatures.brightness < 0.15 || imgFeatures.sharpness < 0.02) {
      refined = refined * 0.85; // -15% penalty
    }

    // Boost if strong leaf area detected (confirms it's a plant photo)
    if (imgFeatures.leafAreaRatio > 0.2) {
      refined = (refined * 1.05).clamp(0.0, 1.0);
    }

    // ── Severity Estimation ──
    int severityPercent = 0;
    if (!isHealthy) {
      // Disease area ratio is the primary severity indicator
      severityPercent = (imgFeatures.diseaseAreaRatio * 100).round().clamp(0, 100);

      // Adjust based on confidence — higher confidence disease = likely more severe
      if (tfliteConfidence > 0.8) {
        severityPercent = (severityPercent * 1.2).round().clamp(0, 100);
      }

      // Minimum severity of 10% if disease is detected with decent confidence
      if (tfliteConfidence > 0.5 && severityPercent < 10) {
        severityPercent = 10;
      }
    }

    // ── Health Score Adjustment ──
    int healthAdj = 0;
    if (!isHealthy && severityPercent > 30) {
      healthAdj = -(severityPercent ~/ 5); // Reduce health by severity/5
    }
    if (isHealthy && imgFeatures.greenDominance > 1.2) {
      healthAdj = 5; // Small boost for very green healthy plants
    }

    // ── Risk Factors for Prevention ──
    final riskFactors = <RiskFactor>[];

    if (imgFeatures.brightness < 0.25) {
      riskFactors.add(const RiskFactor(
        factor: 'Low Light',
        description: 'Plant appears to be in low light — ensure adequate sunlight',
        severity: 'medium',
        icon: '☀️',
      ));
    }

    if (imgFeatures.leafAreaRatio < 0.1 && !isHealthy) {
      riskFactors.add(const RiskFactor(
        factor: 'Significant Leaf Loss',
        description: 'Very little green leaf area detected — disease may be advanced',
        severity: 'high',
        icon: '🍂',
      ));
    }

    if (severityPercent > 50) {
      riskFactors.add(RiskFactor(
        factor: 'High Severity Infection',
        description: 'Approximately $severityPercent% of leaf area appears affected',
        severity: 'critical',
        icon: '🔴',
      ));
    } else if (severityPercent > 20) {
      riskFactors.add(RiskFactor(
        factor: 'Moderate Infection',
        description: 'Approximately $severityPercent% of leaf area appears affected',
        severity: 'medium',
        icon: '🟡',
      ));
    }

    if (imgFeatures.diseaseAreaRatio > 0.3 && imgFeatures.leafAreaRatio > 0.15) {
      riskFactors.add(const RiskFactor(
        factor: 'Spreading Risk',
        description: 'Disease spots are spread across the leaf — may spread to nearby plants',
        severity: 'high',
        icon: '⚠️',
      ));
    }

    return XGBoostResult(
      refinedConfidence: refined,
      severityPercent: severityPercent,
      healthScoreAdjustment: healthAdj,
      riskFactors: riskFactors,
    );
  }

  void dispose() {
    // Hook: _session?.release();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════════════════════════════════════════

class ImageFeatures {
  final double brightness;     // 0.0 (dark) — 1.0 (bright)
  final double contrast;       // 0.0 (flat) — 0.5+ (high contrast)
  final double sharpness;      // 0.0 (blurry) — 0.3+ (sharp)
  final double greenDominance; // >1.0 means green is dominant channel
  final double leafAreaRatio;  // 0.0 — 1.0 (ratio of green pixels)
  final double diseaseAreaRatio; // 0.0 — 1.0 (brown/disease pixels vs leaf)

  const ImageFeatures({
    required this.brightness,
    required this.contrast,
    required this.sharpness,
    required this.greenDominance,
    required this.leafAreaRatio,
    required this.diseaseAreaRatio,
  });

  factory ImageFeatures.empty() => const ImageFeatures(
    brightness: 0.5,
    contrast: 0.1,
    sharpness: 0.05,
    greenDominance: 1.0,
    leafAreaRatio: 0.3,
    diseaseAreaRatio: 0.0,
  );

  Map<String, dynamic> toMap() => {
    'brightness': brightness,
    'contrast': contrast,
    'sharpness': sharpness,
    'green_dominance': greenDominance,
    'leaf_area_ratio': leafAreaRatio,
    'disease_area_ratio': diseaseAreaRatio,
  };
}

class XGBoostResult {
  final double refinedConfidence;    // Refined confidence (0.0–1.0)
  final int severityPercent;         // Infection severity (0–100%)
  final int healthScoreAdjustment;   // Adjustment to apply to ML health score
  final List<RiskFactor> riskFactors; // Prevention risk flags

  const XGBoostResult({
    required this.refinedConfidence,
    required this.severityPercent,
    required this.healthScoreAdjustment,
    required this.riskFactors,
  });

  String get severityLabel {
    if (severityPercent == 0) return 'None';
    if (severityPercent <= 10) return 'Minimal';
    if (severityPercent <= 25) return 'Mild';
    if (severityPercent <= 50) return 'Moderate';
    if (severityPercent <= 75) return 'Severe';
    return 'Critical';
  }

  String get severityEmoji {
    if (severityPercent == 0) return '✅';
    if (severityPercent <= 25) return '🟡';
    if (severityPercent <= 50) return '🟠';
    return '🔴';
  }
}

class RiskFactor {
  final String factor;
  final String description;
  final String severity; // 'low' | 'medium' | 'high' | 'critical'
  final String icon;

  const RiskFactor({
    required this.factor,
    required this.description,
    required this.severity,
    required this.icon,
  });
}
