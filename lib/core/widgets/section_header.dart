import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? eyebrow;
  final String? subtitle;
  final String? actionText;
  final VoidCallback? onActionTap;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.actionText,
    this.onActionTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eyebrow != null) ...[
                  Text(
                    eyebrow!.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: isDark
                          ? AppColors.primaryLight
                          : AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (actionText != null && onActionTap != null)
            TextButton(
              onPressed: onActionTap,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionText!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.primaryLight
                      : AppColors.primaryDark,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
