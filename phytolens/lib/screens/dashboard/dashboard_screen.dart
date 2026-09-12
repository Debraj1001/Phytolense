// lib/screens/dashboard/dashboard_screen.dart
// Minimalist, high-performance plant health dashboard

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../../services/scan_limiter.dart';
import '../../models/app_user.dart';
import '../../models/scan_result.dart';
import '../../theme/colors.dart';
import '../../theme/design_tokens.dart';
import '../../providers/scan_limit_provider.dart';
import '../../providers/ai_limit_provider.dart';
import '../../providers/user_provider.dart';
import '../home/home_screen.dart';
import '../history/scan_detail_screen.dart';
import '../ai/chatbot_screen.dart';
import '../subscription/upgrade_screen.dart';
import '../../widgets/smooth_page_route.dart';
import '../../widgets/bouncing_button.dart';
import '../../widgets/trial_banner.dart';
import '../../services/trial_service.dart';
import '../../providers/app_config_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _supabase = SupabaseService();
  final _auth = AuthService();

  bool _loading = true;
  AppUser? _user;
  Map<String, dynamic> _stats = {};
  List<ScanResult> _recentScans = [];

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
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final uid = currentUser.uid;

    _userSub?.cancel();
    _scansSub?.cancel();

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

        if (mounted) {
          setState(() {
            _recentScans = recent;
            _stats = stats;
            _loading = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final liveUser = ref.watch(currentUserProvider).value ?? _user;
    final scanLimit = ref.watch(scanLimitProvider).value;
    final aiLimit = ref.watch(aiLimitProvider).value;

    final displayName = liveUser?.displayName ?? 'Plant Lover';
    final firstName = displayName.split(' ').first;

    final totalScans = _stats['total'] as int? ?? liveUser?.scanCount ?? 0;
    final avgScore = _stats['avgScore'] as int? ?? 0;
    final diseaseCount = _stats['diseaseCount'] as int? ?? 0;

    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: Colors.white,
        onRefresh: () async {
          ref.read(scanLimitProvider.notifier).refreshLimit();
          ref.read(aiLimitProvider.notifier).refreshLimit();
          final uid = FirebaseAuth.instance.currentUser?.uid;
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
            ),

            const SizedBox(height: 12),

            // ── Trial Status Banner ─────────────────────────────────────────
            Builder(builder: (_) {
              final config = ref.watch(appConfigProvider).value;
              final trialInfo = TrialService.getTrialInfo(
                liveUser,
                trialDays: config?.trialDays ?? 2,
              );
              return TrialBanner(
                trialInfo: trialInfo,
                onUpgradeTap: () {
                  Navigator.push(
                    context,
                    SmoothPageRoute(page: const UpgradeScreen()),
                  );
                },
              );
            }),

            const SizedBox(height: 12),

            // ── Live Tier & Daily Quota Card ────────────────────────────────
            _buildQuotaCard(liveUser, scanLimit, aiLimit),

            const SizedBox(height: 18),

            // ── Vitals Summary Row ──────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _buildVitalPill(
                    label: 'Total Scanned',
                    value: '$totalScans',
                    icon: Icons.qr_code_scanner_rounded,
                    accentColor: AppColors.primaryLight,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildVitalPill(
                    label: 'Avg Health',
                    value: totalScans > 0 ? '$avgScore%' : '--',
                    icon: Icons.favorite_rounded,
                    accentColor: avgScore >= 80
                        ? AppColors.primaryLight
                        : (avgScore >= 50 ? AppColors.warning : AppColors.error),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildVitalPill(
                    label: 'Needs Care',
                    value: '$diseaseCount',
                    icon: Icons.healing_rounded,
                    accentColor: diseaseCount > 0 ? AppColors.warning : AppColors.textMuted,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Quick Actions ───────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ref.read(navIndexProvider.notifier).state = 1;
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ChatbotScreen()),
                      );
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
            ),

            const SizedBox(height: 28),

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
                      ref.read(navIndexProvider.notifier).state = 2;
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
            ),

            const SizedBox(height: 10),

            // ── Recent Diagnoses List ───────────────────────────────────────
            if (_loading && _recentScans.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
              )
            else if (_recentScans.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: const Border.fromBorderSide(
                    BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x0A0F172A),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.eco_outlined,
                      size: 40,
                      color: AppColors.primary.withValues(alpha: 0.4),
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
              )
            else
              ..._recentScans.map((scan) => _buildRecentScanCard(scan)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuotaCard(AppUser? user, ScanLimitResult? scanLimit, AiLimitResult? aiLimit) {
    final isFarm = user?.isFarm ?? false;
    final isPro = user?.isPro ?? false;

    final String scanRemainingStr;
    if (scanLimit == null) {
      scanRemainingStr = '--';
    } else if (scanLimit.limit <= 0 || scanLimit.remaining <= -1) {
      scanRemainingStr = 'Unlimited';
    } else {
      scanRemainingStr = '${scanLimit.remaining} / ${scanLimit.limit} left';
    }

    final String aiRemainingStr;
    if (aiLimit == null) {
      aiRemainingStr = '--';
    } else if (aiLimit.limit <= 0 || aiLimit.remaining <= -1) {
      aiRemainingStr = 'Unlimited';
    } else {
      aiRemainingStr = '${aiLimit.remaining} / ${aiLimit.limit} left';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0A0F172A),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: isFarm
                          ? const Color(0xFFFFD700).withValues(alpha: 0.15)
                          : (isPro
                              ? const Color(0xFF00BCD4).withValues(alpha: 0.15)
                              : AppColors.primary.withValues(alpha: 0.15)),
                      borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                    ),
                    child: Text(
                      isFarm ? '🌾 FARM TIER' : (isPro ? '⚡ PRO TIER' : '🌱 FREE PLAN'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: isFarm
                            ? const Color(0xFFFFD700)
                            : (isPro ? const Color(0xFF00BCD4) : AppColors.primaryLight),
                      ),
                    ),
                  ),
                ],
              ),
              if (!isPro)
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                    );
                  },
                  child: const Row(
                    children: [
                      Text(
                        'Upgrade',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryLight,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.primaryLight),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.document_scanner_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Leaf Scans', style: TextStyle(fontSize: 11, color: AppColors.lightTextMuted)),
                        Text(
                          scanRemainingStr,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.lightTextPrimary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.smart_toy_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI Queries', style: TextStyle(fontSize: 11, color: AppColors.lightTextMuted)),
                        Text(
                          aiRemainingStr,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.lightTextPrimary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVitalPill({
    required String label,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: const Border.fromBorderSide(
          BorderSide(color: Color(0xFFE2E8F0)),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x080F172A),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: accentColor),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppColors.lightTextMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentScanCard(ScanResult scan) {
    final isHealthy = scan.isHealthy;
    final statusColor = isHealthy ? AppColors.primary : AppColors.warning;

    return BouncingButton(
      scaleFactor: 0.98,
      onTap: () {
        Navigator.push(
          context,
          SmoothPageRoute(page: ScanDetailScreen(scan: scan)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: const Border.fromBorderSide(
            BorderSide(color: Color(0xFFE2E8F0)),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0x090F172A),
              blurRadius: 4,
              offset: const Offset(0, 1),
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
            child: Icon(
              isHealthy ? Icons.eco_rounded : Icons.coronavirus_outlined,
              color: statusColor,
              size: 22,
            ),
          ),
          title: Text(
            scan.plantName.isNotEmpty ? scan.plantName : 'Unknown Plant',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.lightTextPrimary,
            ),
          ),
          subtitle: Text(
            scan.diseaseName,
            style: TextStyle(
              fontSize: 12,
              color: isHealthy ? AppColors.lightTextSecondary : AppColors.warning,
              fontWeight: isHealthy ? FontWeight.w400 : FontWeight.w600,
            ),
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
}
