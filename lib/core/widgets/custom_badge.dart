import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum BadgeVariant {
  primary,
  secondary,
  success,
  error,
  warning,
  info,
  purple,
  outline,
}

class CustomBadge extends StatelessWidget {
  final String text;
  final BadgeVariant variant;
  final IconData? icon;
  final bool isLivePulse;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const CustomBadge({
    super.key,
    required this.text,
    this.variant = BadgeVariant.primary,
    this.icon,
    this.isLivePulse = false,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color border = Colors.transparent;

    switch (variant) {
      case BadgeVariant.primary:
        bg = AppTheme.primary.withValues(alpha: 0.15);
        fg = AppTheme.primary;
        border = AppTheme.primary.withValues(alpha: 0.3);
        break;
      case BadgeVariant.secondary:
        bg = AppTheme.secondary.withValues(alpha: 0.15);
        fg = AppTheme.secondaryLight;
        border = AppTheme.secondary.withValues(alpha: 0.3);
        break;
      case BadgeVariant.success:
        bg = AppTheme.success.withValues(alpha: 0.15);
        fg = AppTheme.success;
        border = AppTheme.success.withValues(alpha: 0.3);
        break;
      case BadgeVariant.error:
        bg = AppTheme.error.withValues(alpha: 0.15);
        fg = AppTheme.error;
        border = AppTheme.error.withValues(alpha: 0.3);
        break;
      case BadgeVariant.warning:
        bg = AppTheme.warning.withValues(alpha: 0.15);
        fg = AppTheme.warning;
        border = AppTheme.warning.withValues(alpha: 0.3);
        break;
      case BadgeVariant.info:
        bg = AppTheme.info.withValues(alpha: 0.15);
        fg = AppTheme.info;
        border = AppTheme.info.withValues(alpha: 0.3);
        break;
      case BadgeVariant.purple:
        bg = AppTheme.purple.withValues(alpha: 0.15);
        fg = AppTheme.purple;
        border = AppTheme.purple.withValues(alpha: 0.3);
        break;
      case BadgeVariant.outline:
        bg = Colors.transparent;
        fg = AppTheme.textSecondary;
        border = AppTheme.borderLight;
        break;
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLivePulse) ...[
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(right: 6),
              decoration: const BoxDecoration(
                color: AppTheme.error,
                shape: BoxShape.circle,
              ),
            ),
          ] else if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
