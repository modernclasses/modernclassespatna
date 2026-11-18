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
    this.fontSize = 10.5,
    this.padding = const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color bg;
    Color fg;
    Color border;

    switch (variant) {
      case BadgeVariant.primary:
        bg = isDark
            ? AppColors.primary.withValues(alpha: 0.18)
            : AppColors.saffronMuted;
        fg = isDark ? AppColors.primaryLight : AppColors.primaryDark;
        border = isDark
            ? AppColors.primary.withValues(alpha: 0.4)
            : AppColors.saffronBorder;
        break;
      case BadgeVariant.secondary:
        bg = isDark
            ? AppColors.secondaryLight.withValues(alpha: 0.18)
            : AppColors.secondaryMuted;
        fg = isDark ? const Color(0xFF93C5FD) : AppColors.secondary;
        border = isDark
            ? AppColors.secondaryLight.withValues(alpha: 0.4)
            : AppColors.secondaryLight.withValues(alpha: 0.3);
        break;
      case BadgeVariant.success:
        bg = isDark
            ? AppColors.success.withValues(alpha: 0.18)
            : AppColors.successBg;
        fg = isDark ? const Color(0xFF86EFAC) : AppColors.success;
        border = isDark
            ? AppColors.success.withValues(alpha: 0.4)
            : AppColors.successBorder;
        break;
      case BadgeVariant.error:
        bg = isDark
            ? AppColors.error.withValues(alpha: 0.18)
            : AppColors.errorBg;
        fg = isDark ? const Color(0xFFFDA4AF) : AppColors.error;
        border = isDark
            ? AppColors.error.withValues(alpha: 0.4)
            : AppColors.errorBorder;
        break;
      case BadgeVariant.warning:
        bg = isDark
            ? AppColors.warning.withValues(alpha: 0.18)
            : AppColors.warningBg;
        fg = isDark ? const Color(0xFFFCD34D) : AppColors.warning;
        border = isDark
            ? AppColors.warning.withValues(alpha: 0.4)
            : AppColors.warningBorder;
        break;
      case BadgeVariant.info:
        bg = isDark ? AppColors.info.withValues(alpha: 0.18) : AppColors.infoBg;
        fg = isDark ? const Color(0xFF7DD3FC) : AppColors.info;
        border = isDark
            ? AppColors.info.withValues(alpha: 0.4)
            : AppColors.infoBorder;
        break;
      case BadgeVariant.purple:
        bg = isDark
            ? AppColors.purple.withValues(alpha: 0.18)
            : AppColors.purpleBg;
        fg = isDark ? const Color(0xFFDDD6FE) : AppColors.purple;
        border = isDark
            ? AppColors.purple.withValues(alpha: 0.4)
            : AppColors.purpleBorder;
        break;
      case BadgeVariant.outline:
        bg = isDark ? AppColors.darkSurface : Colors.transparent;
        fg = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
        border = isDark ? AppColors.darkBorder : AppColors.border;
        break;
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isLivePulse) ...[
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 5),
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
            ),
          ] else if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
