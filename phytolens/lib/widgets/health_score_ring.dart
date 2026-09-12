// lib/widgets/health_score_ring.dart
// Animated circular health score indicator

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/colors.dart';

class HealthScoreRing extends StatelessWidget {
  final int score;          // 0-100
  final double size;
  final double strokeWidth;
  final bool showLabel;
  final bool animate;

  const HealthScoreRing({
    super.key,
    required this.score,
    this.size = 100,
    this.strokeWidth = 8,
    this.showLabel = true,
    this.animate = true,
  });

  Color get _ringColor {
    if (score >= 90) return AppColors.healthExcellent;
    if (score >= 70) return AppColors.healthGood;
    if (score >= 50) return AppColors.healthFair;
    return AppColors.healthCritical;
  }

  String get _label {
    if (score >= 90) return 'Excellent';
    if (score >= 70) return 'Good';
    if (score >= 50) return 'Fair';
    return 'Critical';
  }

  @override
  Widget build(BuildContext context) {
    final ring = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          score: score,
          ringColor: _ringColor,
          strokeWidth: strokeWidth,
        ),
        child: showLabel
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$score',
                      style: TextStyle(
                        fontSize: size * 0.22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (size > 70)
                      Text(
                        _label,
                        style: TextStyle(
                          fontSize: size * 0.1,
                          fontWeight: FontWeight.w500,
                          color: _ringColor,
                        ),
                      ),
                  ],
                ),
              )
            : null,
      ),
    );

    if (!animate) return ring;

    return ring.animate().scale(
          begin: const Offset(0.7, 0.7),
          end: const Offset(1.0, 1.0),
          duration: 600.ms,
          curve: Curves.elasticOut,
        );
  }
}

class _RingPainter extends CustomPainter {
  final int score;
  final Color ringColor;
  final double strokeWidth;

  _RingPainter({
    required this.score,
    required this.ringColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background track
    final bgPaint = Paint()
      ..color = AppColors.textMuted.withValues(alpha: 0.15)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Score arc
    final scorePaint = Paint()
      ..color = ringColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * pi * (score / 100);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      scorePaint,
    );

    // Glow effect on the arc tip
    if (score > 0) {
      final glowPaint = Paint()
        ..color = ringColor.withValues(alpha: 0.4)
        ..strokeWidth = strokeWidth * 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      final angle = -pi / 2 + sweepAngle;
      final tipX = center.dx + radius * cos(angle);
      final tipY = center.dy + radius * sin(angle);
      canvas.drawCircle(Offset(tipX, tipY), strokeWidth / 2, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.score != score;
}

/// Mini inline health badge chip
class HealthBadge extends StatelessWidget {
  final int score;

  const HealthBadge({super.key, required this.score});

  Color get _color {
    if (score >= 90) return AppColors.healthExcellent;
    if (score >= 70) return AppColors.healthGood;
    if (score >= 50) return AppColors.healthFair;
    return AppColors.healthCritical;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$score%',
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
