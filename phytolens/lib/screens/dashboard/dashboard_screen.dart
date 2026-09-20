// lib/screens/dashboard/dashboard_screen.dart
// Minimalist, high-performance plant health dashboard
// Consolidated single-screen status card + offline SQLite sync + micro-animations.

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
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
import '../../providers/language_provider.dart';
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
import '../../widgets/glass_card.dart';
import '../../widgets/glass_button.dart';
import '../../widgets/language_selector_sheet.dart';

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
  String _outbreakMessage = 'checking_outbreaks';

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

  String _getGreeting(WidgetRef ref) {
    final hour = DateTime.now().hour;
    if (hour < 12) return ref.tr('good_morning');
    if (hour < 17) return ref.tr('good_afternoon');
    return ref.tr('good_evening');
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
        // Cache all remote scans to local database
        await _localDb.batchUpsertScans(scans, synced: true);

        final allRecent = await _localDb.getRecentScans(uid, limit: 5);
        final localStats = await _localDb.getUserStats(uid);
        Map<String, dynamic> stats = {
          'total': localStats['total_scans'] ?? 0,
          'avgScore': localStats['avg_health'] ?? 0,
          'diseaseCount': localStats['diseases_found'] ?? 0,
        };

        try {
          final cloudStats = await _supabase.getScanStats(uid);
          if ((cloudStats['total'] as int? ?? 0) >= (stats['total'] as int? ?? 0)) {
            stats = cloudStats;
          }
        } catch (_) {}

        if (mounted) {
          setState(() {
            _recentScans = allRecent.isNotEmpty ? allRecent : scans.take(5).toList();
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
          final disease = response[0]['disease_name'] ?? 'unknown_disease';
          setState(() {
            _outbreakMessage = 'outbreak_count|$count|$disease';
          });
        } else {
          setState(() {
            _outbreakMessage = 'no_outbreaks';
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching outbreaks: $e');
      if (mounted) {
        setState(() {
          _outbreakMessage = 'radar_unavailable';
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

    final displayName = liveUser?.displayName ?? ref.tr('plant_lover');
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
      body: Stack(
        children: [
          // Background ambient gradient for glassmorphism (hardware accelerated shader)
          Positioned(
            top: -150,
            right: -100,
            child: IgnorePointer(
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.16),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -100,
            child: IgnorePointer(
              child: Container(
                width: 300,
                height: 300,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0x206366F1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          RefreshIndicator(
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
                      '${_getGreeting(ref)}, $firstName 👋',
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
                          ? ref.tr('plants_require_attention').replaceAll('{count}', diseaseCount.toString())
                          : ref.tr('all_plants_healthy'),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: diseaseCount > 0 ? AppColors.warning : AppColors.lightTextSecondary,
                        fontWeight: diseaseCount > 0 ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.language, color: AppColors.lightTextPrimary),
                  onPressed: () => LanguageSelectorSheet.show(context, ref),
                ),
              ],
            ),

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
            ),

            const SizedBox(height: 18),

            // ── Quick Actions ───────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: GlassButton.action(
                    label: ref.tr('scan_now'),
                    icon: Icons.camera_alt_rounded,
                    style: GlassButtonStyle.emerald,
                    onTap: () {
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
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: GlassButton.action(
                    label: ref.tr('ai_specialist'),
                    icon: Icons.auto_awesome_rounded,
                    style: GlassButtonStyle.adaptive,
                    accentColor: AppColors.primary,
                    onTap: () {
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
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Secondary Actions ──────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: GlassButton.action(
                    label: ref.tr('nearby_retailers'),
                    icon: Icons.storefront_rounded,
                    style: GlassButtonStyle.light,
                    accentColor: AppColors.primaryDark,
                    onTap: () {
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
                  ),
                ),
              ],
            ),

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
              child: GlassCard(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                borderRadius: 20,
                color: isAccessLocked ? const Color(0xFFF8FAFC) : const Color(0xFFFFF7ED),
                borderColor: isAccessLocked ? const Color(0xFFE2E8F0) : const Color(0xFFFFEDD5),
                blur: 16,
                alpha: 0.75,
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
                                ref.tr('community_radar'),
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
                                  child: Text(ref.tr('locked_caps'),
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
                                ? ref.tr('radar_locked_msg')
                                : _outbreakMessage.startsWith('outbreak_count|')
                                    ? ref.tr('outbreak_count').replaceAll('{count}', _outbreakMessage.split('|')[1]).replaceAll('{disease}', _outbreakMessage.split('|')[2] == 'unknown_disease' ? ref.tr('unknown_disease') : _outbreakMessage.split('|')[2])
                                    : ref.tr(_outbreakMessage),
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
            ),

            // ── Emergency Doctor Pass ───────────────────────────────────────
            BouncingButton(
              onTap: () => EmergencyDoctorPassSheet.show(context),
              child: GlassCard(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                gradient: const LinearGradient(
                  colors: [Color(0xCC6366F1), Color(0x994F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: 20,
                borderColor: Colors.white.withValues(alpha: 0.2),
                blur: 24,
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
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(ref.tr('emergency_doctor_pass'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            ref.tr('emergency_doctor_msg'),
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
            ),

            // ── Spray Window Widget ───────────────────────────────────────
            if (isAccessLocked)
              GlassCard(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(18),
                borderRadius: 20,
                blur: 24,
                alpha: 0.85,
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
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(ref.tr('spray_window_advisory'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.lightTextPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            ref.tr('spray_locked_msg'),
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
                      child: Text(ref.tr('unlock'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              )
            else if (_sprayWindow != null)
              GlassCard(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(20),
                borderRadius: 20,
                color: _sprayWindow!.isOptimal ? const Color(0xFFD1FAE5) : const Color(0xFFFEF2F2),
                borderColor: _sprayWindow!.isOptimal ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                blur: 16,
                alpha: 0.75,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Weather description header with emoji
                    Row(
                      children: [
                        Text(
                          _sprayWindow!.current.weatherEmoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _sprayWindow!.current.weatherDescription,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.lightTextPrimary,
                                ),
                              ),
                              Text(
                                ref.tr('feels_like').replaceAll('{temp}', _sprayWindow!.current.feelsLike.toStringAsFixed(1)),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Rain probability badge
                        if (_sprayWindow!.current.precipitationProbability > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _sprayWindow!.current.precipitationProbability >= 30
                                  ? const Color(0xFFFEE2E2)
                                  : const Color(0xFFF0F9FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '🌧️ ${_sprayWindow!.current.precipitationProbability}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _sprayWindow!.current.precipitationProbability >= 30
                                    ? const Color(0xFFB91C1C)
                                    : const Color(0xFF0369A1),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Spray status
                    Row(
                      children: [
                        Icon(
                          _sprayWindow!.isOptimal ? Icons.check_circle_rounded : Icons.warning_rounded,
                          color: _sprayWindow!.isOptimal ? AppColors.primary : AppColors.error,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${ref.tr("spray_window_status")}: ${_sprayWindow!.isOptimal ? "${ref.tr("optimal")} ✓" : ref.tr("not_ideal")}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _sprayWindow!.isOptimal ? AppColors.primary : AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
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
                          "${ref.tr('next_best_time')}: ${_sprayWindow!.nextBestTime}",
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
                        _buildWeatherStat(Icons.thermostat, '${_sprayWindow!.current.temperature.toStringAsFixed(1)}°C', _sprayWindow!.isOptimal),
                        _buildWeatherStat(Icons.air, '${_sprayWindow!.current.windSpeed.toStringAsFixed(1)} km/h', _sprayWindow!.isOptimal),
                        _buildWeatherStat(Icons.opacity, '${_sprayWindow!.current.humidity.toStringAsFixed(0)}%', _sprayWindow!.isOptimal),
                        _buildWeatherStat(Icons.water_drop, '${_sprayWindow!.current.precipitation.toStringAsFixed(1)} mm', _sprayWindow!.isOptimal),
                      ],
                    ),
                  ],
                ),
              ),


            // ── Recent Diagnoses Header ─────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(ref.tr('recent_diagnoses'),
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
                    child: Text(ref.tr('view_all'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ),
              ],
            ),

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
                    Text(ref.tr('no_scans_yet'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.lightTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(ref.tr('no_scans_subtitle'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.lightTextSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._recentScans.asMap().entries.map((entry) {
                final scan = entry.value;
                return _buildRecentScanCard(scan, isAccessLocked: isAccessLocked);
              }),
            ],
          ),
        ),
      ],
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
      scanRemainingStr = ref.tr('trial_ended');
    } else if (scanLimit.isUnlimited) {
      scanRemainingStr = ref.tr('unlimited');
    } else {
      scanRemainingStr = ref.tr('quota_left').replaceAll('{remaining}', scanLimit.remaining.toString()).replaceAll('{limit}', scanLimit.limit.toString());
    }

    final String aiRemainingStr;
    if (aiLimit == null) {
      aiRemainingStr = '--';
    } else if (isExpired) {
      aiRemainingStr = ref.tr('trial_ended');
    } else if (aiLimit.isUnlimited) {
      aiRemainingStr = ref.tr('unlimited');
    } else {
      aiRemainingStr = ref.tr('quota_left').replaceAll('{remaining}', aiLimit.remaining.toString()).replaceAll('{limit}', aiLimit.limit.toString());
    }

    final cfg = ref.watch(appConfigProvider).value ?? const AppConfig();

    // Badge styling & copy
    final String badgeLabel;
    final Color badgeColor;
    final Color badgeBg;
    if (isFarm) {
      badgeLabel = ref.tr('farm_tier_badge');
      badgeColor = const Color(0xFF92400E);
      badgeBg = const Color(0xFFFEF3C7);
    } else if (isPro) {
      badgeLabel = ref.tr('pro_tier_badge');
      badgeColor = const Color(0xFF0369A1);
      badgeBg = const Color(0xFFE0F2FE);
    } else if (isExpired) {
      badgeLabel = ref.tr('trial_ended_badge');
      badgeColor = AppColors.error;
      badgeBg = const Color(0xFFFEE2E2);
    } else if (isNotStarted) {
      badgeLabel = ref.tr('trial_start_badge').replaceAll('{days}', cfg.trialDays.toString());
      badgeColor = AppColors.primaryDark;
      badgeBg = const Color(0xFFD1FAE5);
    } else {
      badgeLabel = ref.tr('trial_active_badge').replaceAll('{days}', trialInfo.remainingDays.toString());
      badgeColor = AppColors.primaryDark;
      badgeBg = const Color(0xFFD1FAE5);
    }

    final String actionText;
    final VoidCallback onActionTap;
    if (isNotStarted) {
      actionText = ref.tr('start_free_trial');
      onActionTap = () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TrialActivationScreen()),
      );
    } else if (isFarm || isPro) {
      actionText = ref.tr('manage');
      onActionTap = () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => user != null
              ? SubscriptionDetailsScreen(user: user)
              : const UpgradeScreen(),
        ),
      );
    } else {
      actionText = ref.tr('upgrade');
      onActionTap = () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UpgradeScreen()),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 22,
      blur: 24,
      alpha: 0.85,
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
                      ref.tr('days_left').replaceAll('{days}', trialInfo.remainingDays.toString()),
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
                          Text(ref.tr('leaf_scans'),
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
                          Text(ref.tr('ai_consults'),
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
                  label: ref.tr('scans'),
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
                  label: ref.tr('avg_health'),
                  value: totalScans > 0 ? '$avgScore%' : '--',
                ),
              ),
              Container(width: 1, height: 30, color: const Color(0xFFF1F5F9)),
              Expanded(
                child: _buildCompactVital(
                  icon: Icons.healing_rounded,
                  iconColor: diseaseCount > 0 ? AppColors.warning : const Color(0xFF94A3B8),
                  label: ref.tr('needs_care'),
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
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(ref.tr('trial_ended_locked'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          ref.tr('must_pay_msg'),
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
                    child: Text(ref.tr('upgrade'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
      child: GlassCard(
        margin: const EdgeInsets.only(bottom: 10),
        borderRadius: 16,
        blur: 16,
        alpha: 0.85,
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
                  scan.plantName.isNotEmpty ? scan.plantName : ref.tr('unknown_plant'),
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
                  child: Text(ref.tr('offline'),
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
