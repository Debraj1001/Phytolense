// lib/services/gamification_service.dart

import '../config/constants.dart';
import 'supabase_service.dart';

class GamificationService {
  final SupabaseService _supabase = SupabaseService();

  // ─── XP ───────────────────────────────────────────────────────────────────

  Future<({int newXp, int newLevel, bool leveledUp})> awardXP(
    String userId,
    int xp,
  ) async {
    final appUser = await _supabase.getUser(userId);
    final currentXp = appUser?.xp ?? 0;
    final newXp = currentXp + xp;
    final newLevel = _calcLevel(newXp);
    final oldLevel = _calcLevel(currentXp);
    final leveledUp = newLevel > oldLevel;

    await _supabase.updateUser(userId, {
      'xp': newXp,
      'level': newLevel,
    });

    return (newXp: newXp, newLevel: newLevel, leveledUp: leveledUp);
  }

  int _calcLevel(int xp) {
    if (xp >= 50001) return 10;
    if (xp >= 20001) return 9;
    if (xp >= 10001) return 8;
    if (xp >= 5001) return 7;
    if (xp >= 2001) return 6;
    if (xp >= 1001) return 5;
    if (xp >= 601) return 4;
    if (xp >= 301) return 3;
    if (xp >= 101) return 2;
    return 1;
  }

  // ─── Streak ───────────────────────────────────────────────────────────────

  Future<({int streak, bool extended})> updateStreak(String userId) async {
    final appUser = await _supabase.getUser(userId);
    if (appUser == null) return (streak: 0, extended: false);
    
    final lastScan = appUser.lastScanDate;
    final currentStreak = appUser.streak;
    final today = _todayStr();
    final yesterday = _yesterdayStr();

    if (lastScan == today) {
      return (streak: currentStreak, extended: false);
    }

    int newStreak;
    bool extended = false;

    if (lastScan == yesterday) {
      newStreak = currentStreak + 1;
      extended = true;
    } else {
      newStreak = 1;
    }

    await _supabase.updateUser(userId, {
      'streak': newStreak,
      'last_scan_date': today,
    });

    if (extended) {
      await awardXP(userId, AppConstants.xpStreak);
    }

    return (streak: newStreak, extended: extended);
  }

  String _todayStr() => DateTime.now().toIso8601String().substring(0, 10);
  String _yesterdayStr() => DateTime.now()
      .subtract(const Duration(days: 1))
      .toIso8601String()
      .substring(0, 10);

  // ─── Badges ───────────────────────────────────────────────────────────────

  Future<List<String>> checkAndAwardBadges(String userId) async {
    final appUser = await _supabase.getUser(userId);
    if (appUser == null) return [];
    
    final badges = List<String>.from(appUser.badges);
    final scanCount = await _supabase.getTotalScanCount(userId);
    final streak = appUser.streak;

    final newBadges = <String>[];

    void checkBadge(String id, bool condition, int xpReward) {
      if (!badges.contains(id) && condition) {
        badges.add(id);
        newBadges.add(id);
        awardXP(userId, xpReward);
      }
    }

    checkBadge(BadgeIds.firstScan, scanCount >= 1, 10);
    checkBadge(BadgeIds.plantDetective, scanCount >= 10, 50);
    checkBadge(BadgeIds.farmerPro, scanCount >= 100, 500);
    checkBadge(BadgeIds.weekWarrior, streak >= 7, 100);
    checkBadge(BadgeIds.monthlyMaster, streak >= 30, 300);
    checkBadge(BadgeIds.phytolensLegend, badges.length >= 10, 1000);

    if (newBadges.isNotEmpty) {
      await _supabase.updateUser(userId, {'badges': badges});
    }

    return newBadges;
  }

  // ─── Scan Count ───────────────────────────────────────────────────────────



  // ─── After Scan (all-in-one) ──────────────────────────────────────────────

  Future<PostScanReward> processScanReward(String userId) async {
    final xpResult = await awardXP(userId, AppConstants.xpScan);
    final streakResult = await updateStreak(userId);
    final newBadges = await checkAndAwardBadges(userId);

    return PostScanReward(
      xpEarned: AppConstants.xpScan,
      totalXp: xpResult.newXp,
      newLevel: xpResult.newLevel,
      leveledUp: xpResult.leveledUp,
      streak: streakResult.streak,
      streakExtended: streakResult.extended,
      newBadges: newBadges,
    );
  }
}

class PostScanReward {
  final int xpEarned;
  final int totalXp;
  final int newLevel;
  final bool leveledUp;
  final int streak;
  final bool streakExtended;
  final List<String> newBadges;

  const PostScanReward({
    required this.xpEarned,
    required this.totalXp,
    required this.newLevel,
    required this.leveledUp,
    required this.streak,
    required this.streakExtended,
    required this.newBadges,
  });

  bool get hasRewards => leveledUp || streakExtended || newBadges.isNotEmpty;
}
