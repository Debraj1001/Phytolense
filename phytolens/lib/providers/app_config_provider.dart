// lib/providers/app_config_provider.dart
//
// Streams the app_config and plans from Supabase Realtime.
// Any change made in the Supabase dashboard (in plans or app_config)
// is pushed to every connected client within ~300 ms.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_config.dart';
import '../services/supabase_service.dart';

export '../models/app_config.dart';

/// Live AppConfig stream from Supabase Realtime with immediate REST fetch.
final appConfigProvider = StreamProvider<AppConfig>((ref) async* {
  final supabase = SupabaseService();

  // 1. Immediately yield live database configuration & plans
  try {
    final initial = await supabase.fetchAppConfig();
    yield initial;
  } catch (_) {
    yield const AppConfig();
  }

  // 2. Stream real-time events from plans and app_config
  final controller = StreamController<void>();
  final sub1 = supabase.streamAppConfig().listen((_) => controller.add(null));
  final sub2 = supabase.streamPlans().listen((_) => controller.add(null));

  ref.onDispose(() {
    sub1.cancel();
    sub2.cancel();
    controller.close();
  });

  await for (final _ in controller.stream) {
    try {
      final updated = await supabase.fetchAppConfig();
      yield updated;
    } catch (_) {}
  }
});
