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

  Plant copyWith({
    String? id,
    String? userId,
    String? name,
    String? type,
    String? imageUrl,
    int? latestHealthScore,
    String? latestDisease,
    DateTime? addedAt,
    DateTime? lastScannedAt,
    List<HealthRecord>? healthHistory,
  }) {
    return Plant(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      imageUrl: imageUrl ?? this.imageUrl,
      latestHealthScore: latestHealthScore ?? this.latestHealthScore,
      latestDisease: latestDisease ?? this.latestDisease,
      addedAt: addedAt ?? this.addedAt,
      lastScannedAt: lastScannedAt ?? this.lastScannedAt,
      healthHistory: healthHistory ?? this.healthHistory,
    );
  }

  factory Plant.fromMap(Map<String, dynamic> map) => Plant(
        id: map['id']?.toString() ?? '',
        userId: map['user_id']?.toString() ?? '',
        name: map['name']?.toString() ?? 'Unknown',
        type: (map['plant_type'] ?? map['type'] ?? 'Other').toString(),
        imageUrl: map['image_url']?.toString(),
        latestHealthScore: (map['latest_health_score'] as num?)?.toInt() ?? 0,
        latestDisease: map['latest_disease']?.toString(),
        addedAt: DateTime.tryParse(map['created_at']?.toString() ??
                map['added_at']?.toString() ??
                '') ??
            DateTime.now(),
        lastScannedAt: map['last_scanned_at'] != null
            ? DateTime.tryParse(map['last_scanned_at'].toString())
            : null,
        healthHistory: [],
      );

  Map<String, dynamic> toMap({bool includeId = false}) {
    final map = <String, dynamic>{
      'user_id': userId,
      'name': name,
      'type': type,
      'plant_type': type,
      'image_url': imageUrl,
      'latest_health_score': latestHealthScore,
      'latest_disease': latestDisease,
      'added_at': addedAt.toUtc().toIso8601String(),
      'created_at': addedAt.toUtc().toIso8601String(),
      'last_scanned_at': lastScannedAt?.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (includeId && id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }
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
