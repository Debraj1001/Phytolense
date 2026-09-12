// lib/theme/design_tokens.dart
// Single source of truth for spacing, radius, shadow, and animation tokens.

import 'package:flutter/material.dart';

abstract class AppTokens {
  // ─── 8pt Grid Spacing ─────────────────────────────────────────────────────
  static const double space1 = 4.0;
  static const double space2 = 8.0;
  static const double space3 = 12.0;
  static const double space4 = 16.0;
  static const double space5 = 20.0;
  static const double space6 = 24.0;
  static const double space8 = 32.0;
  static const double space10 = 40.0;
  static const double space12 = 48.0;
  static const double space16 = 64.0;

  // ─── Border Radius Scale ──────────────────────────────────────────────────
  /// 8px — Chips, tags, small icon containers
  static const double radiusXS = 8.0;
  /// 12px — Input fields, list tiles
  static const double radiusSM = 12.0;
  /// 16px — Standard cards
  static const double radiusMD = 16.0;
  /// 20px — Sheets, prominent cards
  static const double radiusLG = 20.0;
  /// 24px — Modals, hero cards
  static const double radiusXL = 24.0;
  /// 32px — Large hero / showcase cards
  static const double radius2XL = 32.0;
  /// 9999px — Pill buttons, snackbars, badges
  static const double radiusPill = 9999.0;

  /// Pre-built BorderRadius objects
  static final BorderRadius bXS = BorderRadius.circular(radiusXS);
  static final BorderRadius bSM = BorderRadius.circular(radiusSM);
  static final BorderRadius bMD = BorderRadius.circular(radiusMD);
  static final BorderRadius bLG = BorderRadius.circular(radiusLG);
  static final BorderRadius bXL = BorderRadius.circular(radiusXL);
  static final BorderRadius b2XL = BorderRadius.circular(radius2XL);
  static final BorderRadius bPill = BorderRadius.circular(radiusPill);

  // ─── Tap Targets ──────────────────────────────────────────────────────────
  static const double tapTarget = 48.0;
  static const double tapTargetMin = 44.0;

  // ─── Elevation Shadows ────────────────────────────────────────────────────
  /// Level 1 — Resting card
  static List<BoxShadow> shadowSurface(Color shadow) => [
        BoxShadow(
          color: shadow.withValues(alpha: 0.04),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];

  /// Level 2 — Elevated card
  static List<BoxShadow> shadowElevated(Color shadow) => [
        BoxShadow(
          color: shadow.withValues(alpha: 0.10),
          blurRadius: 8,
          spreadRadius: -2,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: shadow.withValues(alpha: 0.05),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ];

  /// Level 3 — Floating elements
  static List<BoxShadow> shadowFloating(Color shadow) => [
        BoxShadow(
          color: shadow.withValues(alpha: 0.18),
          blurRadius: 28,
          spreadRadius: -6,
          offset: const Offset(0, 20),
        ),
        BoxShadow(
          color: shadow.withValues(alpha: 0.10),
          blurRadius: 10,
          spreadRadius: -4,
          offset: const Offset(0, 8),
        ),
      ];

  // ─── Animation Durations ──────────────────────────────────────────────────
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 400);

  // ─── Animation Curves ─────────────────────────────────────────────────────
  static const Curve curveStandard = Curves.easeInOutCubic;
  static const Curve curveDecelerate = Curves.easeOutCubic;
  static const Curve curveAccelerate = Curves.easeInCubic;
  static const Curve curveEmphasized = Curves.easeInOutBack;

  // ─── Inner Radius Helper ──────────────────────────────────────────────────
  /// innerRadius = outerRadius - padding. Prevents negative values.
  static double innerRadius(double outerRadius, double padding) {
    final r = outerRadius - padding;
    return r < 0 ? 0 : r;
  }
}
