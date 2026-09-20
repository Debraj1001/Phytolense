// lib/widgets/glass_button.dart
// ChatGPT-inspired professional glassmorphic buttons with frosted blur,
// specular rim borders, ambient depth shadows, and tactile micro-bounce.

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import 'bouncing_button.dart';

/// Style variants for glass buttons
enum GlassButtonStyle {
  /// Adapts automatically to the theme (Light: frosted white, Dark: frosted obsidian)
  adaptive,
  /// Always frosted translucent white (ideal on light surfaces)
  light,
  /// Always frosted dark glass (ideal over camera viewfinders, plant photos, dark heroes)
  dark,
  /// Frosted emerald-tinted glass
  emerald,
}

/// A circular or pill-shaped frosted glass button inspired by ChatGPT and iOS 18.
class GlassButton extends StatelessWidget {
  final Widget? child;
  final IconData? icon;
  final double iconSize;
  final Color? iconColor;
  final String? label;
  final TextStyle? labelStyle;
  final VoidCallback? onTap;
  final double size;
  final double? width;
  final double? height;
  final double borderRadius;
  final GlassButtonStyle style;
  final double blurSigma;
  final EdgeInsetsGeometry? padding;
  final String? tooltip;
  final bool isPill;

  const GlassButton({
    super.key,
    this.child,
    this.icon,
    this.iconSize = 18,
    this.iconColor,
    this.label,
    this.labelStyle,
    this.onTap,
    this.size = 40,
    this.width,
    this.height,
    this.borderRadius = 999,
    this.style = GlassButtonStyle.adaptive,
    this.blurSigma = 14,
    this.padding,
    this.tooltip,
    this.isPill = false,
  });

  /// Factory for a ChatGPT-style Back Button with smooth arrow icon
  factory GlassButton.back({
    Key? key,
    VoidCallback? onTap,
    GlassButtonStyle style = GlassButtonStyle.adaptive,
    double size = 40,
    Color? iconColor,
    String? tooltip = 'Back',
  }) {
    return GlassButton(
      key: key,
      size: size,
      style: style,
      icon: Icons.arrow_back_ios_new_rounded,
      iconSize: 18,
      iconColor: iconColor,
      tooltip: tooltip,
      onTap: onTap,
    );
  }

  /// Factory for a ChatGPT-style Close Button
  factory GlassButton.close({
    Key? key,
    VoidCallback? onTap,
    GlassButtonStyle style = GlassButtonStyle.adaptive,
    double size = 40,
    Color? iconColor,
    String? tooltip = 'Close',
  }) {
    return GlassButton(
      key: key,
      size: size,
      style: style,
      icon: Icons.close_rounded,
      iconSize: 20,
      iconColor: iconColor,
      tooltip: tooltip,
      onTap: onTap,
    );
  }

  /// Factory for an Action Pill Button (e.g. "Save", "Share", "Details")
  factory GlassButton.action({
    Key? key,
    required String label,
    IconData? icon,
    VoidCallback? onTap,
    GlassButtonStyle style = GlassButtonStyle.adaptive,
    Color? accentColor,
    double height = 44,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  }) {
    return GlassButton(
      key: key,
      label: label,
      icon: icon,
      iconSize: 17,
      height: height,
      isPill: true,
      style: style,
      iconColor: accentColor,
      padding: padding,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Resolve color tokens based on chosen style
    final Color backgroundColor;
    final Color borderColor;
    final Color effectiveIconColor;
    final Color effectiveTextColor;
    final List<BoxShadow> shadows;

    switch (style) {
      case GlassButtonStyle.dark:
        backgroundColor = const Color(0x99111827); // Dark frosted slate
        borderColor = Colors.white.withValues(alpha: 0.16);
        effectiveIconColor = iconColor ?? Colors.white;
        effectiveTextColor = Colors.white;
        shadows = [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ];
        break;

      case GlassButtonStyle.emerald:
        backgroundColor = isDark
            ? AppColors.primaryDark.withValues(alpha: 0.35)
            : AppColors.primary.withValues(alpha: 0.12);
        borderColor = AppColors.primary.withValues(alpha: isDark ? 0.4 : 0.3);
        effectiveIconColor = iconColor ?? AppColors.primary;
        effectiveTextColor = AppColors.primary;
        shadows = [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ];
        break;

      case GlassButtonStyle.light:
        backgroundColor = Colors.white.withValues(alpha: 0.82);
        borderColor = Colors.black.withValues(alpha: 0.07);
        effectiveIconColor = iconColor ?? AppColors.lightTextPrimary;
        effectiveTextColor = AppColors.lightTextPrimary;
        shadows = [
          BoxShadow(
            color: const Color(0x0C0F172A),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: const Color(0x060F172A),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ];
        break;

      case GlassButtonStyle.adaptive:
        if (isDark) {
          backgroundColor = const Color(0x8A1E293B);
          borderColor = Colors.white.withValues(alpha: 0.14);
          effectiveIconColor = iconColor ?? AppColors.darkTextPrimary;
          effectiveTextColor = AppColors.darkTextPrimary;
          shadows = [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ];
        } else {
          backgroundColor = Colors.white.withValues(alpha: 0.82);
          borderColor = const Color(0xFFE2E8F0).withValues(alpha: 0.95);
          effectiveIconColor = iconColor ?? AppColors.lightTextPrimary;
          effectiveTextColor = AppColors.lightTextPrimary;
          shadows = [
            const BoxShadow(
              color: Color(0x0A0F172A),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
            const BoxShadow(
              color: Color(0x060F172A),
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ];
        }
        break;
    }

    final effectiveRadius = BorderRadius.circular(borderRadius);

    Widget content;
    if (child != null) {
      content = child!;
    } else if (isPill && label != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: effectiveIconColor),
            const SizedBox(width: 7),
          ],
          Text(
            label!,
            style: labelStyle ??
                TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: effectiveTextColor,
                  letterSpacing: -0.1,
                ),
          ),
        ],
      );
    } else if (icon != null) {
      content = Center(
        child: Icon(
          icon,
          size: iconSize,
          color: effectiveIconColor,
        ),
      );
    } else {
      content = const SizedBox.shrink();
    }

    final effectiveBlur = blurSigma.clamp(0.0, 8.0);

    Widget innerContent = Container(
      padding: padding ?? (isPill ? const EdgeInsets.symmetric(horizontal: 14) : EdgeInsets.zero),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: effectiveRadius,
        border: Border.all(color: borderColor, width: 1.1),
      ),
      alignment: Alignment.center,
      child: content,
    );

    Widget buttonContent = effectiveBlur > 0
        ? ClipRRect(
            borderRadius: effectiveRadius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
              child: innerContent,
            ),
          )
        : innerContent;

    Widget button = Container(
      width: isPill ? width : (width ?? size),
      height: height ?? size,
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        boxShadow: shadows,
      ),
      child: buttonContent,
    );

    button = BouncingButton(
      scaleFactor: 0.92,
      onTap: () {
        HapticFeedback.lightImpact();
        if (onTap != null) {
          onTap!();
        } else {
          Navigator.maybePop(context);
        }
      },
      child: button,
    );

    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return button;
  }
}
