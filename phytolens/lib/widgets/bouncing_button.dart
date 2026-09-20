// lib/widgets/bouncing_button.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A premium, tactile button wrapper that provides soft bounce micro-interaction
/// and subtle haptic feedback on press.
class BouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;
  final Duration duration;
  final bool enableHaptics;

  const BouncingButton({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = 0.96,
    this.duration = const Duration(milliseconds: 120),
    this.enableHaptics = true,
  });

  @override
  State<BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<BouncingButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleFactor).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutCubic,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isProcessingTap = false;

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null && !_isProcessingTap) {
      if (widget.enableHaptics) HapticFeedback.lightImpact();
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) async {
    if (widget.onTap != null && !_isProcessingTap) {
      _controller.reverse();
      
      // Debounce logic
      _isProcessingTap = true;
      widget.onTap!();
      
      // Short delay before allowing next tap
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          _isProcessingTap = false;
        }
      });
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null && !_isProcessingTap) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
