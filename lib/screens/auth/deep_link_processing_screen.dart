import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/auth/logic/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../app.dart';

class DeepLinkProcessingScreen extends StatefulWidget {
  final String code;

  const DeepLinkProcessingScreen({super.key, required this.code});

  @override
  State<DeepLinkProcessingScreen> createState() =>
      _DeepLinkProcessingScreenState();
}

class _DeepLinkProcessingScreenState extends State<DeepLinkProcessingScreen> {
  bool _processed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_processed) {
        _processed = true;
        _processCode();
      }
    });
  }

  Future<void> _processCode() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      await authProvider.processDeepLinkCode(widget.code);
    } catch (e) {
      // Ignore if it fails (e.g., code already used by supabase_flutter implicitly)
      debugPrint("DeepLink processing note: $e");
    } finally {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const RootGateScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.primary),
            const SizedBox(height: 24),
            Text(
              "Authenticating...",
              style: TextStyle(
                color: isDark ? AppColors.darkTextPrimary : AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
