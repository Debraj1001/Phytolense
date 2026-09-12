// lib/models/scan_result.dart

class ScanResult {
  final String id;
  final String userId;
  final String? imageUrl;
  final String diseaseName;
  final double diseaseConfidence;  // 0.0 - 1.0
  final String plantName;
  final int healthScore;           // 0 - 100
  final String? remedy;
  final bool flagged;
  final DateTime scannedAt;

  const ScanResult({
    required this.id,
    required this.userId,
    this.imageUrl,
    required this.diseaseName,
    required this.diseaseConfidence,
    required this.plantName,
    required this.healthScore,
    this.remedy,
    this.flagged = false,
    required this.scannedAt,
  });

  bool get isHealthy => diseaseName == 'Healthy' || healthScore >= 90;
  bool get isNonPlant => diseaseName.contains('Object') || diseaseName.contains('Non-Plant') || plantName.toLowerCase().contains('hand') || plantName.toLowerCase().contains('laptop') || plantName.toLowerCase().contains('phone') || plantName.toLowerCase().contains('keyboard');
  bool get isLowConfidence => diseaseConfidence < 0.45 && !isNonPlant;
  bool get isUnknownPlant => (plantName == 'Unknown Plant' || isLowConfidence) && !isNonPlant;

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

  factory ScanResult.fromMap(Map<String, dynamic> map) => ScanResult(
    id: map['id'] ?? '',
    userId: map['user_id'] ?? '',
    imageUrl: map['image_url'],
    diseaseName: map['disease_name'] ?? 'Unknown',
    diseaseConfidence: (map['disease_confidence'] ?? 0.0).toDouble(),
    plantName: map['plant_name'] ?? 'Unknown Plant',
    healthScore: map['health_score'] ?? 0,
    remedy: map['remedy'],
    flagged: map['flagged'] ?? false,
    scannedAt: DateTime.tryParse(map['scanned_at'] ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
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
}
