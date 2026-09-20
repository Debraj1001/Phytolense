// lib/screens/profile/profile_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../home/home_screen.dart';
import '../../services/auth_service.dart';
import '../../models/app_user.dart';
import '../../providers/ai_settings_provider.dart';
import '../../services/supabase_service.dart';
import '../../theme/colors.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/shimmer_widget.dart';

import '../../config/constants.dart';
import 'package:intl/intl.dart';
import '../subscription/upgrade_screen.dart';
import 'subscription_details_screen.dart';
import 'garden_screen.dart';
import 'model_manager_screen.dart';
import '../history/analytics_screen.dart';
import 'help_support_screen.dart';
import 'about_screen.dart';
import 'privacy_screen.dart';
import 'edit_profile_screen.dart';
import '../../widgets/smooth_page_route.dart';
import '../../widgets/bouncing_button.dart';
import '../../services/trial_service.dart';
import '../../providers/app_config_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _auth = AuthService();
  final _supabase = SupabaseService();
  AppUser? _user;
  int _scanCount = 0;
  bool _loading = true;

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
    if (currentUser == null) return;
    final uid = currentUser.id;

    _userSub?.cancel();
    _scansSub?.cancel();

    try {
      final user = await _auth.getUser(uid);
      final scanCount = await _supabase.getTotalScanCount(uid);
      if (mounted) {
        setState(() {
          _user = user;
          _scanCount = scanCount;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }

    _userSub = _auth.userStream(uid).listen((user) {
      if (mounted && user != null) {
        setState(() => _user = user);
      }
    });

    _scansSub = _supabase.streamUserScans(uid).listen((scans) {
      if (mounted) {
        setState(() => _scanCount = scans.length);
      }
    });
  }

  Future<void> _signOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to sign out of your account?', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (shouldSignOut != true) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    await _auth.signOut();

    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppConstants.routeLogin,
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(navIndexProvider, (prev, next) {
      if (next == 4) {
        _load();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.backgroundDark,
            flexibleSpace: FlexibleSpaceBar(
              background: _loading
                  ? const Center(child: ShimmerProfileHeader())
                  : _buildProfileHeader(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (_loading)
                  Column(children: [
                    ShimmerBox(width: double.infinity, height: 80, radius: 16),
                    const SizedBox(height: 12),
                    ShimmerBox(width: double.infinity, height: 80, radius: 16),
                  ])
                else ...[
                  // Stats row
                  _buildStatsRow().animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: 16),

                  // Subscription card
                  if (_user != null)
                    _buildUpgradeCard().animate().fadeIn(delay: 150.ms),

                  const SizedBox(height: 16),

                  // Menu items
                  _buildMenuSection(),

                  const SizedBox(height: 70),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    if (_user == null) return const SizedBox.shrink();

    final tier = _user!.subscriptionTier;
    final tierColor = tier == 'farm'
        ? const Color(0xFFFFD700)  // Gold for Farm
        : tier == 'pro'
            ? const Color(0xFF00BCD4)  // Cyan for Pro
            : AppColors.primaryLight;  // Default green

    return Container(
      decoration: BoxDecoration(
        color: tierColor.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(
            color: tierColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 10, left: 20, right: 20, bottom: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Avatar — DiceBear URL, Google Photo or initial fallback
              BouncingButton(
                onTap: () async {
                  if (_user != null) {
                    final updated = await Navigator.push(
                      context,
                      SmoothPageRoute(page: EditProfileScreen(user: _user!)),
                    );
                    if (updated == true) _load();
                  }
                },
                child: Stack(
                  children: [
                    Container(
                      width: 105,
                      height: 105,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: tierColor.withValues(alpha: 0.5), width: 2.5),
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                      child: ClipOval(
                        child: _user!.avatarUrl != null && _user!.avatarUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: _user!.avatarUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => _AvatarFallback(name: _user!.displayName),
                              )
                            : _AvatarFallback(name: _user!.displayName),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AppColors.cardDarker,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.backgroundDark, width: 2),
                        ),
                        child: Icon(Icons.edit_rounded, size: 13, color: tierColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _user!.displayName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: tierColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: tierColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (tier == 'farm') const Text('🌾 ', style: TextStyle(fontSize: 11))
                        else if (tier == 'pro') const Text('⚡ ', style: TextStyle(fontSize: 11)),
                        Text(
                          tier == 'farm' ? 'FARM PACK' : tier == 'pro' ? 'PRO' : 'FREE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: tierColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _user!.levelTitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Dedicated Edit Profile Pill Button
              BouncingButton(
                onTap: () async {
                  if (_user != null) {
                    final updated = await Navigator.push(
                      context,
                      SmoothPageRoute(page: EditProfileScreen(user: _user!)),
                    );
                    if (updated == true) _load();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, size: 13, color: AppColors.primaryDark),
                      SizedBox(width: 6),
                      Text(
                        'Edit Profile Details',
                        style: TextStyle(fontSize: 12, color: AppColors.primaryDark, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _StatCard(
          value: '$_scanCount',
          label: 'Total Scans',
          icon: Icons.camera_alt_outlined,
        ),
        const SizedBox(width: 10),
        _StatCard(
          value: '${_user?.xp ?? 0}',
          label: 'XP Points',
          icon: Icons.star_border,
        ),
        const SizedBox(width: 10),
        _StatCard(
          value: '${_user?.streak ?? 0}',
          label: 'Day Streak',
          icon: Icons.local_fire_department_outlined,
        ),
        const SizedBox(width: 10),
        _StatCard(
          value: '${_user?.badges.length ?? 0}',
          label: 'Badges',
          icon: Icons.emoji_events_outlined,
        ),
      ],
    );
  }

  Widget _buildUpgradeCard() {
    final tier = _user?.subscriptionTier ?? 'free';
    final isPro = tier == 'pro';
    final isFarm = tier == 'farm';
    final isPaid = isPro || isFarm;
    final expiry = _user?.subscriptionExpiry;
    final now = DateTime.now();
    final daysRemaining = expiry != null ? expiry.difference(now).inDays : 0;
    
    return GestureDetector(
      onTap: () {
        if (isPaid && _user != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SubscriptionDetailsScreen(user: _user!)),
          ).then((_) => _load());
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => UpgradeScreen(isPro: isPro)),
          ).then((_) => _load());
        }
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isFarm
                ? const [Color(0xFFD97706), Color(0xFFB45309), Color(0xFF78350F)]
                : (isPro
                    ? const [Color(0xFF0284C7), Color(0xFF0369A1), Color(0xFF075985)]
                    : const [Color(0xFF059669), Color(0xFF0D9488), Color(0xFF0284C7)]),
          ),
          borderRadius: BorderRadius.circular(AppTokens.radiusLG),
          boxShadow: [
            BoxShadow(
              color: (isFarm ? const Color(0xFFF59E0B) : AppColors.primary).withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFarm
                    ? Icons.agriculture_rounded
                    : (isPro ? Icons.bolt_rounded : Icons.star_rounded),
                size: 24,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isFarm ? 'Farm Pack Active' : (isPro ? 'Pro Plan Active' : 'Upgrade to Pro / Farm'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (isPaid) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isPaid && expiry != null
                        ? '${daysRemaining > 0 ? '$daysRemaining days remaining' : 'Expires today'} · ${DateFormat('MMM dd, yyyy').format(expiry)}'
                        : (isPaid
                            ? 'Unlimited Scans & Agronomy Active'
                            : '50-100+ scans/day · AI chats · Analytics'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSection() {
    final tier = _user?.subscriptionTier ?? 'free';
    final isPaid = tier == 'pro' || tier == 'farm';
    final planLabel = tier == 'farm' ? 'Farm Pack' : (tier == 'pro' ? 'Pro Tier' : 'Free Plan');

    // Compute trial status
    final config = ref.watch(appConfigProvider).value;
    final trialInfo = TrialService.getTrialInfo(_user, trialDays: config?.trialDays ?? 2);
    final trialLabel = trialInfo.badgeLabel;

    final items = [
      _MenuItem(
        icon: Icons.person_outline,
        label: 'Edit Profile Details',
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
        onTap: () {
          if (_user != null) {
            Navigator.push(
              context,
              SmoothPageRoute(page: EditProfileScreen(user: _user!)),
            ).then((_) => _load());
          }
        },
      ),
      _MenuItem(
        icon: Icons.workspace_premium_outlined,
        label: 'My Subscription & Limits',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trialLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  trialLabel.replaceFirst(' · ', ''),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: trialInfo.isExpired
                        ? AppColors.error
                        : (trialInfo.isNotStarted ? AppColors.primaryDark : AppColors.warning),
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (isPaid ? AppColors.secondary : AppColors.primary).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                planLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isPaid ? AppColors.secondary : AppColors.primaryDark,
                ),
              ),
            ),
          ],
        ),
        onTap: () {
          if (_user != null) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SubscriptionDetailsScreen(user: _user!)),
            ).then((_) => _load());
          }
        },
      ),
      _MenuItem(
        icon: Icons.local_florist_outlined,
        label: 'My Garden',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GardenScreen()),
        ),
      ),
      _MenuItem(
        icon: Icons.cloud_download_outlined,
        label: 'Offline AI Model',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ModelManagerScreen()),
          );
        },
      ),
      _MenuItem(
        icon: Icons.auto_awesome,
        label: 'AI Cloud Engine Enabled',
        trailing: Switch(
          value: ref.watch(aiEngineProvider),
          onChanged: (val) {
            ref.read(aiEngineProvider.notifier).toggle();
          },
          activeThumbColor: AppColors.primary,
        ),
        onTap: () {
          ref.read(aiEngineProvider.notifier).toggle();
        },
      ),
      _MenuItem(
        icon: Icons.insights_rounded,
        label: 'Crop Health Analytics',
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: (isPaid ? AppColors.healthGood : AppColors.primary).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            isPaid ? 'UNLOCKED' : 'PRO',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: isPaid ? AppColors.healthGood : AppColors.primaryDark,
            ),
          ),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
        ),
      ),
      _MenuItem(
        icon: Icons.notifications_outlined,
        label: 'Notifications',
        onTap: () {},
      ),
      _MenuItem(
        icon: Icons.language_outlined,
        label: 'Language',
        trailing: const Text('English',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
        onTap: () {},
      ),
      _MenuItem(
        icon: Icons.privacy_tip_outlined,
        label: 'Privacy Policy',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PrivacyScreen()),
        ),
      ),
      _MenuItem(
        icon: Icons.help_outline,
        label: 'Help & Support',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
        ),
      ),
      _MenuItem(
        icon: Icons.info_outline,
        label: 'About PhytoLens',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AboutScreen()),
        ),
      ),
      _MenuItem(
        icon: Icons.logout,
        label: 'Sign Out',
        color: AppColors.error,
        onTap: _signOut,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final isLast = e.key == items.length - 1;
          return Column(
            children: [
              e.value,
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 52,
                  color: AppColors.textMuted.withValues(alpha: 0.1),
                ),
            ],
          );
        }).toList(),
      ),
    ).animate().fadeIn(delay: 300.ms);
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTokens.radiusMD),
          border: Border.all(color: AppColors.lightBorder),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: AppColors.primaryDark),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final Color? color;
  final VoidCallback? onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.trailing,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return BouncingButton(
      scaleFactor: 0.98,
      onTap: onTap,
      child: ListTile(
        leading: Icon(icon, color: c, size: 22),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: color ?? AppColors.textPrimary,
          ),
        ),
        trailing: trailing ?? Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String name;
  const _AvatarFallback({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.2),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryLight,
          ),
        ),
      ),
    );
  }
}

