// lib/screens/config/app_config_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/constants.dart';
import '../../models/app_config.dart';
import '../../providers/admin_providers.dart';

class AppConfigScreen extends ConsumerStatefulWidget {
  const AppConfigScreen({super.key});

  @override
  ConsumerState<AppConfigScreen> createState() => _AppConfigScreenState();
}

class _AppConfigScreenState extends ConsumerState<AppConfigScreen> {
  bool _saving = false;

  // Controllers & Form State
  late TextEditingController _freeDaysCtrl;
  late TextEditingController _freeScanCtrl;
  late TextEditingController _freeAiCtrl;

  late TextEditingController _proScanCtrl;
  late TextEditingController _proAiCtrl;
  late TextEditingController _proPriceCtrl;

  late TextEditingController _farmScanCtrl;
  late TextEditingController _farmAiCtrl;
  late TextEditingController _farmPriceCtrl;

  late TextEditingController _farmCapFreeCtrl;
  late TextEditingController _farmCapProCtrl;
  late TextEditingController _farmCapFarmCtrl;

  late TextEditingController _versionCtrl;
  bool _maintenanceMode = false;

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _freeDaysCtrl = TextEditingController();
    _freeScanCtrl = TextEditingController();
    _freeAiCtrl = TextEditingController();

    _proScanCtrl = TextEditingController();
    _proAiCtrl = TextEditingController();
    _proPriceCtrl = TextEditingController();

    _farmScanCtrl = TextEditingController();
    _farmAiCtrl = TextEditingController();
    _farmPriceCtrl = TextEditingController();

    _farmCapFreeCtrl = TextEditingController();
    _farmCapProCtrl = TextEditingController();
    _farmCapFarmCtrl = TextEditingController();

