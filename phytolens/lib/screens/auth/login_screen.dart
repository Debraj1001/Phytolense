// lib/screens/auth/login_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app_links/app_links.dart';
import '../../services/auth_service.dart';
import '../../config/constants.dart';
import '../../theme/colors.dart';
import '../../widgets/loading_dots.dart';
import 'email_verification_screen.dart';
import '../subscription/trial_activation_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _googleLoading = false;
  String? _error;
  String? _successMsg;

  final _auth = AuthService();
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initAppLinks();
  }

  Future<void> _initAppLinks() async {
    _appLinks = AppLinks();
    
    // Check initial link
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Failed to get initial link: $e');
    }

    // Listen for incoming links
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      debugPrint('Link stream error: $err');
    });
  }

  Future<void> _handleDeepLink(Uri uri) async {
    if (uri.toString().contains('access_token=') || uri.toString().contains('type=magiclink') || uri.toString().contains('apiKey=')) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppConstants.routeHome);
      }
    }
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailCtrl.text.trim();
    setState(() { _loading = true; _error = null; _successMsg = null; });
    try {
      await _auth.sendOtpToEmail(email);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EmailVerificationScreen(email: email),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending OTP/magic link: $e');
      setState(() {
        _error = 'Failed to send verification code. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() { _googleLoading = true; _error = null; _successMsg = null; });
    try {
      final appUser = await _auth.signInWithGoogle();
      if (mounted) {
        if (appUser.subscriptionTier == 'free' && appUser.trialActivatedAt == null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const TrialActivationScreen(fromOnboarding: true),
            ),
          );
        } else {
          Navigator.pushReplacementNamed(context, AppConstants.routeHome);
        }
      }
    } catch (e, st) {
      debugPrint('🚨 Google Sign In Error: $e\n$st');
      setState(() {
        _error = 'Google Sign In failed: $e';
      });
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              // Logo + Title
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.eco_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'PhytoLens',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.lightTextPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 400.ms),

              const SizedBox(height: 32),

              // Heading
              Text(
                'Welcome Back',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.lightTextPrimary,
                  letterSpacing: -0.5,
                ),
              ).animate(delay: 100.ms).fadeIn(),

              const SizedBox(height: 8),

              Text(
                'Sign in to diagnose crop diseases, consult AI agronomists, and track your garden.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.lightTextSecondary,
                  height: 1.6,
                ),
              ).animate(delay: 150.ms).fadeIn(),

              const SizedBox(height: 32),

              // Magic Link Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: GoogleFonts.inter(
                        color: AppColors.lightTextPrimary,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        labelStyle: GoogleFonts.inter(
                          color: AppColors.lightTextMuted,
                          fontSize: 13,
                        ),
                        hintText: 'farmer@example.com',
                        hintStyle: GoogleFonts.inter(
                          color: AppColors.lightTextMuted,
                          fontSize: 14,
                        ),
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: AppColors.lightTextMuted,
                          size: 20,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: GoogleFonts.inter(
                          color: AppColors.lightError,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    if (_successMsg != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(10),
                          border: const Border.fromBorderSide(
                            BorderSide(color: Color(0xFF6EE7B7)),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.mark_email_read_outlined,
                                color: AppColors.primary, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _successMsg!,
                                style: GoogleFonts.inter(
                                  color: AppColors.primaryDark,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _loading ? null : _sendOtp,
                        child: _loading
                            ? const ButtonDots()
                            : const Text('Send OTP'),
                      ),
                    ),
                  ],
                ),
              ).animate(delay: 200.ms).fadeIn(),

              const SizedBox(height: 32),

              // Divider
              Row(
                children: [
                  const Expanded(
                    child: Divider(color: Color(0xFFE2E8F0)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OR',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.lightTextMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Divider(color: Color(0xFFE2E8F0)),
                  ),
                ],
              ).animate(delay: 300.ms).fadeIn(),

              const SizedBox(height: 24),

              // Google Auth Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _googleLoading ? null : _loginWithGoogle,
                  child: _googleLoading
                      ? const ButtonDots()
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/google_logo.png',
                              width: 20,
                              height: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Continue with Google',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.lightTextPrimary,
                              ),
                            ),
                          ],
                        ),
                ),
              ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.1, end: 0),


            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _linkSubscription?.cancel();
    super.dispose();
  }
}
