import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class NameSelectionScreen extends StatefulWidget {
  const NameSelectionScreen({super.key});

  @override
  State<NameSelectionScreen> createState() => _NameSelectionScreenState();
}

class _NameSelectionScreenState extends State<NameSelectionScreen> {
  final _nameCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitName() async {
    final newName = _nameCtrl.text.trim();
    if (newName.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await context.read<AuthProvider>().updateDisplayName(newName);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: const Key('name_selection_root'),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Choose Your Display Name'),
        centerTitle: true,
        automaticallyImplyLeading: false, // Must select a name
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.badge, size: 64, color: isDark ? AppColors.primaryLight : AppTheme.primary),
              const SizedBox(height: 24),
              Text(
                "Set Your Name",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Please enter your full name as you want it to appear in classes and leaderboards. You cannot change this later.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppTheme.error, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              TextField(
                key: const Key('name_input_field'),
                controller: _nameCtrl,
                style: TextStyle(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                ),
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person, color: isDark ? AppColors.primaryLight : AppTheme.primary),
                ),
                maxLength: 15,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                key: const Key('name_submit_button'),
                onPressed: _isLoading ? null : _submitName,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Name',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
