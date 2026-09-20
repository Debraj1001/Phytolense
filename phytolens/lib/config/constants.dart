// lib/config/constants.dart

class AppConstants {
  // App Info
  static const String appName = 'PhytoLens';
  static const String appTagline = 'Your Plant\'s Best Health Companion';
  static const String appVersion = '1.0.0';

  // Subscription Tiers
  static const String tierFree = 'free';
  static const String tierPro = 'pro';
  static const String tierFarm = 'farm';

  // Trial System
  static const int defaultTrialDays = 2;
  static const int trialWarningDaysThreshold = 2;
  // Post-trial "starter" limits (never fully locked out)
  static const int starterDailyScanLimit = 1;
  static const int starterDailyAiLimit = 1;

  // Daily Limits
  static const int freeDailyScanLimit = 50;
  static const int freeDailyAiLimit = 50;
  static const int proDailyAiLimit = 100;

  // Prices (in paise for Razorpay)
  static const int proMonthlyPaise = 4900;    // ₹49
  static const int farmMonthlyPaise = 19900;  // ₹199

  // Groq Model
  static const String groqModel = 'qwen/qwen3.8-27b';

  // XP Values
  static const int xpScan = 10;
  static const int xpDisease = 25;
  static const int xpTreatment = 15;
  static const int xpStreak = 20;
  static const int xpWeekChallenge = 50;
  static const int xpShare = 5;
  static const int xpReferral = 100;
  static const int xpOnboarding = 30;

  // Onboarding key
  static const String onboardingKey = 'onboarding_complete';
  static const String userRoleKey = 'user_role';

  // Supabase Tables
  static const String tableUsers = 'users';
  static const String tableScanHistory = 'scan_history';
  static const String tableAiUsage = 'ai_usage';
  static const String tablePayments = 'payments';
  static const String tableCoupons = 'coupons';
  static const String tableAppConfig = 'app_config';

  // Routes
  static const String routeSplash = '/';
  static const String routeOnboarding = '/onboarding';
  static const String routeLogin = '/login';
  static const String routeHome = '/home';
}

class BadgeIds {
  static const String firstScan = 'first_scan';
  static const String plantDetective = 'plant_detective';
  static const String healthHero = 'health_hero';
  static const String remedyMaster = 'remedy_master';
  static const String perfectScore = 'perfect_score';
  static const String weekWarrior = 'week_warrior';
  static const String monthlyMaster = 'monthly_master';
  static const String globalCitizen = 'global_citizen';
  static const String aiGuru = 'ai_guru';
  static const String farmerPro = 'farmer_pro';
  static const String phytolensLegend = 'phytolens_legend';
}

class HealthScore {
  static String getLabel(int score) {
    if (score >= 90) return 'Excellent';
    if (score >= 70) return 'Good';
    if (score >= 50) return 'Fair';
    return 'Critical';
  }

  static String getEmoji(int score) {
    if (score >= 90) return '🟢';
    if (score >= 70) return '🟡';
    if (score >= 50) return '🟠';
    return '🔴';
  }
}
