import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_user.dart';
import '../services/supabase_service.dart';
import '../data/local_database.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  try {
    return Supabase.instance.client.auth.onAuthStateChange.map((event) => event.session?.user);
  } catch (_) {
    return Stream.value(null);
  }
});

final currentUserProvider = StreamProvider<AppUser?>((ref) async* {
  String? uid;
  try {
    uid = Supabase.instance.client.auth.currentUser?.id;
  } catch (_) {}

  final localDb = LocalDatabase();
  final lastUser = await localDb.getLastLoggedInUser();
  final effectiveUid = (uid != null && uid.isNotEmpty) ? uid : lastUser?.uid;

  if (effectiveUid == null || effectiveUid.isEmpty) {
    yield null;
    return;
  }

  // 1. Immediately yield cached user for instant offline startup
  final cachedUser = await localDb.getCachedUser(effectiveUid) ?? lastUser;
  if (cachedUser != null) {
    yield cachedUser;
  }

  // 2. Stream live user changes from Supabase if connected
  try {
    final stream = SupabaseService().streamUser(effectiveUid);
    await for (final user in stream) {
      if (user != null) {
        await localDb.saveCachedUser(user);
        yield user;
      } else if (cachedUser != null) {
        yield cachedUser; // Preserve offline session
      }
    }
  } catch (e) {
    debugPrint('User stream offline/disconnected: $e');
    if (cachedUser != null) {
      yield cachedUser;
    }
  }
});
