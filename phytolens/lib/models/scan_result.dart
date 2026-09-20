// lib/models/scan_result.dart

class ScanResult {
  final String id;
  final String userId;
  final String? plantId;
  final String? imageUrl;
  final String diseaseName;
  final double diseaseConfidence; // 0.0 - 1.0
  final String plantName;
  final int healthScore; // 0 - 100
  final String? remedy;
  final bool flagged;
  final DateTime scannedAt;
  // ── XGBoost Severity Fields ──
  final int severityPercent;       // 0-100 infection severity
  final double infectionArea;      // 0.0-1.0 disease-to-leaf ratio
  final String aiSource;           // 'cloud' | 'offline' | 'template'

  const ScanResult({
    required this.id,
    required this.userId,
    this.plantId,
    this.imageUrl,
    required this.diseaseName,
    required this.diseaseConfidence,
    required this.plantName,
    required this.healthScore,
    this.remedy,
    this.flagged = false,
    required this.scannedAt,
    this.severityPercent = 0,
    this.infectionArea = 0.0,
    this.aiSource = 'cloud',
  });

  bool get isHealthy => diseaseName == 'Healthy' || healthScore >= 90;
  bool get isNonPlant =>
      diseaseName.contains('Object') ||
      diseaseName.contains('Non-Plant') ||
      plantName.toLowerCase().contains('hand') ||
      plantName.toLowerCase().contains('laptop') ||
      plantName.toLowerCase().contains('phone') ||
      plantName.toLowerCase().contains('keyboard');
  bool get isLowConfidence => diseaseConfidence < 0.45 && !isNonPlant;
  bool get isUnknownPlant =>
      (plantName == 'Unknown Plant' || isLowConfidence) && !isNonPlant;
  bool get isOffline => aiSource == 'offline' || aiSource == 'template';

  String get statusLabel {
    if (healthScore >= 90) return 'Excellent';
    if (healthScore >= 70) return 'Good';
    if (healthScore >= 50) return 'Fair';
    return 'Critical';
  }

  String get statusEmoji {
    if (healthScore >= 90) return '✅';
    if (healthScore >= 70) return '⚠️';
    if (healthScore >= 50) return '🟠';
    return '🔴';
  }

  ScanResult copyWith({
    String? id,
    String? userId,
    String? plantId,
    String? imageUrl,
    String? diseaseName,
    double? diseaseConfidence,
    String? plantName,
    int? healthScore,
    String? remedy,
    bool? flagged,
    DateTime? scannedAt,
    int? severityPercent,
    double? infectionArea,
    String? aiSource,
  }) {
    return ScanResult(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      plantId: plantId ?? this.plantId,
      imageUrl: imageUrl ?? this.imageUrl,
      diseaseName: diseaseName ?? this.diseaseName,
      diseaseConfidence: diseaseConfidence ?? this.diseaseConfidence,
      plantName: plantName ?? this.plantName,
      healthScore: healthScore ?? this.healthScore,
      remedy: remedy ?? this.remedy,
      flagged: flagged ?? this.flagged,
      scannedAt: scannedAt ?? this.scannedAt,
      severityPercent: severityPercent ?? this.severityPercent,
      infectionArea: infectionArea ?? this.infectionArea,
      aiSource: aiSource ?? this.aiSource,
    );
  }

  factory ScanResult.fromMap(Map<String, dynamic> map) => ScanResult(
        id: map['id']?.toString() ?? '',
        userId: map['user_id']?.toString() ?? '',
        plantId: map['plant_id']?.toString(),
        imageUrl: map['image_url']?.toString(),
        diseaseName: map['disease_name'] ?? 'Unknown',
        diseaseConfidence: (map['disease_confidence'] ?? 0.0).toDouble(),
        plantName: map['plant_name'] ?? 'Unknown Plant',
        healthScore: map['health_score'] ?? 0,
        remedy: map['remedy']?.toString(),
        flagged: map['flagged'] ?? false,
        scannedAt: DateTime.tryParse(map['scanned_at']?.toString() ?? '') ??
            DateTime.now(),
        severityPercent: map['severity_percent'] ?? 0,
        infectionArea: (map['infection_area'] ?? 0.0).toDouble(),
        aiSource: map['ai_source'] ?? 'cloud',
      );

  Map<String, dynamic> toMap({bool includeId = false}) {
    final map = <String, dynamic>{
      'user_id': userId,
      'image_url': imageUrl,
      'disease_name': diseaseName,
      'disease_confidence': diseaseConfidence,
      'plant_name': plantName,
      'health_score': healthScore,
      'remedy': remedy,
      'flagged': flagged,
      'scanned_at': scannedAt.toUtc().toIso8601String(),
      'severity_percent': severityPercent,
      'infection_area': infectionArea,
      'ai_source': aiSource,
    };
    if (plantId != null && plantId!.isNotEmpty) {
      map['plant_id'] = plantId;
    }
    if (includeId && id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

  Map<String, dynamic> toSupabaseMap({bool includeId = false}) {
    final map = <String, dynamic>{
      'user_id': userId,
      'image_url': imageUrl,
      'disease_name': diseaseName,
      'disease_confidence': diseaseConfidence,
      'plant_name': plantName,
      'health_score': healthScore,
      'remedy': remedy,
      'flagged': flagged,
      'scanned_at': scannedAt.toUtc().toIso8601String(),
    };
    if (plantId != null && plantId!.isNotEmpty) {
      map['plant_id'] = plantId;
    }
    if (includeId && id.isNotEmpty && !id.startsWith('temp_') && !id.startsWith('scan_')) {
      map['id'] = id;
    }
    return map;
  }
}
