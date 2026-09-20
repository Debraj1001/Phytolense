// lib/models/app_config.dart

class AppConfig {
  // Daily scan limits
  final int freeScanLimit;
  final int proScanLimit;
  final int farmScanLimit; // <= 0 indicates unlimited

  // Daily AI chat limits
  final int freeAiLimit;
  final int proAiLimit;
  final int farmAiLimit; // <= 0 indicates unlimited

  // Prices in Rupees (e.g. 49, 199)
  final int proMonthlyPrice;
  final int farmMonthlyPrice;

  int get proMonthlyPaise => proMonthlyPrice * 100;
  int get farmMonthlyPaise => farmMonthlyPrice * 100;

  // Trial & Farm Creation Limits
  final int freeTierDays;
  final int farmCreationLimitFree;
  final int farmCreationLimitPro;
  final int farmCreationLimitFarm;

  // Feature flags
  final bool gardenEnabled;
  final bool bulkExportEnabled;

  // Paid Trial Config
  final double trialPrice;
  final int trialDays;
  final bool trialEnabled;

  // Maintenance Lockdown Mode
  final bool maintenanceMode;

  const AppConfig({
    this.freeScanLimit = 15,
    this.proScanLimit = 50,
    this.farmScanLimit = 100,
    this.freeAiLimit = 15,
    this.proAiLimit = 50,
    this.farmAiLimit = 100,
    this.proMonthlyPrice = 49,
    this.farmMonthlyPrice = 199,
    this.freeTierDays = 3,
    this.farmCreationLimitFree = 1,
    this.farmCreationLimitPro = 5,
    this.farmCreationLimitFarm = 100,
    this.gardenEnabled = true,
    this.bulkExportEnabled = true,
    this.trialPrice = 1.0,
    this.trialDays = 2,
    this.trialEnabled = true,
    this.maintenanceMode = false,
  });

  factory AppConfig.fromPlansAndConfig(List<Map<String, dynamic>> plans, Map<String, dynamic> m) {
    Map<String, dynamic>? freePlan;
    Map<String, dynamic>? proPlan;
    Map<String, dynamic>? farmPlan;

    for (final p in plans) {
      final id = p['id']?.toString().toLowerCase();
      if (id == 'free') freePlan = p;
      if (id == 'pro') proPlan = p;
      if (id == 'farm') farmPlan = p;
    }

    int parseLimit(dynamic val, int defaultVal) {
      if (val == null) return defaultVal;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? defaultVal;
    }

    return AppConfig(
      freeScanLimit: parseLimit(freePlan?['daily_scan_limit'] ?? m['free_daily_scan_limit'], 15),
      proScanLimit: parseLimit(proPlan?['daily_scan_limit'] ?? m['pro_daily_scan_limit'], 50),
      farmScanLimit: parseLimit(farmPlan?['daily_scan_limit'] ?? m['farm_daily_scan_limit'], 100),

      freeAiLimit: parseLimit(freePlan?['daily_ai_limit'] ?? m['free_daily_ai_limit'], 15),
      proAiLimit: parseLimit(proPlan?['daily_ai_limit'] ?? m['pro_daily_ai_limit'], 50),
      farmAiLimit: parseLimit(farmPlan?['daily_ai_limit'] ?? m['farm_daily_ai_limit'], 100),

      proMonthlyPrice: parseLimit(proPlan?['monthly_price'] ?? m['pro_monthly_price'], 49),
      farmMonthlyPrice: parseLimit(farmPlan?['monthly_price'] ?? m['farm_monthly_price'], 199),

      freeTierDays: parseLimit(m['free_tier_days'], 3),
      farmCreationLimitFree: parseLimit(freePlan?['farm_limit'] ?? m['farm_creation_limit_free'], 1),
      farmCreationLimitPro: parseLimit(proPlan?['farm_limit'] ?? m['farm_creation_limit_pro'], 5),
      farmCreationLimitFarm: parseLimit(farmPlan?['farm_limit'] ?? m['farm_creation_limit_farm'], 100),

      gardenEnabled: farmPlan?['garden_enabled'] as bool? ?? m['garden_enabled'] as bool? ?? true,
      bulkExportEnabled: farmPlan?['bulk_export_enabled'] as bool? ?? m['bulk_export_enabled'] as bool? ?? true,
      
      trialPrice: (m['trial_price'] as num?)?.toDouble() ?? 1.0,
      trialDays: parseLimit(m['trial_days'], 2),
      trialEnabled: m['trial_enabled'] as bool? ?? true,
      maintenanceMode: m['maintenance_mode'] as bool? ?? false,
    );
  }

  factory AppConfig.fromMap(Map<String, dynamic> m) {
    return AppConfig.fromPlansAndConfig([], m);
  }

  // ── Display helpers ────────────────────────────────────────────────────────

  String get proPrice => '₹$proMonthlyPrice';
  String get farmPrice => '₹$farmMonthlyPrice';

  String _limitLabel(int n) => (n <= 0) ? 'Unlimited' : '$n/day';

  String get freeScanLabel => _limitLabel(freeScanLimit);
  String get proScanLabel  => _limitLabel(proScanLimit);
  String get farmScanLabel => _limitLabel(farmScanLimit);

  String get freeAiLabel => _limitLabel(freeAiLimit);
  String get proAiLabel  => _limitLabel(proAiLimit);
  String get farmAiLabel => _limitLabel(farmAiLimit);
}
