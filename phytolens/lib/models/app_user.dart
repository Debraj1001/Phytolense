// lib/models/app_user.dart

import '../config/constants.dart';

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final String subscriptionTier; // 'free' | 'pro' | 'farm'
  final DateTime? subscriptionExpiry;
  final int xp;
  final int level;
  final int streak;
  final int scanCount;
  final int dailyScanCount;
  final int dailyAiCount;
  final List<String> badges;
  final String? lastScanDate;
  final String? lastAiDate;
  final String? fcmToken;
  final bool banned;
  final String? phone;
  final String? location;
  final String? bio;
  final String? gardenType;
  final DateTime createdAt;
  final DateTime? trialActivatedAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.subscriptionTier = 'free',
    this.subscriptionExpiry,
    this.xp = 0,
    this.level = 1,
    this.streak = 0,
    this.scanCount = 0,
    this.dailyScanCount = 0,
    this.dailyAiCount = 0,
    this.badges = const [],
    this.lastScanDate,
    this.lastAiDate,
    this.fcmToken,
    this.banned = false,
    this.phone,
    this.location,
    this.bio,
    this.gardenType,
    required this.createdAt,
    this.trialActivatedAt,
  });

  bool get isPro => subscriptionTier == 'pro' || subscriptionTier == 'farm';
  bool get isFarm => subscriptionTier == 'farm';

  int get todayScans {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (lastScanDate == null) return 0;
    final cleanDate = lastScanDate!.length >= 10 ? lastScanDate!.substring(0, 10) : lastScanDate!;
    return (cleanDate == today) ? dailyScanCount : 0;
  }

  int get todayAi {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (lastAiDate == null) return 0;
    final cleanDate = lastAiDate!.length >= 10 ? lastAiDate!.substring(0, 10) : lastAiDate!;
    return (cleanDate == today) ? dailyAiCount : 0;
  }

  String get levelTitle {
    switch (level) {
      case 1: return '🌱 Seedling';
      case 2: return '🌿 Sprout';
      case 3: return '🪴 Plant';
      case 4: return '🌳 Tree';
      case 5: return '🌳 Forest';
      case 6: return '🏔️ Mountain';
      case 7: return '🌍 World';
      case 8: return '🌌 Galaxy';
      case 9: return '🌟 Legend';
      case 10: return '👑 PhytoLens Master';
      default: return '🌱 Seedling';
    }
  }

  bool get hasTrialStarted => trialActivatedAt != null;

  bool get isPaidActive {
    final tier = subscriptionTier.toLowerCase();
    if (tier != AppConstants.tierPro && tier != AppConstants.tierFarm) {
      return false;
    }
    if (subscriptionExpiry != null && subscriptionExpiry!.isBefore(DateTime.now())) {
      return false;
    }
    return true;
  }

  bool hasActiveAccess(int trialDays) {
    if (isPaidActive) return true;
    if (trialActivatedAt == null) return true;
    return !isFreeTrialExpired(trialDays);
  }

  bool isFreeTrialActive(int trialDays) {
    if (trialActivatedAt == null) return false;
    return !isFreeTrialExpired(trialDays);
  }

  bool isFreeTrialExpired(int trialDays) {
    final tier = subscriptionTier.toLowerCase();
    if (tier == AppConstants.tierPro || tier == AppConstants.tierFarm) {
      if (subscriptionExpiry != null && subscriptionExpiry!.isBefore(DateTime.now())) {
        // Paid subscription expired — fall through to trial check
      } else {
        return false;
      }
    }
    // If the trial has never been activated, it hasn't expired yet
    if (trialActivatedAt == null) return false;
    final expiryDate = trialActivatedAt!.add(Duration(days: trialDays));
    return DateTime.now().isAfter(expiryDate);
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['display_name'] ?? 'Plant Lover',
      avatarUrl: map['avatar_url'],
      subscriptionTier: map['subscription_tier'] ?? AppConstants.tierFree,
      subscriptionExpiry: map['subscription_expiry'] != null 
          ? DateTime.tryParse(map['subscription_expiry'])
          : null,
      xp: map['xp'] ?? 0,
      level: map['level'] ?? 1,
      streak: map['streak'] ?? 0,
      scanCount: map['scan_count'] ?? 0,
      dailyScanCount: map['daily_scan_count'] ?? 0,
      dailyAiCount: map['daily_ai_count'] ?? 0,
      badges: List<String>.from(map['badges'] ?? []),
      lastScanDate: map['last_scan_date'],
      lastAiDate: map['last_ai_date'],
      fcmToken: map['fcm_token'],
      banned: map['banned'] ?? false,
      phone: map['phone'],
      location: map['location'],
      bio: map['bio'],
      gardenType: map['garden_type'],
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
      trialActivatedAt: map['trial_activated_at'] != null 
          ? DateTime.tryParse(map['trial_activated_at']) 
          : null,
    );
  }

  /// Convenience factory for Firestore DocumentSnapshot
  factory AppUser.fromFirestore(dynamic doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return AppUser.fromMap({...data, 'uid': doc.id});
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'display_name': displayName,
    'avatar_url': avatarUrl,
    'subscription_tier': subscriptionTier,
    'subscription_expiry': subscriptionExpiry?.toIso8601String(),
    'xp': xp,
    'level': level,
    'streak': streak,
    'scan_count': scanCount,
    'daily_scan_count': dailyScanCount,
    'daily_ai_count': dailyAiCount,
    'badges': badges,
    'last_scan_date': lastScanDate,
    'last_ai_date': lastAiDate,
    'fcm_token': fcmToken,
    'banned': banned,
    'phone': phone,
    'location': location,
    'bio': bio,
    'garden_type': gardenType,
    'created_at': createdAt.toIso8601String(),
    'trial_activated_at': trialActivatedAt?.toIso8601String(),
  };

  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? avatarUrl,
    String? subscriptionTier,
    DateTime? subscriptionExpiry,
    int? xp,
    int? level,
    int? streak,
    int? scanCount,
    int? dailyScanCount,
    int? dailyAiCount,
    List<String>? badges,
    String? lastScanDate,
    String? lastAiDate,
    String? fcmToken,
    bool? banned,
    String? phone,
    String? location,
    String? bio,
    String? gardenType,
    DateTime? createdAt,
    DateTime? trialActivatedAt,
  }) =>
      AppUser(
        uid: uid ?? this.uid,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        subscriptionTier: subscriptionTier ?? this.subscriptionTier,
        subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
        xp: xp ?? this.xp,
        level: level ?? this.level,
        streak: streak ?? this.streak,
        scanCount: scanCount ?? this.scanCount,
        dailyScanCount: dailyScanCount ?? this.dailyScanCount,
        dailyAiCount: dailyAiCount ?? this.dailyAiCount,
        badges: badges ?? this.badges,
        lastScanDate: lastScanDate ?? this.lastScanDate,
        lastAiDate: lastAiDate ?? this.lastAiDate,
        fcmToken: fcmToken ?? this.fcmToken,
        banned: banned ?? this.banned,
        phone: phone ?? this.phone,
        location: location ?? this.location,
        bio: bio ?? this.bio,
        gardenType: gardenType ?? this.gardenType,
        createdAt: createdAt ?? this.createdAt,
        trialActivatedAt: trialActivatedAt ?? this.trialActivatedAt,
      );
}