    _versionCtrl = TextEditingController();
  }

  void _populateForm(AppConfig cfg) {
    if (_initialized) return;
    _freeDaysCtrl.text = '${cfg.freeTierDays}';
    _freeScanCtrl.text = '${cfg.freeDailyScanLimit}';
    _freeAiCtrl.text = '${cfg.freeDailyAiLimit}';

    _proScanCtrl.text = '${cfg.proDailyScanLimit}';
    _proAiCtrl.text = '${cfg.proDailyAiLimit}';
    _proPriceCtrl.text = '${cfg.proMonthlyPrice}';

    _farmScanCtrl.text = '${cfg.farmDailyScanLimit}';
    _farmAiCtrl.text = '${cfg.farmDailyAiLimit}';
    _farmPriceCtrl.text = '${cfg.farmMonthlyPrice}';

    _farmCapFreeCtrl.text = '${cfg.farmCreationLimitFree}';
    _farmCapProCtrl.text = '${cfg.farmCreationLimitPro}';
    _farmCapFarmCtrl.text = '${cfg.farmCreationLimitFarm}';

    _versionCtrl.text = cfg.latestVersion;
    _maintenanceMode = cfg.maintenanceMode;
    _initialized = true;
  }

  Future<void> _saveConfig() async {
    setState(() => _saving = true);
    try {
      final updated = AppConfig(
        id: 1,
        freeTierDays: int.tryParse(_freeDaysCtrl.text) ?? 3,
        freeDailyScanLimit: int.tryParse(_freeScanCtrl.text) ?? 15,
        freeDailyAiLimit: int.tryParse(_freeAiCtrl.text) ?? 15,
        proDailyScanLimit: int.tryParse(_proScanCtrl.text) ?? 50,
        proDailyAiLimit: int.tryParse(_proAiCtrl.text) ?? 50,
        farmDailyScanLimit: int.tryParse(_farmScanCtrl.text) ?? -1,
        farmDailyAiLimit: int.tryParse(_farmAiCtrl.text) ?? -1,
        farmCreationLimitFree: int.tryParse(_farmCapFreeCtrl.text) ?? 1,
        farmCreationLimitPro: int.tryParse(_farmCapProCtrl.text) ?? 5,
        farmCreationLimitFarm: int.tryParse(_farmCapFarmCtrl.text) ?? -1,
        proMonthlyPrice: int.tryParse(_proPriceCtrl.text) ?? 49,
        farmMonthlyPrice: int.tryParse(_farmPriceCtrl.text) ?? 199,
        maintenanceMode: _maintenanceMode,
        latestVersion: _versionCtrl.text.trim().isEmpty ? '1.0.0' : _versionCtrl.text.trim(),
        updatedAt: DateTime.now(),
      );

      final service = ref.read(adminServiceProvider);
      await service.updateAppConfig(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AdminColors.primary,
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
                SizedBox(width: 10),
                Text(
                  'Configuration saved & deployed to all users in real time!',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AdminColors.error,
            content: Text('Failed to save config: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(appConfigStreamProvider);

    return configAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AdminColors.primary)),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AdminColors.error))),
      data: (cfg) {
        _populateForm(cfg);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quotas & Pricing Config',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Adjust daily allowances, trial length, pricing and system flags live',
                        style: TextStyle(
                          fontSize: 13,
                          color: AdminColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _saveConfig,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.cloud_upload_rounded, size: 18),
                    label: Text(_saving ? 'Saving...' : 'Deploy Changes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Section 1: Free Trial Tier
              _SectionCard(
                title: 'Free / Trial Tier Settings',
                icon: Icons.card_giftcard_rounded,
                color: AdminColors.secondary,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _NumericField(
                          label: 'Trial Duration (Days)',
                          controller: _freeDaysCtrl,
                          helperText: 'Number of introductory free trial days',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _NumericField(
                          label: 'Free Daily Scans',
                          controller: _freeScanCtrl,
                          helperText: 'Max crop disease scans per day',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _NumericField(
                          label: 'Free Daily AI Chats',
                          controller: _freeAiCtrl,
                          helperText: 'Max AI advisor questions per day',
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Section 2: Pro Tier
              _SectionCard(
                title: 'Pro Tier Settings',
                icon: Icons.star_rounded,
                color: AdminColors.warning,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _NumericField(
                          label: 'Pro Daily Scans',
                          controller: _proScanCtrl,
                          helperText: 'Daily scan limit for Pro users',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _NumericField(
                          label: 'Pro Daily AI Chats',
                          controller: _proAiCtrl,
                          helperText: 'Daily AI chats limit for Pro users',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _NumericField(
                          label: 'Pro Monthly Price (₹)',
                          controller: _proPriceCtrl,
                          prefixText: '₹ ',
                          helperText: 'Displayed in app & charged at checkout',
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Section 3: Farm Pack Tier
              _SectionCard(
                title: 'Farm Pack Tier Settings',
                icon: Icons.agriculture_rounded,
                color: AdminColors.accent,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _NumericField(
                          label: 'Farm Daily Scans (-1 for Unlimited)',
                          controller: _farmScanCtrl,
                          helperText: 'Enter -1 for infinite scans',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _NumericField(
                          label: 'Farm Daily AI Chats (-1 for Unlimited)',
                          controller: _farmAiCtrl,
                          helperText: 'Enter -1 for infinite AI usage',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _NumericField(
                          label: 'Farm Monthly Price (₹)',
                          controller: _farmPriceCtrl,
                          prefixText: '₹ ',
                          helperText: 'Monthly charge in Rupees',
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Section 4: Garden / Farm Creation Quotas
              _SectionCard(
                title: 'Farm Creation & Plant Quotas',
                icon: Icons.park_rounded,
                color: AdminColors.primaryLight,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _NumericField(
                          label: 'Free Tier Garden Cap',
                          controller: _farmCapFreeCtrl,
                          helperText: 'Max plants saved for Free tier',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _NumericField(
                          label: 'Pro Tier Garden Cap',
                          controller: _farmCapProCtrl,
                          helperText: 'Max plants saved for Pro tier',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _NumericField(
                          label: 'Farm Pack Garden Cap (-1 for Unlimited)',
                          controller: _farmCapFarmCtrl,
                          helperText: 'Max plants saved for Farm tier',
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Section 5: System & Maintenance
              _SectionCard(
                title: 'System & Maintenance Flags',
                icon: Icons.build_circle_rounded,
                color: Colors.redAccent,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _versionCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Minimum Required App Version',
                            labelStyle: const TextStyle(color: AdminColors.textSecondary),
                            helperText: 'Forces users below this version to update',
                            helperStyle: const TextStyle(color: AdminColors.textMuted),
                            filled: true,
                            fillColor: AdminColors.darkBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AdminColors.border),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AdminColors.darkBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AdminColors.border),
                          ),
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Maintenance Mode',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            subtitle: const Text(
                              'Lock non-essential features while servicing',
                              style: TextStyle(fontSize: 12, color: AdminColors.textMuted),
                            ),
                            value: _maintenanceMode,
                            activeColor: AdminColors.error,
                            onChanged: (val) => setState(() => _maintenanceMode = val),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _NumericField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? helperText;
  final String? prefixText;

  const _NumericField({
    required this.label,
    required this.controller,
    this.helperText,
    this.prefixText,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(signed: true),
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AdminColors.textSecondary, fontSize: 13),
        helperText: helperText,
        helperStyle: const TextStyle(color: AdminColors.textMuted, fontSize: 11),
        prefixText: prefixText,
        prefixStyle: const TextStyle(color: AdminColors.primaryLight, fontWeight: FontWeight.w700),
        filled: true,
        fillColor: AdminColors.darkBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AdminColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AdminColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
