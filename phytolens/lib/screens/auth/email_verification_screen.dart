// lib/screens/auth/email_verification_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/language_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/constants.dart';
import '../../services/auth_service.dart';
import '../../theme/colors.dart';
import '../../widgets/loading_dots.dart';
import '../subscription/trial_activation_screen.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  final String email;
  const EmailVerificationScreen({super.key, required this.email});

  @override
  ConsumerState<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  final _auth = AuthService();
  final _codeController = TextEditingController();
  final _focusNode = FocusNode();

  bool _loading = false;
  String? _error;
  String? _infoMsg;
  int _secondsRemaining = 60;
  Timer? _timer;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _listenForDeepLinkAuth();
    _focusNode.addListener(() => setState(() {}));
  }

  void _startCountdown() {
    _secondsRemaining = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        t.cancel();
      }
    });
  }

  void _listenForDeepLinkAuth() {
    _authSub = _auth.authStateChanges.listen((state) async {
      if (state.event == AuthChangeEvent.signedIn && mounted) {
        final uid = state.session?.user.id ?? _auth.currentUserId;
        if (uid != null) {
          try {
            final appUser = await _auth.getUser(uid);
            if (mounted && appUser.subscriptionTier == 'free' && appUser.trialActivatedAt == null) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const TrialActivationScreen(fromOnboarding: true),
                ),
                (_) => false,
              );
              return;
            }
          } catch (_) {}
        }
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, AppConstants.routeHome, (_) => false);
        }
      }
    });
  }

  Future<void> _verifyOtp([String? explicitCode]) async {
    final code = (explicitCode ?? _codeController.text).trim();
    if (code.length < 6) {
      setState(() => _error = ref.tr('please_enter_verification_code'));
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _infoMsg = null;
    });

    try {
      final appUser = await _auth.verifyOtp(widget.email, code);
      if (mounted) {
        if (appUser.subscriptionTier == 'free' && appUser.trialActivatedAt == null) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => const TrialActivationScreen(fromOnboarding: true),
            ),
            (_) => false,
          );
        } else {
          Navigator.pushNamedAndRemoveUntil(context, AppConstants.routeHome, (_) => false);
        }
      }
    } catch (e) {
      debugPrint('OTP Verification error: $e');
      setState(() {
        _error = ref.tr('invalid_expired_code');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendCode() async {
    if (_secondsRemaining > 0) return;
    setState(() {
      _loading = true;
      _error = null;
      _infoMsg = null;
    });

    try {
      await _auth.sendOtpToEmail(widget.email);
      _codeController.clear();
      _focusNode.requestFocus();
      _startCountdown();
      setState(() {
        _infoMsg = ref.tr('fresh_code_sent');
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to resend code: ${e.toString()}';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null) {
      final digits = data!.text!.replaceAll(RegExp(r'\D'), '');
      if (digits.isNotEmpty) {
        setState(() {
          _codeController.text = digits.length > 7 ? digits.substring(0, 7) : digits;
        });
        if (_codeController.text.length >= 6) {
          _verifyOtp();
        }
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _authSub?.cancel();
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentCode = _codeController.text;
    final displayBoxCount = currentCode.length > 6 ? 7 : 6;

    return Scaffold(
      backgroundColor: AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.lightTextPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 16),

              // Soft Botanical Icon Container
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.mark_email_read_rounded,
                  color: AppColors.primary,
                  size: 34,
                ),
              ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

              SizedBox(height: 24),

              // Title & Subtitle
              Text(
                ref.tr('verify_your_email'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.lightTextPrimary,
                  letterSpacing: -0.5,
                ),
              ).animate().fadeIn(delay: 100.ms),

              SizedBox(height: 8),

              Text(
                ref.tr('sent_code_to'),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.lightTextSecondary,
                ),
              ).animate().fadeIn(delay: 120.ms),

              SizedBox(height: 4),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.email,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
              ).animate().fadeIn(delay: 150.ms),

              SizedBox(height: 36),

              // Bulletproof Unified OTP Digit Input (Single Controller)
              Stack(
                alignment: Alignment.center,
                children: [
                  // Hidden, real TextField capturing all keyboard / paste events
                  Opacity(
                    opacity: 0.0,
                    child: TextField(
                      controller: _codeController,
                      focusNode: _focusNode,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      maxLength: 7,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (val) {
                        setState(() {});
                        if (val.length >= 6) {
                          _verifyOtp(val);
                        }
                      },
                    ),
                  ),

                  // Visible stylized boxes
                  GestureDetector(
                    onTap: () => _focusNode.requestFocus(),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(displayBoxCount, (i) {
                        final hasChar = i < currentCode.length;
                        final isFocused = _focusNode.hasFocus &&
                            (i == currentCode.length || (i == displayBoxCount - 1 && currentCode.length >= displayBoxCount));
                        final char = hasChar ? currentCode[i] : '';

                        return Container(
                          width: displayBoxCount == 7 ? 40 : 46,
                          height: 58,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isFocused
                                  ? AppColors.primary
                                  : (hasChar ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
                              width: isFocused ? 2 : 1.5,
                            ),
                            boxShadow: isFocused
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.12),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            char,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.lightTextPrimary,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 200.ms),

              SizedBox(height: 16),

              // Paste Button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _pasteFromClipboard,
                  icon: Icon(Icons.paste_rounded, size: 16, color: AppColors.primary),
                  label: Text(
                    ref.tr('paste_code'),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 12),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: AppColors.lightError, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: GoogleFonts.inter(
                            color: AppColors.lightError,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn().shake(),
                SizedBox(height: 12),
              ],

              if (_infoMsg != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF6EE7B7)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, color: AppColors.primaryDark, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _infoMsg!,
                          style: GoogleFonts.inter(
                            color: AppColors.primaryDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(),
                SizedBox(height: 12),
              ],

              SizedBox(height: 12),

              // Verify Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : () => _verifyOtp(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const ButtonDots()
                      : Text(
                          ref.tr('verify_code_continue'),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ).animate().fadeIn(delay: 250.ms),

              SizedBox(height: 24),

              // Resend / Countdown Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    ref.tr('didnt_receive_email'),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.lightTextMuted,
                    ),
                  ),
                  if (_secondsRemaining > 0)
                    Text(
                      'Resend in ${_secondsRemaining}s',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.lightTextSecondary,
                      ),
                    )
                  else
                    TextButton(
                      onPressed: _loading ? null : _resendCode,
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      child: Text(
                        ref.tr('resend_code'),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),
                ],
              ),

              SizedBox(height: 16),

              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.edit_outlined, size: 16, color: AppColors.lightTextSecondary),
                label: Text(
                  ref.tr('change_email'),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.lightTextSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
