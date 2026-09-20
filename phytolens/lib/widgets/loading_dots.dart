// lib/widgets/loading_dots.dart
// Animated loading indicators: dots, spinner, pulse

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/colors.dart';

/// Three bouncing dots loader
class LoadingDots extends StatelessWidget {
  final Color color;
  final double size;

  const LoadingDots({
    super.key,
    this.color = AppColors.primaryLight,
    this.size = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: size * 0.3),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .moveY(
                begin: 0,
                end: -size * 1.2,
                duration: 400.ms,
                delay: Duration(milliseconds: i * 130),
                curve: Curves.easeInOut,
              )
              .then()
              .moveY(
                begin: -size * 1.2,
                end: 0,
                duration: 400.ms,
                curve: Curves.easeInOut,
              ),
        );
      }),
    );
  }
}

/// Centered full-screen loading with dots
class FullScreenLoader extends StatelessWidget {
  final String? message;

  const FullScreenLoader({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.primaryLight,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 20),
            Text(
              message!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small inline spinner
class InlineSpinner extends StatelessWidget {
  final double size;
  final Color color;

  const InlineSpinner({
    super.key,
    this.size = 18,
    this.color = AppColors.primaryLight,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: color,
        ),
      );
}

/// Pulsing circle loader (for scanning animation)
class ScanningPulse extends StatelessWidget {
  const ScanningPulse({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulse rings
          ...List.generate(3, (i) {
            return Container(
              width: 120.0,
              height: 120.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primaryLight.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .scale(
                  begin: const Offset(0.5, 0.5),
                  end: const Offset(1.0, 1.0),
                  duration: 1500.ms,
                  delay: Duration(milliseconds: i * 400),
                  curve: Curves.easeOut,
                )
                .fade(begin: 1, end: 0, duration: 1500.ms);
          }),
          // Center icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: const Icon(
              Icons.local_florist,
              color: AppColors.primaryLight,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

/// AI typing indicator (three dots for chatbot)
class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.15)),
      ),
      child: const LoadingDots(size: 6),
    );
  }
}

/// Mini dots for button loading state
class ButtonDots extends StatelessWidget {
  final Color color;
  const ButtonDots({super.key, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return LoadingDots(
      color: color,
      size: 6,
    );
  }
}
