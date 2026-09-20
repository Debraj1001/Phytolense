// lib/screens/profile/garden_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../models/plant.dart';
import '../../theme/colors.dart';
import '../../widgets/shimmer_widget.dart';
import '../../widgets/plant_card.dart';
import '../../data/supported_crops.dart';
import '../subscription/upgrade_screen.dart';
import '../subscription/trial_activation_screen.dart';
import 'plant_detail_screen.dart';

class GardenScreen extends StatefulWidget {
  const GardenScreen({super.key});

  @override
  State<GardenScreen> createState() => _GardenScreenState();
}

class _GardenScreenState extends State<GardenScreen> {
  final _supabase = SupabaseService();
  List<Plant> _plants = [];
  bool _loading = true;
  bool _isPaid = false;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _load() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final user = await _supabase.getUser(uid);
      if (mounted) {
        setState(() {
          _isPaid = user?.isPaidActive == true;
        });
      }
    } catch (_) {}

    _sub?.cancel();
    _sub = _supabase.streamGarden(uid).listen((plants) {
      if (mounted) {
        setState(() { _plants = plants; _loading = false; });
      }
    }, onError: (_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: AppColors.lightBg,
        elevation: 0,
        title: const Text(
          'My Garden',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isPaid)
            IconButton(
              icon: const Icon(Icons.add, size: 24, color: AppColors.primary),
              onPressed: _addPlant,
            ),
        ],
      ),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: ShimmerPlantGrid(count: 4),
            )
          : !_isPaid
              ? _buildLockedGardenHero()
              : _plants.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: () async {
                        _load();
                      },
                      color: AppColors.primary,
                      backgroundColor: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: _plants.length,
                      itemBuilder: (_, i) => PlantCard(
                        plant: _plants[i],
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlantDetailScreen(plant: _plants[i]),
                            ),
                          );
                        },
                      ).animate(delay: Duration(milliseconds: i * 80)).fadeIn(),
                    ),
                  ),
                ),
    );
  }

  Widget _buildLockedGardenHero() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_florist_rounded, color: AppColors.primary, size: 36),
              ),
              const SizedBox(height: 18),
              const Text(
                'My Garden (Pro & Farm)',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Multi-plot plant health tracking, custom watering intervals, and disease recovery progress logs are exclusive to Pro Plan and Farm Pack subscribers.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.45),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ...[
                '🌱 Track up to 5 plots (Pro) or unlimited (Farm Pack)',
                '💧 Automated irrigation & treatment schedule reminders',
                '📈 Historical health recovery charts and diagnosis logs',
              ].map(
                (feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          feature,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                ),
                icon: const Icon(Icons.flash_on_rounded, size: 18, color: Colors.white),
                label: const Text(
                  'UPGRADE TO UNLOCK GARDEN',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🌱', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          const Text(
            'Your garden is empty',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start scanning plants to track their health.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Your First Plant'),
            onPressed: _addPlant,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addPlant() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final user = await _supabase.getUser(uid);
    final tier = (user?.subscriptionTier ?? 'free').toLowerCase();
    final isPaid = tier == 'pro' || tier == 'farm';
    
    final config = await _supabase.getAppConfig();
    int maxPlants = config['farm_creation_limit_free'] ?? 1;
    if (tier == 'pro') maxPlants = config['farm_creation_limit_pro'] ?? 5;
    if (tier == 'farm') maxPlants = -1; // Farm Pack is unlimited!
    
    // Only check trial for free tier users
    if (!isPaid) {
      final isExpired = user != null && user.isFreeTrialExpired(config['trial_days'] ?? config['free_tier_days'] ?? 2);
      final hasNotStarted = user?.trialActivatedAt == null;

      if (hasNotStarted || isExpired) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              hasNotStarted ? 'Trial Required' : 'Trial Expired',
              style: TextStyle(color: hasNotStarted ? AppColors.primaryDark : AppColors.warning, fontWeight: FontWeight.w700),
            ),
            content: Text(
              hasNotStarted
                  ? 'Activate your introductory Pro trial for just ₹${config['trial_price']?.toInt() ?? 1} to track plants in your garden.'
                  : 'Your trial has expired. Upgrade to Pro or Farm Pack to continue tracking your gardens.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (hasNotStarted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TrialActivationScreen()),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => UpgradeScreen(isPro: tier == 'pro')),
                    );
                  }
                },
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                child: Text(hasNotStarted ? 'Activate Trial' : 'View Plans'),
              ),
            ],
          ),
        );
        return;
      } else {
        // During active trial, user receives Tier 1 (Pro) limits
        maxPlants = config['farm_creation_limit_pro'] ?? 5;
      }
    }

    if (maxPlants != -1 && _plants.length >= maxPlants) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Garden Limit Reached', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          content: Text(
            tier == 'free'
                ? 'Free accounts can track up to $maxPlants plant(s). Upgrade to Pro for more plants or Farm Pack for unlimited crop tracking.'
                : 'Pro accounts can track up to $maxPlants plants. Upgrade to Farm Pack for unlimited multi-crop tracking.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => UpgradeScreen(isPro: tier == 'pro')),
                );
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('View Plans'),
            ),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddPlantSheet(onAdded: _load),
    );
  }
}

class _AddPlantSheet extends StatefulWidget {
  final VoidCallback onAdded;
  const _AddPlantSheet({required this.onAdded});

  @override
  State<_AddPlantSheet> createState() => _AddPlantSheetState();
}

class _AddPlantSheetState extends State<_AddPlantSheet> {
  final _ctrl = TextEditingController();
  String _type = 'Apple';
  bool _saving = false;
  final _supabase = SupabaseService();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add a Plant',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Plant Name',
              hintText: 'e.g. My Tomato Plant',
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          const Text('Plant Type',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          SizedBox(
            height: 140,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: supportedCrops.map((crop) {
                  final selected = _type == crop.name;
                  return GestureDetector(
                    onTap: () => setState(() => _type = crop.name),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : const Color(0xFFF1F5F3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.lightBorder,
                        ),
                      ),
                      child: Text(
                        '${crop.emoji} ${crop.name}',
                        style: TextStyle(
                          fontSize: 13,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Add to Garden',
                    style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final uid = Supabase.instance.client.auth.currentUser!.id;
    await _supabase.addPlant(uid, _ctrl.text.trim(), _type);
    if (mounted) {
      Navigator.pop(context);
      widget.onAdded();
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
}
