// lib/widgets/user_avatar.dart
// Reusable profile avatar widget with image caching, tier borders, and initials fallback.

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/colors.dart';

class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String displayName;
  final double size;
  final String? tier;
  final bool showBorder;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    required this.avatarUrl,
    required this.displayName,
    this.size = 36,
    this.tier,
    this.showBorder = true,
    this.onTap,
  });

  Color get _tierColor {
    if (tier == 'farm') return const Color(0xFFFFD700); // Gold
    if (tier == 'pro') return const Color(0xFF00BCD4);  // Cyan
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveUrl = (avatarUrl != null && avatarUrl!.trim().isNotEmpty) ? avatarUrl!.trim() : null;

    Widget avatarContent = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.15),
        border: showBorder
            ? Border.all(
                color: _tierColor.withValues(alpha: 0.6),
                width: size > 48 ? 2.5 : 1.5,
              )
            : null,
      ),
      child: ClipOval(
        child: effectiveUrl != null
            ? CachedNetworkImage(
                imageUrl: effectiveUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (_, __) => _buildFallback(),
                errorWidget: (_, __, ___) => _buildFallback(),
              )
            : _buildFallback(),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: avatarContent,
      );
    }

    return avatarContent;
  }

  Widget _buildFallback() {
    final initial = displayName.trim().isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : 'P';

    return Container(
      width: size,
      height: size,
      color: AppColors.lightCard,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: _tierColor,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}
