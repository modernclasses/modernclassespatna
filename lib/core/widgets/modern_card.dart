import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Premium Academic Editorial Card.
/// Designed with disciplined spacing, subtle hairline borders, and optional
/// academic accent spine for priority alerts or active sessions.
/// Automatically adapts between Light Ivory Canvas and Dark Surface cards.
class ModernCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final bool hasGlow;
  final Color? glowColor;
  final Color? accentSpineColor;
  final double accentSpineWidth;

  const ModernCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 10,
    this.hasGlow = false,
    this.glowColor,
    this.accentSpineColor,
    this.accentSpineWidth = 3.5,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    if (backgroundColor == null ||
        backgroundColor == AppTheme.surface ||
        backgroundColor == AppColors.surface ||
        backgroundColor == AppTheme.surfaceCard ||
        backgroundColor == AppColors.surfaceCard ||
        (isDark &&
            (backgroundColor == Colors.white ||
                backgroundColor == const Color(0xFFFFFFFF)))) {
      bg = isDark ? AppColors.darkSurfaceCard : AppColors.surface;
    } else if (isDark &&
        (backgroundColor == AppColors.warmIvory ||
            backgroundColor == AppColors.surfaceMuted ||
            backgroundColor == AppColors.surfaceSubtle)) {
      bg = AppColors.darkSurface;
    } else {
      bg = backgroundColor!;
    }

    Color border;
    if (borderColor == null ||
        borderColor == AppTheme.border ||
        borderColor == AppColors.border ||
        borderColor == AppTheme.borderLight ||
        borderColor == AppColors.borderSubtle ||
        (isDark &&
            (borderColor == Colors.white ||
                borderColor == AppColors.surface ||
                borderColor == const Color(0xFFFFFFFF)))) {
      border = isDark ? AppColors.darkBorder : AppColors.border;
    } else {
      border = borderColor!;
    }

    Widget cardBody = Container(padding: padding, child: child);

    // If an accent spine is provided (e.g. Saffron or Crimson for Live session),
    // decorate the left edge with a crisp vertical spine using a border rather
    // than IntrinsicHeight to eliminate line-wrap RenderFlex overflows on narrow phones.
    if (accentSpineColor != null) {
      cardBody = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: accentSpineColor!,
                width: accentSpineWidth,
              ),
            ),
          ),
          padding: padding,
          child: child,
        ),
      );
    }

    final cardDecoration = BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: border, width: 1),
      boxShadow: [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: hasGlow ? 0.35 : 0.15)
              : const Color(
                  0xFF0F172A,
                ).withValues(alpha: hasGlow ? 0.08 : 0.03),
          blurRadius: hasGlow ? 12 : 6,
          offset: const Offset(0, 2),
        ),
      ],
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Ink(decoration: cardDecoration, child: cardBody),
        ),
      );
    }

    return Container(decoration: cardDecoration, child: cardBody);
  }
}
