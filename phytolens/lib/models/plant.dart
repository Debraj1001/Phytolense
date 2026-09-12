// lib/models/plant.dart

class Plant {
  final String id;
  final String userId;
  final String name;
  final String type;
  final String? imageUrl;
  final int latestHealthScore;
  final String? latestDisease;
  final DateTime addedAt;
  final DateTime? lastScannedAt;
  final List<HealthRecord> healthHistory;

  const Plant({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    this.imageUrl,
    this.latestHealthScore = 0,
    this.latestDisease,
    required this.addedAt,
    this.lastScannedAt,
    this.healthHistory = const [],
  });

  String get statusEmoji {
    if (latestHealthScore >= 90) return '✅';
    if (latestHealthScore >= 70) return '⚠️';
    if (latestHealthScore >= 50) return '🟠';
    return '🔴';
  }

  factory Plant.fromMap(Map<String, dynamic> map) => Plant(
    id: map['id'] ?? '',
    userId: map['user_id'] ?? '',
    name: map['name'] ?? 'Unknown',
    type: map['plant_type'] ?? map['type'] ?? 'Other',
    imageUrl: map['image_url'],
    latestHealthScore: map['latest_health_score'] ?? 0,
    latestDisease: map['latest_disease'],
    addedAt: DateTime.tryParse(map['created_at'] ?? map['added_at'] ?? '') ?? DateTime.now(),
    lastScannedAt: map['last_scanned_at'] != null
        ? DateTime.tryParse(map['last_scanned_at'])
        : null,
    healthHistory: [],
  );

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'name': name,
    'type': type,
    'image_url': imageUrl,
    'latest_health_score': latestHealthScore,
    'latest_disease': latestDisease,
    'added_at': addedAt.toIso8601String(),
    'last_scanned_at': lastScannedAt?.toIso8601String(),
  };
}

class HealthRecord {
  final DateTime date;
  final int score;
  final String disease;

  const HealthRecord({
    required this.date,
    required this.score,
    required this.disease,
  });
}
