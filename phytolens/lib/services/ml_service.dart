// lib/services/ml_service.dart
// TFLite on-device plant disease inference

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class MLService {
  Interpreter? _interpreter;
  List<String>? _labels;

  static const double lowConfidenceThreshold = 0.45;

  bool get isLoaded => _interpreter != null && _labels != null;

  // ─── Initialization ────────────────────────────────────────────────────────

  Future<void> initialize() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/plant_disease_model.tflite');
      final labelFile = await rootBundle.loadString('assets/models/plant_labels.txt');
      _labels = labelFile.split('\n').where((s) => s.trim().isNotEmpty).toList();
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

      // Convert image to a 3D float array [1, 256, 256, 3] and normalize 0..1
      // Use list literals and standard dart types since Float32List multidimensional arrays are tricky in Dart TFLite without shaping tools.
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
      // Labels format is usually "PlantName___Disease_Name"
      final parts = label.split('___');
      String plantName = parts[0].replaceAll('_', ' ');
      String diseaseName = parts.length > 1 ? parts[1].replaceAll('_', ' ') : 'Unknown';

      // Mark as low confidence if model is not sure — likely unsupported crop
      final bool lowConfidence = maxProb < MLService.lowConfidenceThreshold;

      return MLResult(
        plantName: lowConfidence ? 'Unknown Plant' : plantName,
        diseaseName: lowConfidence ? 'Unrecognized' : diseaseName,
        confidence: maxProb,
        healthScore: lowConfidence ? 0 : _calcHealthScore(diseaseName, maxProb),
        isLowConfidence: lowConfidence,
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
  final bool isLowConfidence;

  const MLResult({
    required this.plantName,
    required this.diseaseName,
    required this.confidence,
    required this.healthScore,
    this.isLowConfidence = false,
  });

  bool get isHealthy => diseaseName.toLowerCase().contains('healthy');
  bool get isUnknown => isLowConfidence || plantName == 'Unknown Plant';
}
