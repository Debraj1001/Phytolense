// lib/models/app_user.dart

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
  final List<String> badges;
  final String? lastScanDate;
  final String? fcmToken;
  final bool banned;
  final DateTime createdAt;

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
    this.badges = const [],
    this.lastScanDate,
    this.fcmToken,
    this.banned = false,
    required this.createdAt,
  });

  bool get isPro => subscriptionTier == 'pro' || subscriptionTier == 'farm';
  bool get isFarm => subscriptionTier == 'farm';

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      displayName: map['display_name']?.toString() ?? 'User',
      avatarUrl: map['avatar_url']?.toString(),
      subscriptionTier: map['subscription_tier']?.toString() ?? 'free',
      subscriptionExpiry: map['subscription_expiry'] != null 
          ? DateTime.tryParse(map['subscription_expiry'].toString())
          : null,
      xp: (map['xp'] as num?)?.toInt() ?? 0,
      level: (map['level'] as num?)?.toInt() ?? 1,
      streak: (map['streak'] as num?)?.toInt() ?? 0,
      scanCount: (map['scan_count'] as num?)?.toInt() ?? 0,
      badges: List<String>.from(map['badges'] ?? []),
      lastScanDate: map['last_scan_date']?.toString(),
      fcmToken: map['fcm_token']?.toString(),
      banned: map['banned'] == true,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
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
    'badges': badges,
    'last_scan_date': lastScanDate,
    'fcm_token': fcmToken,
    'banned': banned,
    'created_at': createdAt.toIso8601String(),
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
    List<String>? badges,
    String? lastScanDate,
    String? fcmToken,
    bool? banned,
    DateTime? createdAt,
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
        badges: badges ?? this.badges,
        lastScanDate: lastScanDate ?? this.lastScanDate,
        fcmToken: fcmToken ?? this.fcmToken,
        banned: banned ?? this.banned,
        createdAt: createdAt ?? this.createdAt,
      );
}
