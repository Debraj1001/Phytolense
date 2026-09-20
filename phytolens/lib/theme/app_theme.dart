// lib/theme/app_theme.dart
// Soft Botanical Minimalism — Light-first design system.
// Headlines: Plus Jakarta Sans  |  Body/Labels: Inter
// Primary: #10B981 Sage Emerald  |  BG: #F8FAFC off-white

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';
import 'design_tokens.dart';

class AppTheme {
  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final bg           = isDark ? const Color(0xFF0B110E)   : AppColors.lightBg;
    final surface      = isDark ? const Color(0xFF111A16)   : AppColors.lightSurface;
    final card         = isDark ? const Color(0xFF1A2419)   : AppColors.lightSurface;
    final cardElevated = isDark ? const Color(0xFF1F2C1F)   : AppColors.lightCard;
    final textPrimary   = isDark ? AppColors.darkTextPrimary   : AppColors.lightTextPrimary;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final textMuted     = isDark ? AppColors.darkTextMuted     : AppColors.lightTextMuted;
    final semanticError = isDark ? AppColors.darkError : AppColors.lightError;

    // Feather-light shadow for light mode; deeper for dark
    final featherShadow = isDark
        ? const Color(0x1A000000)
        : const Color(0x0A0F172A);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,

      // ── Color Scheme (MD3) ────────────────────────────────────────────────
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: isDark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5),
        onPrimaryContainer: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF064E3B),
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        secondaryContainer: isDark ? const Color(0xFF1A2927) : const Color(0xFFECFDF5),
        onSecondaryContainer: isDark ? AppColors.lightTextPrimary : const Color(0xFF065F46),
        tertiary: AppColors.accent,
        onTertiary: AppColors.primaryDark,
        tertiaryContainer: isDark ? const Color(0xFF1C2C0A) : const Color(0xFFEDFFCE),
        onTertiaryContainer: textPrimary,
        error: semanticError,
        onError: Colors.white,
        errorContainer: isDark ? AppColors.darkErrorBg : AppColors.lightErrorBg,
        onErrorContainer: semanticError,
        surface: surface,
        onSurface: textPrimary,
        surfaceContainerHighest: cardElevated,
        onSurfaceVariant: textSecondary,
        outline: isDark ? textMuted.withValues(alpha: 0.3) : const Color(0xFFCBD5E1),
        outlineVariant: isDark ? textMuted.withValues(alpha: 0.15) : const Color(0xFFE2E8F0),
        shadow: featherShadow,
        scrim: Colors.black.withValues(alpha: 0.5),
        inverseSurface: isDark ? AppColors.lightCard : Colors.white,
        onInverseSurface: isDark ? AppColors.lightTextPrimary : AppColors.darkTextPrimary,
        inversePrimary: isDark ? AppColors.primaryDark : AppColors.primaryLight,
      ),

      scaffoldBackgroundColor: bg,

      // ── Typography ────────────────────────────────────────────────────────
      // Headlines → Plus Jakarta Sans (warm, modern)
      // Body/Labels → Inter (clean, legible)
      textTheme: _buildTextTheme(textPrimary, textSecondary, textMuted),

      // ── AppBar ────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: textPrimary),
        actionsIconTheme: IconThemeData(color: textSecondary),
      ),

      // ── Cards ─────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: featherShadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLG), // 20px smooth squircle
          side: BorderSide(
            color: isDark
                ? textMuted.withValues(alpha: 0.14)
                : const Color(0xFFE2E8F0).withValues(alpha: 0.9),
            width: 1,
          ),
        ),
      ),

      // ── Elevated Button (Primary — 14px radius, 48px height) ──────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return AppColors.primary.withValues(alpha: 0.38);
            if (states.contains(WidgetState.pressed))  return AppColors.primaryDark;
            if (states.contains(WidgetState.hovered))  return AppColors.primary.withValues(alpha: 0.92);
            return AppColors.primary;
          }),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          overlayColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.12)),
          elevation: WidgetStateProperty.all(0),
          shadowColor: WidgetStateProperty.all(Colors.transparent),
          minimumSize: WidgetStateProperty.all(const Size(0, AppTokens.tapTarget)), // 48px
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: AppTokens.space6, vertical: AppTokens.space3),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), // 14px smooth squircle
          ),
          textStyle: WidgetStateProperty.all(
            GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2),
          ),
          animationDuration: AppTokens.durationFast,
        ),
      ),

      // ── Filled Button ─────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return AppColors.primary.withValues(alpha: 0.38);
            if (states.contains(WidgetState.pressed))  return AppColors.primaryDark;
            return AppColors.primary;
          }),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          overlayColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.1)),
          minimumSize: WidgetStateProperty.all(const Size(0, AppTokens.tapTarget)),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: AppTokens.space6, vertical: AppTokens.space3),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusSM)), // 12px
          ),
          textStyle: WidgetStateProperty.all(
            GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2),
          ),
        ),
      ),

      // ── Outlined Button (white bg + emerald border) ───────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(Colors.white),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return textMuted;
            return AppColors.primary;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(color: textMuted.withValues(alpha: 0.3));
            }
            if (states.contains(WidgetState.pressed)) {
              return const BorderSide(color: AppColors.primaryDark, width: 2);
            }
            return const BorderSide(color: AppColors.primary, width: 1.5);
          }),
          overlayColor: WidgetStateProperty.all(AppColors.primary.withValues(alpha: 0.06)),
          minimumSize: WidgetStateProperty.all(const Size(0, AppTokens.tapTarget)),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: AppTokens.space6, vertical: AppTokens.space3),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusSM)), // 12px
          ),
          textStyle: WidgetStateProperty.all(
            GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2),
          ),
        ),
      ),

      // ── Text Button (ghost) ───────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return textMuted;
            return isDark ? AppColors.primaryLight : AppColors.primary;
          }),
          overlayColor: WidgetStateProperty.all(AppColors.primary.withValues(alpha: 0.06)),
          minimumSize: WidgetStateProperty.all(const Size(0, AppTokens.tapTarget)),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: AppTokens.space4, vertical: AppTokens.space2),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusSM)),
          ),
          textStyle: WidgetStateProperty.all(
            GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ),

      // ── Input Fields ──────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? cardElevated : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space4,
          vertical: AppTokens.space4,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSM), // 12px
          borderSide: BorderSide(
            color: isDark ? textMuted.withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSM),
          borderSide: BorderSide(
            color: isDark ? textMuted.withValues(alpha: 0.2) : const Color(0xFFE2E8F0),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSM),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSM),
          borderSide: BorderSide(color: semanticError),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSM),
          borderSide: BorderSide(color: semanticError, width: 2),
        ),
        hintStyle: GoogleFonts.inter(fontSize: 14, color: textMuted),
        labelStyle: GoogleFonts.inter(fontSize: 13, color: textSecondary, fontWeight: FontWeight.w500),
        floatingLabelStyle: GoogleFonts.inter(
          fontSize: 12,
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
        errorStyle: GoogleFonts.inter(fontSize: 12, color: semanticError),
      ),

      // ── Chip (pill) ───────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? cardElevated : Colors.white,
        labelStyle: GoogleFonts.inter(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500),
        side: BorderSide(
          color: isDark ? textMuted.withValues(alpha: 0.2) : const Color(0xFFE2E8F0),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space3,
          vertical: AppTokens.space1,
        ),
        selectedColor: AppColors.primary,
        checkmarkColor: Colors.white,
        secondaryLabelStyle: GoogleFonts.inter(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: isDark ? textMuted.withValues(alpha: 0.12) : const Color(0xFFE2E8F0),
        thickness: 1,
        space: AppTokens.space4,
      ),

      // ── Navigation Bar (MD3) ──────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? surface : Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.14),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.primary : textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.primary : textMuted,
            size: 24,
          );
        }),
      ),

      // ── Snackbar ──────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xE61E293B) : const Color(0xF20F172A),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 13,
          color: Colors.white,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
        behavior: SnackBarBehavior.floating,
        width: 340,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusPill),
          side: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.22),
            width: 1.0,
          ),
        ),
        elevation: 8,
        actionTextColor: AppColors.primaryLight,
        showCloseIcon: false,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space4,
          vertical: AppTokens.space6,
        ),
      ),

      // ── List Tile ─────────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space4,
          vertical: AppTokens.space1,
        ),
        titleTextStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: textPrimary),
        subtitleTextStyle: GoogleFonts.inter(fontSize: 13, color: textSecondary),
        iconColor: textSecondary,
        minVerticalPadding: AppTokens.space3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMD)),
      ),

      // ── Bottom Sheet ──────────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppColors.darkCardHighest : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.radiusXL)),
        ),
        elevation: 0,
        dragHandleColor: textMuted.withValues(alpha: 0.4),
      ),

      // ── Dialog ────────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.darkCardHighest : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusXL)),
        elevation: 0,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.3,
        ),
        contentTextStyle: GoogleFonts.inter(fontSize: 14, color: textSecondary, height: 1.55),
      ),

      // ── Switch ────────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected) ? Colors.white : textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.primary
              : textMuted.withValues(alpha: 0.3);
        }),
      ),

      // ── Progress Indicator ────────────────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: isDark
            ? textMuted.withValues(alpha: 0.15)
            : const Color(0xFFE2E8F0),
        linearMinHeight: 5,
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
      ),
    );
  }

  // ── Text Theme ────────────────────────────────────────────────────────────
  // Display / Headline → Plus Jakarta Sans (warm, friendly)
  // Body / Label / Title → Inter (clean, legible)
  static TextTheme _buildTextTheme(Color primary, Color secondary, Color muted) {
    return TextTheme(
      // Display — splash / hero (Plus Jakarta Sans)
      displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 40, fontWeight: FontWeight.w800, color: primary,
          letterSpacing: -1.0, height: 1.1),
      displayMedium: GoogleFonts.plusJakartaSans(
          fontSize: 32, fontWeight: FontWeight.w700, color: primary,
          letterSpacing: -0.8, height: 1.15),
      displaySmall: GoogleFonts.plusJakartaSans(
          fontSize: 26, fontWeight: FontWeight.w700, color: primary,
          letterSpacing: -0.5, height: 1.2),

      // Headlines (Plus Jakarta Sans)
      headlineLarge: GoogleFonts.plusJakartaSans(
          fontSize: 24, fontWeight: FontWeight.w700, color: primary,
          letterSpacing: -0.4, height: 1.25),
      headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 20, fontWeight: FontWeight.w700, color: primary,
          letterSpacing: -0.3, height: 1.3),
      headlineSmall: GoogleFonts.plusJakartaSans(
          fontSize: 18, fontWeight: FontWeight.w600, color: primary,
          letterSpacing: -0.2, height: 1.35),

      // Titles (Inter)
      titleLarge: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w600, color: primary,
          letterSpacing: -0.1, height: 1.4),
      titleMedium: GoogleFonts.inter(
          fontSize: 15, fontWeight: FontWeight.w600, color: primary,
          height: 1.4),
      titleSmall: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w500, color: secondary,
          height: 1.4),

      // Body (Inter)
      bodyLarge: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w400, color: primary,
          height: 1.6),
      bodyMedium: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w400, color: secondary,
          height: 1.55),
      bodySmall: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w400, color: muted,
          height: 1.5),

      // Labels / Captions (Inter)
      labelLarge: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w600, color: primary,
          letterSpacing: 0.1, height: 1.4),
      labelMedium: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w500, color: secondary,
          letterSpacing: 0.2, height: 1.4),
      labelSmall: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w500, color: muted,
          letterSpacing: 0.4, height: 1.4),
    );
  }
}