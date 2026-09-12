// lib/providers/scan_limit_provider.dart
// Real-time provider for daily plant leaf scan limits and counts.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/scan_limiter.dart';
import '../services/supabase_service.dart';
import 'user_provider.dart';
import 'app_config_provider.dart';

final scanLimitProvider = StateNotifierProvider<ScanLimitNotifier, AsyncValue<ScanLimitResult>>((ref) {
  final notifier = ScanLimitNotifier(ref);
  ref.listen(currentUserProvider, (_, __) => notifier.refreshLimit());
  ref.listen(appConfigProvider, (_, __) => notifier.refreshLimit());
  return notifier;
});

class ScanLimitNotifier extends StateNotifier<AsyncValue<ScanLimitResult>> {
  final Ref _ref;

  ScanLimitNotifier(this._ref) : super(const AsyncValue.loading()) {
    refreshLimit();
  }

  Future<void> refreshLimit() async {
    try {
      final user = _ref.read(currentUserProvider).value;
      final config = _ref.read(appConfigProvider).value;

      final effectiveConfig = config ?? await SupabaseService().fetchAppConfig();
      final effectiveUser = user ?? (FirebaseAuth.instance.currentUser?.uid != null
          ? await SupabaseService().getUser(FirebaseAuth.instance.currentUser!.uid)
          : null);

      final result = ScanLimiter.computeScanLimit(effectiveUser, effectiveConfig);
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> recordScan() async {
    await refreshLimit();
    _ref.invalidate(currentUserProvider);
  }
}
