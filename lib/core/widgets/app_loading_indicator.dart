import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Universal Loading Spinner & State Placeholder.
class AppLoadingIndicator extends StatelessWidget {
  final String? message;
  final double size;

  const AppLoadingIndicator({super.key, this.message, this.size = 36.0});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(message!, style: AppTypography.bodyMedium),
          ],
        ],
      ),
    );
  }
}
