import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_logo.dart';
import '../../core/widgets/modern_button.dart';
import '../../core/widgets/modern_card.dart';
import '../../providers/auth_provider.dart';
import 'student_register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneCtrl = TextEditingController(text: "9876543210");
  final TextEditingController _passCtrl = TextEditingController(text: "••••••••");
  bool _isOtpMode = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _loginStudent() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your mobile number or email")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final auth = context.read<AuthProvider>();
    final success = await auth.loginStudent(
      phoneOrEmail: phone,
      password: _passCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    if (success) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else if (auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Student Sign In"),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo & Header
                  const AppLogo(size: 72),
                  const SizedBox(height: 14),
                  const Text(
                    "Student Learning Portal",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    "Sign in to access your batches, live classes & test series",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 24),

                  // Login Box
                  ModernCard(
                    padding: const EdgeInsets.all(20),
                    backgroundColor: AppTheme.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isOtpMode ? "Enter One-Time Password (OTP)" : "Student Login Credentials",
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: "Registered Mobile / Email",
                            prefixIcon: Icon(Icons.phone_android, size: 20, color: AppTheme.primary),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (!_isOtpMode) ...[
                          TextField(
                            controller: _passCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: "Password",
                              prefixIcon: Icon(Icons.lock_outline, size: 20, color: AppTheme.primary),
                            ),
                          ),
                        ] else ...[
                          const TextField(
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "Enter 6-Digit OTP",
                              hintText: "123456",
                              prefixIcon: Icon(Icons.sms_outlined, size: 20, color: AppTheme.primary),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isOtpMode = !_isOtpMode;
                                });
                              },
                              child: Text(
                                _isOtpMode ? "Use Password" : "Login via OTP",
                                style: const TextStyle(fontSize: 12, color: AppTheme.primary),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Helpdesk: +91 6209016951")),
                                );
                              },
                              child: const Text(
                                "Need Help?",
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        ModernButton(
                          text: _isOtpMode ? "Verify OTP & Sign In" : "Sign In to Student App",
                          width: double.infinity,
                          height: 48,
                          isLoading: _isLoading,
                          icon: Icons.login,
                          onPressed: _loginStudent,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Register Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("New to Modern Classes Patna?", style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const StudentRegisterScreen()),
                          );
                        },
                        child: const Text(
                          "Register Now",
                          style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Quick Demo student auto-fill
                  OutlinedButton.icon(
                    icon: const Icon(Icons.touch_app, size: 16, color: AppTheme.primary),
                    label: const Text("1-Tap Demo Student Login (Rohan Kumar)", style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      _phoneCtrl.text = "9876543210";
                      _loginStudent();
                    },
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    "Modern Classes Patna • Madhurendra Kumar Yadav (+91 6209016951)",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
