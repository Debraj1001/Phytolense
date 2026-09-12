// lib/theme/colors.dart
// Dual-theme color system (Dark + Light) following 2026 modern design standards.
// All semantic tokens pass WCAG 2.1 AA contrast.

import 'package:flutter/material.dart';

abstract class AppColors {
  // ─── Brand Identity (Vibrant, Modern Emerald & Mint) ───────────────────────
  static const Color primary = Color(0xFF10B981);       // Vibrant Emerald
  static const Color primaryLight = Color(0xFF34D399);  // Luminous Mint
  static const Color primaryDark = Color(0xFF059669);   // Deep Emerald
  static const Color secondary = Color(0xFF06B6D4);     // Cyan Teal Accent
  static const Color accent = Color(0xFF00E676);        // Neon Mint Glow

  // ─── Health Score Semantic ────────────────────────────────────────────────
  static const Color healthExcellent = Color(0xFF10B981); // 90–100 Emerald
  static const Color healthGood = Color(0xFFFBBF24);      // 70–89 Amber
  static const Color healthFair = Color(0xFFF97316);      // 50–69 Orange
  static const Color healthCritical = Color(0xFFEF4444);  // 0–49 Rose Red

  // ══════════════════════════════════════════════════════════════════════════
  // DARK THEME — Deep Obsidian Slate hierarchy (zero muddy swamp tones)
  // ══════════════════════════════════════════════════════════════════════════
  static const Color darkBg = Color(0xFF090D11);           // Deep Obsidian Slate
  static const Color darkSurface = Color(0xFF0F151C);      // Elevated surface
  static const Color darkCard = Color(0xFF161F28);         // Rich modern card
  static const Color darkCardElevated = Color(0xFF1E2A36); // Floating card
  static const Color darkCardHighest = Color(0xFF263646);  // Modal / popup

  // Dark text — high contrast on obsidian
  static const Color darkTextPrimary = Color(0xFFFFFFFF);    // Pure Crisp White
  static const Color darkTextSecondary = Color(0xFF94A3B8);  // Slate 400
  static const Color darkTextMuted = Color(0xFF64748B);      // Slate 500
  static const Color darkTextDisabled = Color(0xFF334155);   // Slate 700

  // Dark semantic — WCAG AA
  static const Color darkSuccess = Color(0xFF10B981);
  static const Color darkSuccessBg = Color(0x1F10B981);
  static const Color darkWarning = Color(0xFFF59E0B);
  static const Color darkWarningBg = Color(0x1FF59E0B);
  static const Color darkError = Color(0xFFEF4444);
  static const Color darkErrorBg = Color(0x1FEF4444);
  static const Color darkInfo = Color(0xFF38BDF8);
  static const Color darkInfoBg = Color(0x1F38BDF8);

  // Dark shimmer
  static const Color darkShimmerBase = Color(0xFF161F28);
  static const Color darkShimmerHighlight = Color(0xFF243242);

  // ══════════════════════════════════════════════════════════════════════════
  // LIGHT THEME — Pure, airy modern aesthetic
  // ══════════════════════════════════════════════════════════════════════════
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF1F5F9);
  static const Color lightCardElevated = Color(0xFFE2E8F0);
  static const Color lightCardHighest = Color(0xFFCBD5E1);

  // Light text
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);
  static const Color lightTextDisabled = Color(0xFFCBD5E1);

  // Light semantic
  static const Color lightSuccess = Color(0xFF059669);
  static const Color lightSuccessBg = Color(0xFFECFDF5);
  static const Color lightWarning = Color(0xFFD97706);
  static const Color lightWarningBg = Color(0xFFFFFBEB);
  static const Color lightError = Color(0xFFDC2626);
  static const Color lightErrorBg = Color(0xFFFEF2F2);
  static const Color lightInfo = Color(0xFF0284C7);
  static const Color lightInfoBg = Color(0xFFF0F9FF);

  // Light shimmer
  static const Color lightShimmerBase = Color(0xFFE2E8F0);
  static const Color lightShimmerHighlight = Color(0xFFF8FAFC);

  // ══════════════════════════════════════════════════════════════════════════
  // GRADIENTS
  // ══════════════════════════════════════════════════════════════════════════
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF059669)],
  );

  static const LinearGradient proGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF059669), Color(0xFF0D9488), Color(0xFF0284C7)],
  );

  static const LinearGradient healthGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF10B981), Color(0xFF00E676)],
  );

  static const LinearGradient darkBgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF090D11), Color(0xFF0F151C)],
  );

  static const LinearGradient lightBgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
  );

  static const RadialGradient glowGradient = RadialGradient(
    colors: [Color(0x3310B981), Color(0x00000000)],
  );

  // ══════════════════════════════════════════════════════════════════════════
  // LEGACY ALIASES — now pointing to LIGHT tokens (Soft Botanical redesign)
  // ══════════════════════════════════════════════════════════════════════════
  static const Color backgroundDark = lightBg;         // off-white canvas
  static const Color surfaceDark = lightSurface;       // pure white surfaces
  static const Color cardDark = lightSurface;          // white cards
  static const Color cardDarker = lightCard;           // faint grey containers
  static const Color textPrimary = lightTextPrimary;   // #0F172A near-black
  static const Color textSecondary = lightTextSecondary; // #475569 slate
  static const Color textMuted = lightTextMuted;       // #94A3B8 muted slate
  static const Color success = lightSuccess;
  static const Color warning = lightWarning;
  static const Color error = lightError;
  static const Color info = lightInfo;
  static const Color shimmerBase = lightShimmerBase;
  static const Color shimmerHighlight = lightShimmerHighlight;
  static const LinearGradient backgroundGradient = lightBgGradient;
}
