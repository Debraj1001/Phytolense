// lib/models/app_config.dart

class AppConfig {
  final dynamic id;
  final int freeTierDays;
  final int freeDailyScanLimit;
  final int freeDailyAiLimit;
  final int proDailyScanLimit;
  final int proDailyAiLimit;
  final int farmDailyScanLimit;
  final int farmDailyAiLimit;
  final int farmCreationLimitFree;
  final int farmCreationLimitPro;
  final int farmCreationLimitFarm;
  final int proMonthlyPrice;
  final int farmMonthlyPrice;
  final bool maintenanceMode;
  final String latestVersion;
  final DateTime updatedAt;

  const AppConfig({
    this.id = 1,
    this.freeTierDays = 3,
    this.freeDailyScanLimit = 15,
    this.freeDailyAiLimit = 15,
    this.proDailyScanLimit = 50,
    this.proDailyAiLimit = 50,
    this.farmDailyScanLimit = -1,
    this.farmDailyAiLimit = -1,
    this.farmCreationLimitFree = 1,
    this.farmCreationLimitPro = 5,
    this.farmCreationLimitFarm = -1,
    this.proMonthlyPrice = 49,
    this.farmMonthlyPrice = 199,
    this.maintenanceMode = false,
    this.latestVersion = '1.0.0',
    required this.updatedAt,
  });

  factory AppConfig.fromMap(Map<String, dynamic> map) {
    return AppConfig(
      id: map['id'] ?? 1,
      freeTierDays: (map['free_tier_days'] as num?)?.toInt() ?? 3,
      freeDailyScanLimit: (map['free_daily_scan_limit'] as num?)?.toInt() ?? 15,
      freeDailyAiLimit: (map['free_daily_ai_limit'] as num?)?.toInt() ?? 15,
      proDailyScanLimit: (map['pro_daily_scan_limit'] as num?)?.toInt() ?? 50,
      proDailyAiLimit: (map['pro_daily_ai_limit'] as num?)?.toInt() ?? 50,
      farmDailyScanLimit: (map['farm_daily_scan_limit'] as num?)?.toInt() ?? -1,
      farmDailyAiLimit: (map['farm_daily_ai_limit'] as num?)?.toInt() ?? -1,
      farmCreationLimitFree: (map['farm_creation_limit_free'] as num?)?.toInt() ?? 1,
      farmCreationLimitPro: (map['farm_creation_limit_pro'] as num?)?.toInt() ?? 5,
      farmCreationLimitFarm: (map['farm_creation_limit_farm'] as num?)?.toInt() ?? -1,
      proMonthlyPrice: (map['pro_monthly_price'] as num?)?.toInt() ?? 49,
      farmMonthlyPrice: (map['farm_monthly_price'] as num?)?.toInt() ?? 199,
      maintenanceMode: map['maintenance_mode'] ?? false,
      latestVersion: map['latest_version'] ?? '1.0.0',
      updatedAt: DateTime.tryParse(map['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'free_tier_days': freeTierDays,
    'free_daily_scan_limit': freeDailyScanLimit,
    'free_daily_ai_limit': freeDailyAiLimit,
    'pro_daily_scan_limit': proDailyScanLimit,
    'pro_daily_ai_limit': proDailyAiLimit,
    'farm_daily_scan_limit': farmDailyScanLimit,
    'farm_daily_ai_limit': farmDailyAiLimit,
    'farm_creation_limit_free': farmCreationLimitFree,
    'farm_creation_limit_pro': farmCreationLimitPro,
    'farm_creation_limit_farm': farmCreationLimitFarm,
    'pro_monthly_price': proMonthlyPrice,
    'farm_monthly_price': farmMonthlyPrice,
    'maintenance_mode': maintenanceMode,
    'latest_version': latestVersion,
    'updated_at': DateTime.now().toIso8601String(),
  };

  AppConfig copyWith({
    dynamic id,
    int? freeTierDays,
    int? freeDailyScanLimit,
    int? freeDailyAiLimit,
    int? proDailyScanLimit,
    int? proDailyAiLimit,
    int? farmDailyScanLimit,
    int? farmDailyAiLimit,
    int? farmCreationLimitFree,
    int? farmCreationLimitPro,
    int? farmCreationLimitFarm,
    int? proMonthlyPrice,
    int? farmMonthlyPrice,
    bool? maintenanceMode,
    String? latestVersion,
    DateTime? updatedAt,
  }) =>
      AppConfig(
        id: id ?? this.id,
        freeTierDays: freeTierDays ?? this.freeTierDays,
        freeDailyScanLimit: freeDailyScanLimit ?? this.freeDailyScanLimit,
        freeDailyAiLimit: freeDailyAiLimit ?? this.freeDailyAiLimit,
        proDailyScanLimit: proDailyScanLimit ?? this.proDailyScanLimit,
        proDailyAiLimit: proDailyAiLimit ?? this.proDailyAiLimit,
        farmDailyScanLimit: farmDailyScanLimit ?? this.farmDailyScanLimit,
        farmDailyAiLimit: farmDailyAiLimit ?? this.farmDailyAiLimit,
        farmCreationLimitFree: farmCreationLimitFree ?? this.farmCreationLimitFree,
        farmCreationLimitPro: farmCreationLimitPro ?? this.farmCreationLimitPro,
        farmCreationLimitFarm: farmCreationLimitFarm ?? this.farmCreationLimitFarm,
        proMonthlyPrice: proMonthlyPrice ?? this.proMonthlyPrice,
        farmMonthlyPrice: farmMonthlyPrice ?? this.farmMonthlyPrice,
        maintenanceMode: maintenanceMode ?? this.maintenanceMode,
        latestVersion: latestVersion ?? this.latestVersion,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
