import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Universal Academic Error Display View with Retry capability.
class AppErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const AppErrorView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.error.withValues(alpha: 0.18)
                    : AppColors.errorBg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? AppColors.error.withValues(alpha: 0.4)
                      : AppColors.errorBorder,
                ),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 36,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              "Unable to Load Data",
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                message,
                style: AppTypography.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.primary : AppColors.deepInk,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text(
                  "Retry Connection",
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
