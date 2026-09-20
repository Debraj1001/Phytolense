// lib/screens/dashboard/dashboard_screen.dart
// Minimalist, high-performance plant health dashboard
// Consolidated single-screen status card + offline SQLite sync + micro-animations.

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../../services/scan_limiter.dart';
import '../../services/trial_service.dart';
import '../../services/weather_service.dart';
import '../../data/local_database.dart';
import '../../models/app_user.dart';
import '../../models/scan_result.dart';
import '../../theme/colors.dart';
import '../../theme/design_tokens.dart';
import '../../providers/scan_limit_provider.dart';
import '../../providers/ai_limit_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/app_config_provider.dart';
import '../home/home_screen.dart';
import '../history/scan_detail_screen.dart';
import '../ai/chatbot_screen.dart';
import '../subscription/upgrade_screen.dart';
import '../business/retailer_directory_screen.dart';
import '../subscription/trial_activation_screen.dart';
import '../profile/subscription_details_screen.dart';
import '../../widgets/smooth_page_route.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/emergency_doctor_pass_sheet.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _supabase = SupabaseService();
  final _auth = AuthService();
  final _localDb = LocalDatabase();
  final _weather = WeatherService();

  bool _loading = true;
  AppUser? _user;
  Map<String, dynamic> _stats = {};
  List<ScanResult> _recentScans = [];
  SprayWindow? _sprayWindow;
  String _outbreakMessage = 'Checking for nearby outbreaks...';

  StreamSubscription? _userSub;
  StreamSubscription? _scansSub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _scansSub?.cancel();
    super.dispose();
  }

  void _load() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final uid = currentUser?.id ?? '';

    _userSub?.cancel();
    _scansSub?.cancel();

    // 1. Immediately load offline scans & stats from SQLite local database
    if (uid.isNotEmpty) {
      try {
        final localScans = await _localDb.getRecentScans(uid, limit: 5);
        final localStats = await _localDb.getUserStats(uid);
        if (mounted && localScans.isNotEmpty) {
          setState(() {
            _recentScans = localScans;
            _stats = {
              'total': localStats['total_scans'] ?? 0,
              'avgScore': localStats['avg_health'] ?? 0,
              'diseaseCount': localStats['diseases_found'] ?? 0,
            };
            _loading = false;
          });
        }
      } catch (e) {
        debugPrint('Dashboard local DB error: $e');
      }
    }

    if (currentUser == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final initialUser = await _auth.getUser(uid);
      if (mounted) {
        setState(() {
          _user = initialUser;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }

    _userSub = _auth.userStream(uid).listen((user) {
      if (mounted && user != null) {
        setState(() {
          _user = user;
          _loading = false;
        });
      }
    });

    _scansSub = _supabase.streamUserScans(uid).listen((scans) async {
      if (mounted) {
        final recent = scans.take(5).toList();
        final stats = await _supabase.getScanStats(uid);

        // Cache to local database for offline persistence
        for (final s in recent) {
          await _localDb.upsertScan(s, synced: true);
        }

        if (mounted) {
          setState(() {
            _recentScans = recent;
            _stats = stats;
            _loading = false;
          });
        }
      }
    }, onError: (e) {
      debugPrint('Dashboard Supabase stream error (offline mode): $e');
      if (mounted) setState(() => _loading = false);
    });

    try {
      final spray = await _weather.getSprayWindow();
      if (mounted) {
        setState(() => _sprayWindow = spray);
      }
    } catch (_) {}

    try {
      final response = await Supabase.instance.client
          .from('outbreak_alerts')
          .select()
          .order('reported_at', ascending: false)
          .limit(3);
      if (mounted) {
        if (response.isNotEmpty) {
          final count = response.length;
          final disease = response[0]['disease_name'] ?? 'unknown disease';
          setState(() {
            _outbreakMessage = '$count recent cases of $disease reported within 10km.';
          });
        } else {
          setState(() {
            _outbreakMessage = 'No major outbreaks reported nearby.';
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching outbreaks: $e');
      if (mounted) {
        setState(() {
          _outbreakMessage = 'Outbreak radar unavailable offline.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveUser = ref.watch(currentUserProvider).value ?? _user;
    final scanLimit = ref.watch(scanLimitProvider).value;
    final aiLimit = ref.watch(aiLimitProvider).value;
    final config = ref.watch(appConfigProvider).value;

    final displayName = liveUser?.displayName ?? 'Plant Lover';
    final firstName = displayName.split(' ').first;

    final totalScans = _stats['total'] as int? ?? liveUser?.scanCount ?? 0;
    final avgScore = _stats['avgScore'] as int? ?? 0;
    final diseaseCount = _stats['diseaseCount'] as int? ?? 0;

    final trialInfo = TrialService.getTrialInfo(
      liveUser,
      trialDays: config?.trialDays ?? 2,
    );

    final isAccessLocked = (trialInfo.isExpired || scanLimit?.isExpired == true || aiLimit?.isExpired == true) &&
        !(liveUser?.isPaidActive ?? false);

    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: Colors.white,
        onRefresh: () async {
          ref.read(scanLimitProvider.notifier).refreshLimit();
          ref.read(aiLimitProvider.notifier).refreshLimit();
          final uid = Supabase.instance.client.auth.currentUser?.id;
          if (uid != null) {
            final freshStats = await _supabase.getScanStats(uid);
            final freshUser = await _auth.getUser(uid);
            if (mounted) {
              setState(() {
                _stats = freshStats;
                _user = freshUser;
              });
            }
          }
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            // ── Greeting Header ─────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, $firstName 👋',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.lightTextPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      diseaseCount > 0
                          ? '$diseaseCount plant${diseaseCount > 1 ? 's' : ''} require attention'
                          : 'All plants look healthy today',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: diseaseCount > 0 ? AppColors.warning : AppColors.lightTextSecondary,
                        fontWeight: diseaseCount > 0 ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.05, end: 0, curve: Curves.easeOutCubic),

            const SizedBox(height: 14),

            // ── 1 Consolidated Unified Status Card ──────────────────────────
            _buildUnifiedStatusCard(
              user: liveUser,
              scanLimit: scanLimit,
              aiLimit: aiLimit,
              trialInfo: trialInfo,
              totalScans: totalScans,
              avgScore: avgScore,
              diseaseCount: diseaseCount,
            ).animate().fadeIn(duration: 400.ms, delay: 50.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),

            const SizedBox(height: 18),

            // ── Quick Actions ───────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (isAccessLocked) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                        );
                        return;
                      }
                      if (scanLimit != null && !scanLimit.canScan) {
                        if (scanLimit.isNotStarted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const TrialActivationScreen()),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                          );
                        }
                      } else {
                        ref.read(navIndexProvider.notifier).state = 1;
                      }
                    },
                    icon: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                    label: const Text(
                      'Scan Plant Leaf',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (isAccessLocked || (aiLimit != null && !aiLimit.canChat && aiLimit.isExpired)) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                        );
                      } else if (aiLimit != null && aiLimit.isNotStarted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const TrialActivationScreen()),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ChatbotScreen()),
                        );
                      }
                    },
                    icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.primary),
                    label: const Text(
                      'AI Doctor',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),

            const SizedBox(height: 10),

            // ── Secondary Actions ──────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (isAccessLocked) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RetailerDirectoryScreen()),
                        );
                      }
                    },
                    icon: const Icon(Icons.storefront_rounded, size: 16, color: AppColors.primaryDark),
                    label: const Text(
                      'Nearby Retailers (B2B)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primaryLight, width: 1.0),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: const Color(0xFFF8FAFC),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 400.ms, delay: 120.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),

            const SizedBox(height: 24),

            // ── Outbreak Radar Alert ───────────────────────────────────────
            BouncingButton(
              onTap: () {
                if (isAccessLocked) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                  );
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isAccessLocked ? const Color(0xFFF8FAFC) : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isAccessLocked ? const Color(0xFFE2E8F0) : const Color(0xFFFFEDD5),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isAccessLocked ? const Color(0xFFF1F5F9) : const Color(0xFFFFEDD5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isAccessLocked ? Icons.lock_outline_rounded : Icons.radar_rounded,
                        color: isAccessLocked ? const Color(0xFF64748B) : const Color(0xFFEA580C),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Community Radar',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isAccessLocked ? const Color(0xFF334155) : const Color(0xFF9A3412),
                                ),
                              ),
                              if (isAccessLocked) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'LOCKED',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isAccessLocked
                                ? 'Local outbreak detection locked. Upgrade to Pro/Farm to track nearby crop disease outbreaks.'
                                : _outbreakMessage,
                            style: TextStyle(
                              fontSize: 12,
                              color: isAccessLocked ? const Color(0xFF64748B) : const Color(0xFFC2410C),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isAccessLocked)
                      const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Color(0xFF94A3B8)),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 110.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),

            // ── Emergency Doctor Pass ───────────────────────────────────────
            BouncingButton(
              onTap: () => EmergencyDoctorPassSheet.show(context),
              child: Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Emergency Doctor Pass',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Get 1-on-1 expert help now for ₹10',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 14),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 115.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),

            // ── Spray Window Widget ───────────────────────────────────────
            if (isAccessLocked)
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF2F2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_clock_rounded, color: AppColors.error, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Spray Window & Climate Advisory',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.lightTextPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Locked · Upgrade to Pro or Farm to view optimal chemical/organic spray timing',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Unlock', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 120.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic)
            else if (_sprayWindow != null)
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _sprayWindow!.isOptimal ? const Color(0xFFD1FAE5) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _sprayWindow!.isOptimal ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _sprayWindow!.isOptimal ? Icons.check_circle_rounded : Icons.warning_rounded,
                          color: _sprayWindow!.isOptimal ? AppColors.primary : AppColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Spray Window: ${_sprayWindow!.isOptimal ? "Optimal" : "Not Ideal"}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _sprayWindow!.isOptimal ? AppColors.primary : AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _sprayWindow!.message,
                      style: TextStyle(
                        fontSize: 13,
                        color: _sprayWindow!.isOptimal ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                      ),
                    ),
                    if (!_sprayWindow!.isOptimal)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          "Next best time: ${_sprayWindow!.nextBestTime}",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildWeatherStat(Icons.thermostat, '${_sprayWindow!.current.temperature}°C', _sprayWindow!.isOptimal),
                        _buildWeatherStat(Icons.air, '${_sprayWindow!.current.windSpeed} km/h', _sprayWindow!.isOptimal),
                        _buildWeatherStat(Icons.water_drop, '${_sprayWindow!.current.precipitation} mm', _sprayWindow!.isOptimal),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 120.ms).slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),

            // ── Recent Diagnoses Header ─────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Diagnoses',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.lightTextPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                if (_recentScans.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      if (isAccessLocked) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                        );
                      } else {
                        ref.read(navIndexProvider.notifier).state = 2;
                      }
                    },
                    child: const Text(
                      'View all',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ),
              ],
            ).animate().fadeIn(duration: 350.ms, delay: 150.ms),

            const SizedBox(height: 10),

            // ── Recent Diagnoses List ───────────────────────────────────────
            if (_loading && _recentScans.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_recentScans.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: const Border.fromBorderSide(
                    BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.eco_outlined, color: AppColors.primary, size: 28),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No plant scans yet',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Point your camera at any leaf to diagnose diseases and get instant remedies.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.lightTextSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 350.ms, delay: 180.ms)
            else
              ..._recentScans.asMap().entries.map((entry) {
                final index = entry.key;
                final scan = entry.value;
                return _buildRecentScanCard(scan, isAccessLocked: isAccessLocked)
                    .animate()
                    .fadeIn(duration: 300.ms, delay: (180 + (index * 40)).ms)
                    .slideX(begin: 0.03, end: 0, curve: Curves.easeOutCubic);
              }),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // CONSOLIDATED UNIFIED STATUS CARD
  // Combines: Tier Badge + Trial Countdown + Quota Meters + Vitals in 1 Card
  // ═════════════════════════════════════════════════════════════════════════

  Widget _buildUnifiedStatusCard({
    required AppUser? user,
    required ScanLimitResult? scanLimit,
    required AiLimitResult? aiLimit,
    required TrialInfo trialInfo,
    required int totalScans,
    required int avgScore,
    required int diseaseCount,
  }) {
    final isFarm = user?.isFarm ?? false;
    final isPro = user?.isPro ?? false;
    final isNotStarted = scanLimit?.isNotStarted == true || aiLimit?.isNotStarted == true;
    final isExpired = scanLimit?.isExpired == true || aiLimit?.isExpired == true;

    final String scanRemainingStr;
    if (scanLimit == null) {
      scanRemainingStr = '--';
    } else if (isExpired) {
      scanRemainingStr = 'Trial Ended';
    } else if (scanLimit.isUnlimited) {
      scanRemainingStr = 'Unlimited';
    } else {
      scanRemainingStr = '${scanLimit.remaining}/${scanLimit.limit} left';
    }

    final String aiRemainingStr;
    if (aiLimit == null) {
      aiRemainingStr = '--';
    } else if (isExpired) {
      aiRemainingStr = 'Trial Ended';
    } else if (aiLimit.isUnlimited) {
      aiRemainingStr = 'Unlimited';
    } else {
      aiRemainingStr = '${aiLimit.remaining}/${aiLimit.limit} left';
    }

    final cfg = ref.watch(appConfigProvider).value ?? const AppConfig();

    // Badge styling & copy
    final String badgeLabel;
    final Color badgeColor;
    final Color badgeBg;
    if (isFarm) {
      badgeLabel = '🌾 FARM TIER';
      badgeColor = const Color(0xFF92400E);
      badgeBg = const Color(0xFFFEF3C7);
    } else if (isPro) {
      badgeLabel = '⚡ PRO TIER';
      badgeColor = const Color(0xFF0369A1);
      badgeBg = const Color(0xFFE0F2FE);
    } else if (isExpired) {
      badgeLabel = '🥀 TRIAL ENDED — UPGRADE';
      badgeColor = AppColors.error;
      badgeBg = const Color(0xFFFEE2E2);
    } else if (isNotStarted) {
      badgeLabel = '🌱 ${cfg.trialDays}-DAY FREE TRIAL';
      badgeColor = AppColors.primaryDark;
      badgeBg = const Color(0xFFD1FAE5);
    } else {
      badgeLabel = '🌱 ${trialInfo.remainingDays}D FREE TRIAL ACTIVE';
      badgeColor = AppColors.primaryDark;
      badgeBg = const Color(0xFFD1FAE5);
    }

    final String actionText;
    final VoidCallback onActionTap;
    if (isNotStarted) {
      actionText = 'Start Trial';
      onActionTap = () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TrialActivationScreen()),
      );
    } else if (isFarm || isPro) {
      actionText = 'Manage';
      onActionTap = () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => user != null
              ? SubscriptionDetailsScreen(user: user)
              : const UpgradeScreen(),
        ),
      );
    } else {
      actionText = 'Upgrade';
      onActionTap = () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UpgradeScreen()),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top Row: Status Pill & Action Link ─────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                    ),
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                        color: badgeColor,
                      ),
                    ),
                  ),
                  if (trialInfo.isActive && !isPro && !isFarm) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${trialInfo.remainingDays}d left',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ],
              ),
              InkWell(
                onTap: onActionTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        actionText,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 11,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Middle: Quota & Limits Micro-Bar ───────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Leaf Scans',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.lightTextMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            scanRemainingStr,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 26, color: const Color(0xFFE2E8F0)),
                const SizedBox(width: 14),
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_outlined,
                          size: 16,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI Consults',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.lightTextMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            aiRemainingStr,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.lightTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Bottom: 3 Key Health Vitals ───────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _buildCompactVital(
                  icon: Icons.qr_code_scanner_rounded,
                  iconColor: AppColors.primary,
                  label: 'Scans',
                  value: '$totalScans',
                ),
              ),
              Container(width: 1, height: 30, color: const Color(0xFFF1F5F9)),
              Expanded(
                child: _buildCompactVital(
                  icon: Icons.favorite_rounded,
                  iconColor: avgScore >= 80
                      ? AppColors.primary
                      : (avgScore >= 50 ? AppColors.warning : AppColors.error),
                  label: 'Avg Health',
                  value: totalScans > 0 ? '$avgScore%' : '--',
                ),
              ),
              Container(width: 1, height: 30, color: const Color(0xFFF1F5F9)),
              Expanded(
                child: _buildCompactVital(
                  icon: Icons.healing_rounded,
                  iconColor: diseaseCount > 0 ? AppColors.warning : const Color(0xFF94A3B8),
                  label: 'Needs Care',
                  value: '$diseaseCount',
                  isWarning: diseaseCount > 0,
                ),
              ),
            ],
          ),
          if (isExpired) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock_rounded, color: AppColors.error, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trial Ended — Features Locked',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'Must pay for Pro or Farm to continue using the app',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: const Size(58, 30),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Upgrade', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactVital({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    bool isWarning = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isWarning ? AppColors.warning : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.lightTextMuted,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentScanCard(ScanResult scan, {bool isAccessLocked = false}) {
    final isHealthy = scan.isHealthy;
    final statusColor = isHealthy ? AppColors.primary : AppColors.warning;

    return BouncingButton(
      scaleFactor: 0.98,
      onTap: () {
        if (isAccessLocked) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UpgradeScreen()),
          );
        } else {
          Navigator.push(
            context,
            SmoothPageRoute(page: ScanDetailScreen(scan: scan)),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: const Border.fromBorderSide(
            BorderSide(color: Color(0xFFE2E8F0)),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x070F172A),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildRecentScanThumbnail(scan, statusColor),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  scan.plantName.isNotEmpty ? scan.plantName : 'Unknown Plant',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.lightTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (scan.isOffline)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Text(
                    'Offline',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Text(
            scan.diseaseName,
            style: TextStyle(
              fontSize: 12,
              color: isHealthy ? AppColors.lightTextSecondary : AppColors.warning,
              fontWeight: isHealthy ? FontWeight.w400 : FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${scan.healthScore}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.lightTextMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentScanThumbnail(ScanResult scan, Color statusColor) {
    final url = scan.imageUrl;
    if (url == null || url.isEmpty) {
      return Icon(
        scan.isHealthy ? Icons.eco_rounded : Icons.coronavirus_outlined,
        color: statusColor,
        size: 22,
      );
    }

    if (url.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => Icon(
          scan.isHealthy ? Icons.eco_rounded : Icons.coronavirus_outlined,
          color: statusColor,
          size: 22,
        ),
      );
    }

    final file = File(url);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(
          scan.isHealthy ? Icons.eco_rounded : Icons.coronavirus_outlined,
          color: statusColor,
          size: 22,
        ),
      );
    }

    return Icon(
      scan.isHealthy ? Icons.eco_rounded : Icons.coronavirus_outlined,
      color: statusColor,
      size: 22,
    );
  }

  Widget _buildWeatherStat(IconData icon, String value, bool isOptimal) {
    return Row(
      children: [
        Icon(icon, size: 14, color: isOptimal ? const Color(0xFF047857) : const Color(0xFFB91C1C)),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isOptimal ? const Color(0xFF047857) : const Color(0xFFB91C1C),
          ),
        ),
      ],
    );
  }
}
