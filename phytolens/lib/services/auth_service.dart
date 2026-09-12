import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/app_user.dart';

import 'supabase_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '646033659202-3rimcckpeaca490ubm14ho21fgfif121.apps.googleusercontent.com',
  );

  User? get currentFirebaseUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with Google
  Future<AppUser> signInWithGoogle() async {
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
    } catch (_) {}

    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Google sign in aborted');
    }
    
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    
    final cred = await _auth.signInWithCredential(credential);
    return _handleFirebaseUser(cred.user!);
  }

  // Sign in with Email and Password
  Future<AppUser> signInWithEmailAndPassword(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return _handleFirebaseUser(cred.user!);
  }

  // Send Magic Link
  Future<void> sendSignInLinkToEmail(String email) async {
    final actionCodeSettings = ActionCodeSettings(
      url: 'https://phytolens.com/login', // Replace with your actual domain for app links
      handleCodeInApp: true,
      androidPackageName: 'com.phytolens.phytolens',
      androidInstallApp: true,
      androidMinimumVersion: '1',
    );
    await _auth.sendSignInLinkToEmail(
      email: email,
      actionCodeSettings: actionCodeSettings,
    );
  }

  // Sign in with Email Link
  Future<AppUser> signInWithEmailLink(String email, String emailLink) async {
    if (_auth.isSignInWithEmailLink(emailLink)) {
      final cred = await _auth.signInWithEmailLink(email: email, emailLink: emailLink);
      return _handleFirebaseUser(cred.user!);
    } else {
      throw Exception('Invalid magic link');
    }
  }

  // Handle Firebase User (fetches from Supabase or creates a new one)
  Future<AppUser> _handleFirebaseUser(User firebaseUser) async {
    try {
      final existingUser = await SupabaseService().getUser(firebaseUser.uid);
      if (existingUser != null) {
        return existingUser;
      }
      
      final user = AppUser(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName ?? 'Plant Lover',
        avatarUrl: firebaseUser.photoURL,
        createdAt: DateTime.now(),
      );

      await SupabaseService().upsertUser(user);
      return user;
    } catch (e) {
      throw Exception('Failed to handle user in Supabase: $e');
    }
  }

  // Get User from Supabase (with auto-heal fallback)
  Future<AppUser> getUser(String uid) async {
    final user = await SupabaseService().getUser(uid);
    if (user != null) return user;

    final fbUser = _auth.currentUser;
    if (fbUser != null && fbUser.uid == uid) {
      return _handleFirebaseUser(fbUser);
    }
    
    return AppUser(
      uid: uid,
      email: '',
      displayName: 'Plant Lover',
      createdAt: DateTime.now(),
    );
  }

  // Stream user
  Stream<AppUser?> userStream(String uid) {
    return SupabaseService().streamUser(uid);
  }

  // Sign Out (clears Firebase, Google account, Supabase, and local cache)
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _googleSignIn.disconnect();
    } catch (e) {
      debugPrint('Google sign out error: $e');
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }

    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Firebase sign out error: $e');
    }

    try {
      await Supabase.instance.client.auth.signOut();
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

  // Update Profile
  Future<void> updateProfile(String uid, {String? displayName, String? avatarUrl}) async {
    final updates = <String, dynamic>{};
    if (displayName != null) {
      updates['display_name'] = displayName;
      await _auth.currentUser?.updateDisplayName(displayName);
    }
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (updates.isNotEmpty) {
      await SupabaseService().updateUser(uid, updates);
    }
  }



  // Update subscription
  Future<void> updateSubscription(String uid, String tier) async {
    await SupabaseService().updateSubscription(uid, tier);
  }

  // Update FCM token
  Future<void> updateFcmToken(String uid, String token) async {
    await SupabaseService().updateUser(uid, {'fcm_token': token});
  }
}
