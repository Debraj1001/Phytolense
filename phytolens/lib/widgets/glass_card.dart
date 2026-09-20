// lib/widgets/glass_card.dart
// Modern frosted glass card container with specular border and ambient depth.

import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final double blur;
  final double alpha;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final Gradient? gradient;
  final List<BoxShadow>? shadows;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.borderRadius = AppTokens.radiusLG,
    this.blur = 16,
    this.alpha = 0.75,
    this.color,
    this.borderColor,
    this.borderWidth = 1.1,
    this.gradient,
    this.shadows,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final resolvedBg = color != null
        ? color!.withValues(alpha: alpha)
        : (isDark
            ? const Color(0x99161F28)
            : Colors.white.withValues(alpha: alpha));

    final resolvedBorder = borderColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.12)
            : const Color(0xFFE2E8F0).withValues(alpha: 0.9));

    final resolvedShadows = shadows ??
        [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : const Color(0x0A0F172A),
            blurRadius: 16,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.15)
                : const Color(0x040F172A),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ];

    final radius = BorderRadius.circular(borderRadius);

    final effectiveBlur = blur.clamp(0.0, 10.0);

    Widget innerContent = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? resolvedBg : null,
        gradient: gradient,
        borderRadius: radius,
        border: Border.all(color: resolvedBorder, width: borderWidth),
      ),
      child: child,
    );

    Widget cardBody = effectiveBlur > 0
        ? ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
              child: innerContent,
            ),
          )
        : innerContent;

    Widget card = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: resolvedShadows,
      ),
      child: cardBody,
    );

    if (onTap != null) {
      card = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: card,
      );
    }

    return card;
  }
}
