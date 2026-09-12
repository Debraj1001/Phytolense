// lib/screens/dashboard/admin_main_screen.dart

import 'package:flutter/material.dart';
import '../../config/constants.dart';
import '../config/app_config_screen.dart';
import '../users/user_management_screen.dart';
import '../scans/scan_moderation_screen.dart';
import '../login/admin_login_screen.dart';
import 'admin_overview_screen.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    AdminOverviewScreen(),
    AppConfigScreen(),
    UserManagementScreen(),
    ScanModerationScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;

        return Scaffold(
          backgroundColor: AdminColors.darkBg,
          appBar: AppBar(
            backgroundColor: AdminColors.darkSurface,
            elevation: 0,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AdminColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.eco_rounded, color: AdminColors.primaryLight, size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  'PhytoLens Admin Console',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Logout',
                icon: const Icon(Icons.logout_rounded, color: AdminColors.textSecondary),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Row(
            children: [
              if (isWide)
                NavigationRail(
                  backgroundColor: AdminColors.darkSurface,
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
                  labelType: NavigationRailLabelType.all,
                  selectedIconTheme: const IconThemeData(color: AdminColors.primaryLight),
                  unselectedIconTheme: const IconThemeData(color: AdminColors.textMuted),
                  selectedLabelTextStyle: const TextStyle(
                    color: AdminColors.primaryLight,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  unselectedLabelTextStyle: const TextStyle(
                    color: AdminColors.textMuted,
                    fontSize: 12,
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard_rounded),
                      label: Text('Overview'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.tune_outlined),
                      selectedIcon: Icon(Icons.tune_rounded),
                      label: Text('Quotas & Config'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.people_outline_rounded),
                      selectedIcon: Icon(Icons.people_rounded),
                      label: Text('Users'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.image_search_outlined),
                      selectedIcon: Icon(Icons.image_search_rounded),
                      label: Text('Live Scans'),
                    ),
                  ],
                ),
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: _pages,
                ),
              ),
            ],
          ),
          bottomNavigationBar: isWide
              ? null
              : NavigationBar(
                  backgroundColor: AdminColors.darkSurface,
                  indicatorColor: AdminColors.primary.withOpacity(0.25),
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined, color: AdminColors.textMuted),
                      selectedIcon: Icon(Icons.dashboard_rounded, color: AdminColors.primaryLight),
                      label: 'Overview',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.tune_outlined, color: AdminColors.textMuted),
                      selectedIcon: Icon(Icons.tune_rounded, color: AdminColors.primaryLight),
                      label: 'Config',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.people_outline_rounded, color: AdminColors.textMuted),
                      selectedIcon: Icon(Icons.people_rounded, color: AdminColors.primaryLight),
                      label: 'Users',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.image_search_outlined, color: AdminColors.textMuted),
                      selectedIcon: Icon(Icons.image_search_rounded, color: AdminColors.primaryLight),
                      label: 'Scans',
                    ),
                  ],
                ),
        );
      },
    );
  }
}
