// lib/services/auth_service.dart

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_user.dart';
import 'supabase_service.dart';
import 'notification_service.dart';

class AuthService {
  SupabaseClient get _client => Supabase.instance.client;

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '829141947094-ul2srm1goo7vt6hkb3b71bipqut8m9fp.apps.googleusercontent.com',
  );

  User? get currentSupabaseUser => _client.auth.currentUser;
  String? get currentUserId => _client.auth.currentUser?.id;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // Send OTP to email via Supabase Auth (pure 6-digit OTP, no confirmation URL)
  Future<void> sendOtpToEmail(String email) async {
    await _client.auth.signInWithOtp(
      email: email.trim(),
      shouldCreateUser: true,
    );
  }

  // Backwards compatible alias
  Future<void> sendSignInLinkToEmail(String email) => sendOtpToEmail(email);

  // Verify OTP code entered by user (supports 6 or 7 digit variations across all types)
  Future<AppUser> verifyOtp(String email, String token) async {
    AuthResponse? res;
    dynamic lastError;

    final trimmed = token.trim();
    final candidates = <String>[
      trimmed,
      if (trimmed.length >= 7) trimmed.substring(0, 6),
      if (trimmed.length >= 7) trimmed.substring(1),
    ];

    final types = [
      OtpType.email,
      OtpType.signup,
      OtpType.magiclink,
      OtpType.recovery,
    ];

    for (final candidate in candidates) {
      for (final type in types) {
        try {
          res = await _client.auth.verifyOTP(
            email: email.trim(),
            token: candidate,
            type: type,
          );
          if (res.user != null) break;
        } catch (e) {
          lastError = e;
        }
      }
      if (res?.user != null) break;
    }

    if (res == null || res.user == null) {
      throw lastError ?? Exception('Verification failed: Invalid or expired OTP code');
    }

    return _handleSupabaseUser(res.user!);
  }

  // Sign in with Google through Supabase using ID Token
  Future<AppUser> signInWithGoogle() async {
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
    } catch (_) {}

    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Google sign in aborted by user');
    }

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw Exception('No ID Token received from Google.');
    }

    final res = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: googleAuth.accessToken,
    );

    if (res.user == null) {
      throw Exception('Supabase Google Sign-In failed');
    }

    return _handleSupabaseUser(res.user!);
  }

  // Handle Supabase user profile in public.users
  Future<AppUser> _handleSupabaseUser(User sbUser) async {
    final uid = sbUser.id;
    try {
      final existingUser = await SupabaseService().getUser(uid);
      if (existingUser != null) {
        final metadata = sbUser.userMetadata ?? {};
        final displayName = metadata['full_name'] ?? metadata['name'] ?? metadata['display_name'];
        final avatarUrl = metadata['avatar_url'];

        final updates = <String, dynamic>{};
        if ((existingUser.displayName.isEmpty || existingUser.displayName == 'Plant Lover') &&
            displayName != null && displayName.toString().isNotEmpty) {
          updates['display_name'] = displayName.toString();
        }
        if (existingUser.avatarUrl == null && avatarUrl != null) {
          updates['avatar_url'] = avatarUrl.toString();
        }
        if (existingUser.email.isEmpty && sbUser.email != null) {
          updates['email'] = sbUser.email!;
        }
        if (updates.isNotEmpty) {
          await SupabaseService().updateUser(uid, updates);
        }

        NotificationService().syncDeviceToken();

        return existingUser.copyWith(
          displayName: updates['display_name'] ?? existingUser.displayName,
          avatarUrl: updates['avatar_url'] ?? existingUser.avatarUrl,
          email: updates['email'] ?? existingUser.email,
        );
      }

      final metadata = sbUser.userMetadata ?? {};
      final displayName = metadata['full_name'] ?? metadata['name'] ?? metadata['display_name'] ?? 'Plant Lover';
      final avatarUrl = metadata['avatar_url'];

      final newUser = AppUser(
        uid: uid,
        email: sbUser.email ?? '',
        displayName: displayName.toString(),
        avatarUrl: avatarUrl?.toString(),
        createdAt: DateTime.now(),
      );

      await SupabaseService().upsertUser(newUser);
      NotificationService().syncDeviceToken();
      return newUser;
    } catch (e) {
      debugPrint('Notice in _handleSupabaseUser: $e');
      final fallback = await SupabaseService().getUser(uid);
      if (fallback != null) return fallback;

      return AppUser(
        uid: uid,
        email: sbUser.email ?? '',
        displayName: 'Plant Lover',
        createdAt: DateTime.now(),
      );
    }
  }

  // Get User from Supabase
  Future<AppUser> getUser(String uid) async {
    final user = await SupabaseService().getUser(uid);
    if (user != null) return user;

    final sbUser = _client.auth.currentUser;
    if (sbUser != null && sbUser.id == uid) {
      return _handleSupabaseUser(sbUser);
    }

    return AppUser(
      uid: uid,
      email: '',
      displayName: 'Plant Lover',
      createdAt: DateTime.now(),
    );
  }

  Stream<AppUser?> userStream(String uid) {
    return SupabaseService().streamUser(uid);
  }

  // Sign Out (clears Google account, Supabase session, and local cache)
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _googleSignIn.disconnect();
    } catch (e) {
      debugPrint('Google sign out notice: $e');
    }

    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('Supabase sign out error: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_user_tier');
      await prefs.remove('cached_user_id');
      await prefs.remove('last_scan_date');
      await prefs.remove('daily_scan_count');
      await prefs.remove('daily_ai_count');
    } catch (e) {
      debugPrint('Prefs clean error: $e');
    }
  }

  Future<void> updateProfile(String uid, {String? displayName, String? avatarUrl}) async {
    final updates = <String, dynamic>{};
    if (displayName != null) updates['display_name'] = displayName;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (updates.isNotEmpty) {
      await SupabaseService().updateUser(uid, updates);
    }
  }

  Future<void> updateSubscription(String uid, String tier) async {
    await SupabaseService().updateSubscription(uid, tier);
  }

  Future<void> updateFcmToken(String uid, String token) async {
    await SupabaseService().updateUser(uid, {'fcm_token': token});
  }
}
