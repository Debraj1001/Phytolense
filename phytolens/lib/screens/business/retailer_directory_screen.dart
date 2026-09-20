import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:phytolens/theme/colors.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/user_provider.dart';
import '../../providers/app_config_provider.dart';
import '../../services/trial_service.dart';
import '../subscription/upgrade_screen.dart';
import '../../widgets/glass_button.dart';

class RetailerDirectoryScreen extends ConsumerStatefulWidget {
  const RetailerDirectoryScreen({super.key});

  @override
  ConsumerState<RetailerDirectoryScreen> createState() => _RetailerDirectoryScreenState();
}

class _RetailerDirectoryScreenState extends ConsumerState<RetailerDirectoryScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _retailers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchRetailers();
  }

  Future<void> _fetchRetailers() async {
    try {
      final response = await _supabase.from('retailers').select().order('rating', ascending: false);
      setState(() {
        _retailers = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error fetching retailers: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _callRetailer(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final config = ref.watch(appConfigProvider).value ?? const AppConfig();
    final trialInfo = TrialService.getTrialInfo(user, trialDays: config.trialDays);
    final isLocked = !trialInfo.isUpgraded && trialInfo.isExpired;

    return Scaffold(
      backgroundColor: AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: Center(
          child: GlassButton.back(),
        ),
        title: Text(
          'Nearby Retailers',
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.lightTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.lightTextPrimary),
        elevation: 0,
      ),
      body: isLocked
          ? _buildLockedPaywall(context, config)
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _retailers.isEmpty
                  ? Center(
                      child: Text(
                        'No retailers found nearby.',
                        style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _retailers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                    final r = _retailers[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.storefront_rounded, color: AppColors.primaryDark),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r['name'] ?? 'Unknown Retailer',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: AppColors.lightTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, size: 14, color: AppColors.textMuted),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        r['address'] ?? '',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${r['rating'] ?? 0.0}',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.call, color: AppColors.primary),
                            onPressed: () {
                              if (r['phone'] != null) {
                                _callRetailer(r['phone']);
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildLockedPaywall(BuildContext context, AppConfig config) {
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
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront_rounded, color: AppColors.error, size: 36),
              ),
              const SizedBox(height: 18),
              const Text(
                'Nearby Retailers Locked',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your ${config.trialDays}-Day Free Trial has ended. Access to certified fertilizer stockists, seed distributors, and direct retailer calling requires an active Pro Plan or Farm Pack.',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.45),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UpgradeScreen()),
                ),
                icon: const Icon(Icons.flash_on_rounded, size: 18, color: Colors.white),
                label: const Text(
                  'UPGRADE TO ACCESS RETAILERS',
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
}
