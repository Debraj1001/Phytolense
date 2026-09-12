// lib/models/scan_item.dart

class ScanItem {
  final String id;
  final String userId;
  final String plantName;
  final String diseaseName;
  final double diseaseConfidence;
  final int healthScore;
  final String? remedy;
  final String? imageUrl;
  final DateTime scannedAt;

  const ScanItem({
    required this.id,
    required this.userId,
    required this.plantName,
    required this.diseaseName,
    required this.diseaseConfidence,
    required this.healthScore,
    this.remedy,
    this.imageUrl,
    required this.scannedAt,
  });

  bool get isHealthy => diseaseName.toLowerCase().contains('healthy');

  factory ScanItem.fromMap(Map<String, dynamic> map) {
    return ScanItem(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      plantName: map['plant_name']?.toString() ?? 'Unknown Plant',
      diseaseName: map['disease_name']?.toString() ?? 'Unknown',
      diseaseConfidence: (map['disease_confidence'] as num?)?.toDouble() ?? 0.0,
      healthScore: (map['health_score'] as num?)?.toInt() ?? 0,
      remedy: map['remedy']?.toString(),
      imageUrl: map['image_url']?.toString(),
      scannedAt: DateTime.tryParse(map['scanned_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
