import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Universal Academic Empty State Widget.
/// Displays an intentional, dignified message with no generic fluff.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    String? description,
    String? subtitle,
    String? actionLabel,
    String? actionText,
    this.onAction,
  }) : description = description ?? subtitle ?? '',
       actionLabel = actionLabel ?? actionText;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxl,
          vertical: AppSpacing.md,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceSubtle,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
              ),
              child: Icon(
                icon,
                size: 36,
                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: AppTypography.titleMedium.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                description,
                style: AppTypography.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.primary : AppColors.deepInk,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                ),
                onPressed: onAction,
                child: Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
