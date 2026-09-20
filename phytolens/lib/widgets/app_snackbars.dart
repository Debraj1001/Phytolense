// lib/widgets/app_snackbars.dart
// Professional frosted glass snackbars with blur, specular rim borders,
// and semantic icon badges inspired by modern design systems.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';

enum GlassSnackbarType {
  success,
  error,
  warning,
  info,
}

class AppSnackbars {
  static void show(
    BuildContext context, {
    required String message,
    GlassSnackbarType type = GlassSnackbarType.info,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Resolve semantic styling tokens
    final IconData icon;
    final Color accentColor;
    final Color iconBg;

    switch (type) {
      case GlassSnackbarType.success:
        icon = Icons.check_circle_rounded;
        accentColor = AppColors.primary;
        iconBg = AppColors.primary.withValues(alpha: 0.15);
        break;
      case GlassSnackbarType.error:
        icon = Icons.error_rounded;
        accentColor = const Color(0xFFEF4444);
        iconBg = const Color(0xFFEF4444).withValues(alpha: 0.15);
        break;
      case GlassSnackbarType.warning:
        icon = Icons.warning_amber_rounded;
        accentColor = const Color(0xFFF59E0B);
        iconBg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
        break;
      case GlassSnackbarType.info:
        icon = Icons.info_outline_rounded;
        accentColor = const Color(0xFF38BDF8);
        iconBg = const Color(0xFF38BDF8).withValues(alpha: 0.15);
        break;
    }

    final Color bgColor = isDark
        ? const Color(0xCC0F172A)
        : const Color(0xDE0F172A);

    final Color borderColor = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.22);

    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        padding: EdgeInsets.zero,
        content: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 20,
                spreadRadius: -2,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: accentColor.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor, width: 1.1),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: iconBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 18, color: accentColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          letterSpacing: 0.1,
                          height: 1.3,
                        ),
                      ),
                    ),
                    if (actionLabel != null && onAction != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          messenger.hideCurrentSnackBar();
                          onAction();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          actionLabel,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
