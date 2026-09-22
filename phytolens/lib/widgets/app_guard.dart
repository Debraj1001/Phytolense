// lib/widgets/app_guard.dart
// Realtime Application Guard: Handles System Lockdown, User Bans, and Deleted Account Auto-Logout

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/app_config_provider.dart';
import '../providers/user_provider.dart';
import '../screens/system/lockdown_screen.dart';
import '../screens/system/ban_screen.dart';
import '../config/constants.dart';
import '../data/local_database.dart';
import '../data/chat_database.dart';
import '../services/sync_service.dart';
import 'app_snackbars.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class AppGuard extends ConsumerStatefulWidget {
  final Widget child;

  const AppGuard({super.key, required this.child});

  @override
  ConsumerState<AppGuard> createState() => _AppGuardState();
}

class _AppGuardState extends ConsumerState<AppGuard> {
  bool _wasUserLoaded = false;
  bool _isHandlingDeletion = false;

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(appConfigProvider);
    final currentUserAsync = ref.watch(currentUserProvider);
    final authUser = ref.watch(authStateProvider).value;

    final isLockdown = configAsync.value?.maintenanceMode ?? false;
    final currentUser = currentUserAsync.value;

    // Track user session state
    if (authUser != null && currentUser != null) {
      _wasUserLoaded = true;
    } else if (authUser == null) {
      _wasUserLoaded = false;
    }

    // Detect if user account was deleted from database by administrator (only when confirmed online)
    if (_wasUserLoaded &&
        authUser != null &&
        currentUserAsync.hasValue &&
        currentUserAsync.value == null &&
        !_isHandlingDeletion) {
      _isHandlingDeletion = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final online = await SyncService().isOnline();
        if (online) {
          _handleAccountDeleted(authUser.id);
        } else {
          _isHandlingDeletion = false;
        }
      });
    }

    final isBanned = (authUser != null && currentUser != null && currentUser.banned);

    return Stack(
      children: [
        // 1. Underlying application (kept mounted so state & scroll are preserved on unban/unlock)
        widget.child,

        // 2. Ban Screen overlay (when user is suspended by admin)
        if (isBanned && !isLockdown)
          Positioned.fill(
            child: BanScreen(user: currentUser),
          ),

        // 3. Platform Lockdown Screen overlay (highest precedence)
        if (isLockdown)
          const Positioned.fill(
            child: LockdownScreen(),
          ),
      ],
    );
  }

  Future<void> _handleAccountDeleted(String uid) async {
    try {
      // 1. Clear local cached databases
      await LocalDatabase().clearAllUserData(uid);
      await ChatDatabase().clearAllUserData(uid);

      // 2. Revoke active auth session
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint('Error during deleted account cleanup: $e');
    } finally {
      _wasUserLoaded = false;
      _isHandlingDeletion = false;

      // 3. Redirect user to login screen
      final nav = appNavigatorKey.currentState;
      if (nav != null) {
        nav.pushNamedAndRemoveUntil(AppConstants.routeLogin, (route) => false);
      }

      // 4. Present clear administrative notification
      final navContext = appNavigatorKey.currentContext;
      if (navContext != null && navContext.mounted) {
        AppSnackbars.show(
          navContext,
          message: 'Your account has been deleted by an administrator.',
          type: GlassSnackbarType.error,
          duration: const Duration(seconds: 5),
        );
      }
    }
  }
}
