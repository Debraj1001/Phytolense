// lib/services/ml_service.dart
// TFLite on-device plant disease inference

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'xgboost_service.dart';

class MLService {
  Interpreter? _interpreter;
  List<String>? _labels;
  Map<String, dynamic>? _agronomyKb;

  static const double lowConfidenceThreshold = 0.45;

  bool get isLoaded => _interpreter != null && _labels != null;

  // ─── Initialization ────────────────────────────────────────────────────────

  Future<void> initialize() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/plant_disease_model.tflite');
      final labelFile = await rootBundle.loadString('assets/models/plant_labels.txt');
      _labels = labelFile.split('\n').where((s) => s.trim().isNotEmpty).toList();
      
      try {
        final kbFile = await rootBundle.loadString('assets/data/agronomy_kb.json');
        _agronomyKb = jsonDecode(kbFile);
      } catch (e) {
        debugPrint('Agronomy KB not found or invalid: $e');
      }
    } catch (e) {
      debugPrint('Failed to load TFLite model or labels: $e');
    }
  }

  // ─── Inference ────────────────────────────────────────────────────────────

  Future<MLResult> classifyImage(File imageFile) async {
    if (!isLoaded) {
      return _mockInference(imageFile.path);
    }

    try {
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      if (image == null) throw Exception('Invalid image');

      // The standard PlantVillage model requires 256x256 input
      const int inputSize = 256;
      final resized = img.copyResize(image, width: inputSize, height: inputSize);

      // ── Lightweight Non-Plant Heuristic ──
      // Check if image contains at least some plant-like colors (green, yellow, brown)
      int plantPixels = 0;
      for (int y = 0; y < inputSize; y += 8) {
        for (int x = 0; x < inputSize; x += 8) {
          final p = resized.getPixel(x, y);
          // Greenish, yellowish, or brownish tones
          if ((p.g > p.b && p.r > p.b) || (p.g > p.r * 0.8 && p.g > 30)) {
            plantPixels++;
          }
        }
      }
      // Sampled 32x32 = 1024 pixels. If less than 3% are plant-like, reject.
      if (plantPixels < 30) {
        throw Exception('NOT_A_PLANT');
      }

      // Convert image to a 3D float array [1, 256, 256, 3] and normalize 0..1
      var input = List.generate(
        1,
        (i) => List.generate(
          inputSize,
          (y) => List.generate(
            inputSize,
            (x) {
              final pixel = resized.getPixel(x, y);
              return [
                pixel.r / 255.0,
                pixel.g / 255.0,
                pixel.b / 255.0,
              ];
            },
          ),
        ),
      );

      // Output shape is [1, 38] (38 classes)
      var output = List.generate(1, (i) => List.filled(_labels!.length, 0.0));

      _interpreter!.run(input, output);

      final probabilities = output[0];
      
      // Find highest probability
      double maxProb = 0.0;
      int maxIndex = -1;
      for (int i = 0; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          maxIndex = i;
        }
      }

      if (maxIndex == -1) {
        throw Exception('Failed to classify');
      }

      final label = _labels![maxIndex];
      // Labels format in plant_labels.txt: "plantname diseasename" (e.g. "tomato late blight" or "potato healthy")
      final parts = label.split(' ');
      String plantName = parts.isNotEmpty ? parts[0] : 'Unknown';
      String diseaseName = parts.length > 1 ? parts.sublist(1).join(' ') : 'Unknown';
      // Capitalize first letters for clean display
      plantName = plantName.substring(0, 1).toUpperCase() + plantName.substring(1);
      diseaseName = diseaseName.substring(0, 1).toUpperCase() + diseaseName.substring(1);

      // Mark as low confidence if model is not sure — likely unsupported crop
      final bool lowConfidence = maxProb < MLService.lowConfidenceThreshold;

      // XGBoost Post-Processing
      int severity = 0;
      double finalConfidence = maxProb;
      int finalHealthScore = lowConfidence ? 0 : _calcHealthScore(diseaseName, maxProb);

      if (!lowConfidence && !diseaseName.toLowerCase().contains('healthy')) {
        // Extract top 3 probabilities for XGBoost
        final topProbs = List<double>.from(probabilities)..sort((a, b) => b.compareTo(a));
        final top3 = topProbs.take(3).toList();
        
        final imgFeatures = await XGBoostService().extractFeatures(imageFile);
        final xgbResult = await XGBoostService().analyze(
          tfliteProbabilities: top3,
          imageFeatures: imgFeatures,
          predictedDisease: diseaseName,
          tfliteConfidence: maxProb,
        );
        
        severity = xgbResult.severityPercent;
        finalConfidence = xgbResult.refinedConfidence;
        finalHealthScore = (finalHealthScore + xgbResult.healthScoreAdjustment).clamp(0, 100);
      }

      Map<String, dynamic>? treatmentData;
      if (_agronomyKb != null) {
        treatmentData = _agronomyKb![diseaseName] ?? _agronomyKb!['Unknown'];
      }

      return MLResult(
        plantName: lowConfidence ? 'Unknown Plant' : plantName,
        diseaseName: lowConfidence ? 'Unrecognized' : diseaseName,
        confidence: finalConfidence,
        healthScore: finalHealthScore,
        severityPercent: severity,
        isLowConfidence: lowConfidence,
        treatmentData: treatmentData,
      );
    } catch (e) {
      debugPrint('ML Error: $e');
      return _mockInference(imageFile.path);
    }
  }

  // ─── Mock Inference (Fallback) ─────────────────────────────────────────────

  MLResult _mockInference(String path) {
    return const MLResult(
      plantName: 'Unknown Plant',
      diseaseName: 'Analysis Failed',
      confidence: 0.0,
      healthScore: 0,
      severityPercent: 0,
      isLowConfidence: true,
    );
  }

  int _calcHealthScore(String disease, double confidence) {
    if (disease.toLowerCase().contains('healthy')) {
      return (85 + (confidence * 15).round()).clamp(0, 100);
    }
    return ((1.0 - confidence) * 70 + 20).round().clamp(0, 100);
  }

  void dispose() {
    _interpreter?.close();
  }
}

class MLResult {
  final String plantName;
  final String diseaseName;
  final double confidence;
  final int healthScore;
  final int severityPercent;
  final bool isLowConfidence;
  final Map<String, dynamic>? treatmentData;

  const MLResult({
    required this.plantName,
    required this.diseaseName,
    required this.confidence,
    required this.healthScore,
    this.severityPercent = 0,
    this.isLowConfidence = false,
    this.treatmentData,
  });

  bool get isHealthy => diseaseName.toLowerCase().contains('healthy');
  bool get isUnknown => isLowConfidence || plantName == 'Unknown Plant';
}
