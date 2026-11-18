import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final double borderRadius;
  final bool showShadow;
  final bool circular;

  const AppLogo({
    super.key,
    this.size = 64,
    this.borderRadius = 16,
    this.showShadow = true,
    this.circular = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = Image.asset(
      'assets/images/app_logo.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.warning],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(
              circular ? size / 2 : borderRadius,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            "M",
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w900,
              fontSize: size * 0.5,
            ),
          ),
        );
      },
    );

    if (circular) {
      imageWidget = ClipOval(child: imageWidget);
    } else {
      imageWidget = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: imageWidget,
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : BorderRadius.circular(borderRadius),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.25),
                  blurRadius: size * 0.3,
                  offset: Offset(0, size * 0.08),
                ),
              ]
            : null,
      ),
      child: imageWidget,
    );
  }
}
