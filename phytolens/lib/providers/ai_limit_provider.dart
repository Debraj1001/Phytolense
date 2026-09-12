import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/scan_limiter.dart';
import '../services/supabase_service.dart';

import 'user_provider.dart';
import 'app_config_provider.dart';

// Provider to hold the latest AI limit result
final aiLimitProvider = StateNotifierProvider<AiLimitNotifier, AsyncValue<AiLimitResult>>((ref) {
  final notifier = AiLimitNotifier(ref);
  ref.listen(currentUserProvider, (_, __) => notifier.refreshLimit());
  ref.listen(appConfigProvider, (_, __) => notifier.refreshLimit());
  return notifier;
});

class AiLimitNotifier extends StateNotifier<AsyncValue<AiLimitResult>> {
  final Ref _ref;

  AiLimitNotifier(this._ref) : super(const AsyncValue.loading()) {
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

      final result = ScanLimiter.computeAiLimit(effectiveUser, effectiveConfig);
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // Update limit optimistically after an AI usage
  Future<void> recordUsage(int length) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await SupabaseService().recordAiUsage(uid, 'chatbot', tokensUsed: length ~/ 4);
      await refreshLimit();
      _ref.invalidate(currentUserProvider);
    }
  }
}
