import 'package:flutter/material.dart';
import 'package:safeseat_mini/core/theme/app_theme.dart';

/// Reusable Driver Profile Avatar with Network loading, error fallback, and role badge.
class DriverAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? fallbackName;
  final double radius;
  final String? badgeText;
  final Color? badgeColor;
  final IconData defaultIcon;

  const DriverAvatar({
    super.key,
    this.imageUrl,
    this.fallbackName,
    this.radius = 32,
    this.badgeText,
    this.badgeColor,
    this.defaultIcon = Icons.person,
  });

  String _getInitials() {
    if (fallbackName == null || fallbackName!.trim().isEmpty) return '';
    final parts = fallbackName!.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final hasValidUrl = imageUrl != null && imageUrl!.trim().isNotEmpty;
    final initials = _getInitials();

    Widget avatarChild;
    if (hasValidUrl) {
      avatarChild = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          imageUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildFallback(initials);
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: radius * 2,
              height: radius * 2,
              color: const Color(0xFFF1F5F9),
              child: Center(
                child: SizedBox(
                  width: radius * 0.8,
                  height: radius * 0.8,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  ),
                ),
              ),
            );
          },
        ),
      );
    } else {
      avatarChild = _buildFallback(initials);
    }

    if (badgeText == null || badgeText!.isEmpty) {
      return avatarChild;
    }

    final effectiveBadgeColor = badgeColor ?? AppTheme.primaryColor;

    return Stack(
      children: [
        avatarChild,
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: effectiveBadgeColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Text(
              badgeText!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallback(String initials) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
      ),
      child: Center(
        child: initials.isNotEmpty
            ? Text(
                initials,
                style: TextStyle(
                  color: const Color(0xFF334155),
                  fontSize: radius * 0.65,
                  fontWeight: FontWeight.bold,
                ),
              )
            : Icon(
                defaultIcon,
                color: const Color(0xFF64748B),
                size: radius * 1.1,
              ),
      ),
    );
  }
}
