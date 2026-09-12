// lib/screens/users/user_management_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/constants.dart';
import '../../models/app_user.dart';
import '../../providers/admin_providers.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  final _searchCtrl = TextEditingController();
  String _selectedTier = 'all';

  void _showUserActionDialog(AppUser user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AdminColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AdminColors.primary.withOpacity(0.2),
                    child: Text(
                      user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U',
                      style: const TextStyle(color: AdminColors.primaryLight, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                        Text(
                          user.email,
                          style: const TextStyle(fontSize: 13, color: AdminColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getTierColor(user.subscriptionTier).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      user.subscriptionTier.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _getTierColor(user.subscriptionTier),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              const Text(
                'Change Subscription Tier',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: AdminColors.border),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await ref.read(adminServiceProvider).updateUserTier(user.uid, 'free');
                      },
                      child: const Text('Revert to Free'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminColors.warning,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await ref.read(adminServiceProvider).updateUserTier(user.uid, 'pro', days: 30);
                      },
                      child: const Text('Upgrade to Pro (30d)', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminColors.accent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await ref.read(adminServiceProvider).updateUserTier(user.uid, 'farm', days: 30);
                      },
                      child: const Text('Farm Pack (30d)', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: user.banned ? AdminColors.primary : AdminColors.error.withOpacity(0.8),
                        foregroundColor: user.banned ? Colors.black : Colors.white,
                      ),
                      icon: Icon(user.banned ? Icons.check_circle_rounded : Icons.block_rounded, size: 18),
                      label: Text(user.banned ? 'Unban Account' : 'Ban Account'),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await ref.read(adminServiceProvider).toggleUserBan(user.uid, !user.banned);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Color _getTierColor(String tier) {
    switch (tier) {
      case 'pro':
        return AdminColors.warning;
      case 'farm':
        return AdminColors.accent;
      default:
        return AdminColors.primaryLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersStreamProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'User Accounts & Subscriptions',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Search, filter, adjust subscription tiers, or manage access permissions',
            style: TextStyle(fontSize: 13, color: AdminColors.textSecondary),
          ),

          const SizedBox(height: 20),

          // Search & Filter Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search by user name, email, or UID...',
                    hintStyle: const TextStyle(color: AdminColors.textMuted, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: AdminColors.textSecondary),
                    filled: true,
                    fillColor: AdminColors.darkSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AdminColors.border),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Filter chips
              Wrap(
                spacing: 8,
                children: ['all', 'free', 'pro', 'farm'].map((tier) {
                  final isSelected = _selectedTier == tier;
                  return ChoiceChip(
                    label: Text(tier.toUpperCase()),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _selectedTier = tier);
                    },
                    selectedColor: AdminColors.primary.withOpacity(0.25),
                    backgroundColor: AdminColors.darkSurface,
                    labelStyle: TextStyle(
                      color: isSelected ? AdminColors.primaryLight : AdminColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
                    side: BorderSide(
                      color: isSelected ? AdminColors.primary : AdminColors.border,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Users List
          Expanded(
            child: usersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AdminColors.primary)),
              error: (e, _) => Center(child: Text('Error loading users: $e', style: const TextStyle(color: AdminColors.error))),
              data: (allUsers) {
                final search = _searchCtrl.text.trim().toLowerCase();
                final filtered = allUsers.where((u) {
                  final matchesTier = _selectedTier == 'all' || u.subscriptionTier == _selectedTier;
                  final matchesSearch = search.isEmpty ||
                      u.displayName.toLowerCase().contains(search) ||
                      u.email.toLowerCase().contains(search) ||
                      u.uid.toLowerCase().contains(search);
                  return matchesTier && matchesSearch;
                }).toList();

                if (filtered.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: AdminColors.darkSurface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text(
                        'No matching users found.',
                        style: TextStyle(color: AdminColors.textSecondary, fontSize: 14),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final u = filtered[i];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AdminColors.darkSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: u.banned ? AdminColors.error.withOpacity(0.4) : AdminColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: _getTierColor(u.subscriptionTier).withOpacity(0.15),
                            child: Text(
                              u.displayName.isNotEmpty ? u.displayName[0].toUpperCase() : 'U',
                              style: TextStyle(
                                color: _getTierColor(u.subscriptionTier),
                                fontWeight: FontWeight.w700,
                              ),
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
                                      u.displayName,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (u.banned) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AdminColors.error.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'BANNED',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: AdminColors.error,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  u.email.isNotEmpty ? u.email : 'UID: ${u.uid}',
                                  style: const TextStyle(fontSize: 12, color: AdminColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          // Stats
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${u.xp} XP • Lvl ${u.level}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${u.scanCount} Scans • 🔥 ${u.streak}d',
                                style: const TextStyle(fontSize: 11, color: AdminColors.textMuted),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          // Tier Badge & Action Button
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getTierColor(u.subscriptionTier).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _getTierColor(u.subscriptionTier).withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              u.subscriptionTier.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _getTierColor(u.subscriptionTier),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            icon: const Icon(Icons.more_vert_rounded, color: AdminColors.textSecondary),
                            onPressed: () => _showUserActionDialog(u),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
