import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum ButtonVariant { primary, secondary, outline, text, danger, saffron }

class ModernButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final double? width;
  final double height;
  final double borderRadius;

  const ModernButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = ButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height = 46,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color bg;
    Color fg;
    BorderSide border = BorderSide.none;

    switch (variant) {
      case ButtonVariant.primary:
        bg = AppTheme.primary;
        fg = Colors.black;
        break;
      case ButtonVariant.saffron:
        bg = AppColors.primary;
        fg = Colors.white;
        break;
      case ButtonVariant.secondary:
        bg = isDark ? AppColors.darkSurfaceCard : AppColors.surfaceSubtle;
        fg = isDark ? AppColors.darkTextPrimary : AppColors.deepInk;
        border = BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.border,
          width: 1,
        );
        break;
      case ButtonVariant.outline:
        bg = Colors.transparent;
        fg = isDark ? AppColors.darkTextPrimary : AppColors.deepInk;
        border = BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.border,
          width: 1,
        );
        break;
      case ButtonVariant.text:
        bg = Colors.transparent;
        fg = isDark ? AppColors.primaryLight : AppColors.primaryDark;
        break;
      case ButtonVariant.danger:
        bg = AppTheme.error;
        fg = Colors.white;
        break;
    }

    final child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: fg),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          );

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: border,
        ),
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }
}
