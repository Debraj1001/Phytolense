// lib/providers/admin_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_config.dart';
import '../models/app_user.dart';
import '../models/scan_item.dart';
import '../services/supabase_admin_service.dart';

final adminServiceProvider = Provider((ref) => SupabaseAdminService());

final appConfigStreamProvider = StreamProvider<AppConfig>((ref) {
  final service = ref.watch(adminServiceProvider);
  return service.streamAppConfig();
});

final usersStreamProvider = StreamProvider<List<AppUser>>((ref) {
  final service = ref.watch(adminServiceProvider);
  return service.streamUsers();
});

final scansStreamProvider = StreamProvider<List<ScanItem>>((ref) {
  final service = ref.watch(adminServiceProvider);
  return service.streamRecentScans();
});

final globalStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.watch(adminServiceProvider);
  return service.getGlobalStats();
});
