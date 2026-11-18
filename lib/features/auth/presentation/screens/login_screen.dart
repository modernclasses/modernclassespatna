import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent, AuthState, Supabase;
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/modern_button.dart';
import '../../../../core/widgets/modern_card.dart';
import '../../logic/auth_provider.dart';
import '../../../../providers/course_provider.dart';
import 'student_register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePass = true;
  bool _isResetDialogActive = false;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _initAuthRecoveryListener();
  }

  void _initAuthRecoveryListener() {
    if (!AppConfig.isSupabaseConfigured || AppConfig.isTestMode) return;
    try {
      _authSubscription =
          Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (!mounted) return;
        // Never trigger duplicate dialog when user is already recovering in a dialog
        if (_isResetDialogActive) return;
        if (data.event == AuthChangeEvent.passwordRecovery) {
          _showRecoveryNewPasswordDialog();
        }
      });
    } catch (_) {}
  }

  void _showRecoveryNewPasswordDialog() {
    if (_isResetDialogActive) return;
    _isResetDialogActive = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _RecoveryNewPasswordDialog(
        onPasswordResetSuccess: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Password updated successfully! Please sign in with your new password.',
              ),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 5),
            ),
          );
        },
      ),
    ).then((_) {
      if (mounted) {
        _isResetDialogActive = false;
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _loginStudent() async {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your registered email")),
      );
      return;
    }

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your password")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final auth = context.read<AuthProvider>();
    final success = await auth.loginStudent(
      phoneOrEmail: email,
      password: password,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    if (success) {
      if (mounted) {
        context.read<CourseProvider>().fetchMyEnrollments();
      }
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      final msg =
          auth.errorMessage ?? "Invalid login credentials. Please try again.";
      final isVerifyError = msg.contains('verify your account');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.error,
          duration: isVerifyError
              ? const Duration(seconds: 10)
              : const Duration(seconds: 4),
          action: isVerifyError
              ? SnackBarAction(
                  label: 'Resend Email',
                  textColor: Colors.white,
                  onPressed: () async {
                    final resendSuccess = await auth.resendConfirmationEmail(
                      email,
                    );
                    if (resendSuccess && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Verification email resent.'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    } else if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            auth.errorMessage ?? 'Failed to resend.',
                          ),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                )
              : null,
        ),
      );
    }
  }

  void _showForgotPasswordDialog() {
    final initialEmail = _emailCtrl.text.trim();
    _isResetDialogActive = true;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _ForgotPasswordDialog(
        initialEmail: initialEmail,
        onPasswordResetSuccess: (email) {
          _emailCtrl.text = email;
          _passCtrl.clear();
        },
      ),
    ).then((_) {
      if (mounted) {
        _isResetDialogActive = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text("Student Sign In")),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppLogo(size: 68, showShadow: false),
                  const SizedBox(height: 14),
                  Text(
                    "Student Learning Portal",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Sign in to access your enrolled batches, live classes & test series",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Login Box
                  ModernCard(
                    padding: const EdgeInsets.all(22),
                    backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                    borderColor: isDark ? AppColors.darkBorder : AppColors.border,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "STUDENT CREDENTIALS",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: "Registered Email Address",
                            prefixIcon: Icon(
                              Icons.email_outlined,
                              size: 19,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passCtrl,
                          obscureText: _obscurePass,
                          decoration: InputDecoration(
                            labelText: "Password",
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              size: 19,
                              color: AppColors.primaryDark,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePass
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                size: 19,
                                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                              ),
                              onPressed: () =>
                                  setState(() => _obscurePass = !_obscurePass),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: _showForgotPasswordDialog,
                                child: const Text(
                                  "Forgot Password?",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primaryDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Helpdesk: +91 6209016951"),
                                  ),
                                );
                              },
                              child: Text(
                                "Need Help?",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        ModernButton(
                          text: "Sign In to Student App",
                          width: double.infinity,
                          height: 46,
                          isLoading: _isLoading,
                          icon: Icons.login_rounded,
                          onPressed: _loginStudent,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Register Link
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        "New to Modern Classes Patna?",
                        style: TextStyle(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const StudentRegisterScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          "Register Now",
                          style: TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Text(
                    "Modern Classes Patna • Madhurendra Kumar Yadav (+91 6209016951)",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.textMuted),
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


/// Dedicated student password recovery dialog supporting both email reset links
/// and 6-digit recovery OTP codes.
class _ForgotPasswordDialog extends StatefulWidget {
  final String initialEmail;
  final ValueChanged<String> onPasswordResetSuccess;

  const _ForgotPasswordDialog({
    required this.initialEmail,
    required this.onPasswordResetSuccess,
  });

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _emailCtrl;
  final TextEditingController _otpCtrl = TextEditingController();
  final TextEditingController _newPassCtrl = TextEditingController();
  final TextEditingController _confirmPassCtrl = TextEditingController();

  bool _isEnteringOtp = false;
  bool _isLoading = false;
  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;
  String? _statusMessage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  void _sendResetEmail() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage = "Please enter a valid registered email address.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = null;
    });

    final auth = context.read<AuthProvider>();
    final success = await auth.sendPasswordResetEmail(email);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    if (success) {
      setState(() {
        _statusMessage =
            "Password reset instructions have been sent to $email. Please check your inbox (and Spam folder) to reset your password.";
      });
    } else {
      setState(() {
        _errorMessage =
            auth.errorMessage ?? "Failed to send reset email. Please try again.";
      });
    }
  }

  void _verifyOtpAndResetPassword() async {
    final email = _emailCtrl.text.trim();
    final otp = _otpCtrl.text.trim();
    final newPass = _newPassCtrl.text.trim();
    final confirmPass = _confirmPassCtrl.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = "Please enter a valid registered email address.");
      return;
    }
    if (otp.isEmpty) {
      setState(() => _errorMessage = "Please enter the recovery code from your email.");
      return;
    }
    if (newPass.length < 6) {
      setState(() => _errorMessage = "Password must be at least 6 characters.");
      return;
    }
    if (newPass != confirmPass) {
      setState(() => _errorMessage = "Passwords do not match.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = null;
    });

    final auth = context.read<AuthProvider>();
    final success = await auth.verifyRecoveryOtpAndSetNewPassword(
      email: email,
      token: otp,
      newPassword: newPass,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    if (success) {
      widget.onPasswordResetSuccess(email);
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Password successfully updated! You can now sign in with your new password.",
          ),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 5),
        ),
      );
    } else {
      final rawError = auth.errorMessage ?? "Invalid or expired recovery code.";
      setState(() {
        if (rawError.toLowerCase().contains("expired") || rawError.toLowerCase().contains("invalid")) {
          _errorMessage = "The code entered is invalid or has expired. Please check your email for the latest code or tap '1. Request Code' above to receive a new one.";
        } else {
          _errorMessage = rawError;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      contentPadding: const EdgeInsets.all(20),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : AppColors.saffronMuted,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _isEnteringOtp
                          ? Icons.password_rounded
                          : Icons.lock_reset_rounded,
                      color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEnteringOtp ? "Set New Password" : "Reset Password",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.deepInk,
                          ),
                        ),
                        Text(
                          _isEnteringOtp
                              ? "Enter recovery code from email & choose new password"
                              : "Enter registered email to receive reset code",
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Segmented Tabs: 1. Request Code | 2. Enter Code
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBackground : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _isEnteringOtp = false;
                            _errorMessage = null;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !_isEnteringOtp ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.mail_outline_rounded,
                                size: 15,
                                color: !_isEnteringOtp
                                    ? Colors.white
                                    : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  "1. Request Code",
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: !_isEnteringOtp ? FontWeight.w800 : FontWeight.w600,
                                    color: !_isEnteringOtp
                                        ? Colors.white
                                        : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _isEnteringOtp = true;
                            _errorMessage = null;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _isEnteringOtp ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.pin_outlined,
                                size: 15,
                                color: _isEnteringOtp
                                    ? Colors.white
                                    : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  "2. Enter Code",
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: _isEnteringOtp ? FontWeight.w800 : FontWeight.w600,
                                    color: _isEnteringOtp
                                        ? Colors.white
                                        : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Success Banner
              if (_statusMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: AppColors.success,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.white : AppColors.deepInk,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Error Banner
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.error,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.error,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Email Field
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Registered Student Email",
                  hintText: "student@example.com",
                  prefixIcon: Icon(
                    Icons.email_outlined,
                    size: 19,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),

              if (_isEnteringOtp) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2),
                  decoration: const InputDecoration(
                    labelText: "Recovery Code / Token",
                    hintText: "Enter 6-digit code (e.g. 123456)",
                    helperText: "Check your email inbox for the 6-digit verification code",
                    prefixIcon: Icon(
                      Icons.pin_outlined,
                      size: 19,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newPassCtrl,
                  obscureText: _obscureNewPass,
                  decoration: InputDecoration(
                    labelText: "New Password",
                    hintText: "Min 6 characters",
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      size: 19,
                      color: AppColors.primaryDark,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNewPass
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 18,
                      ),
                      onPressed: () =>
                          setState(() => _obscureNewPass = !_obscureNewPass),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPassCtrl,
                  obscureText: _obscureConfirmPass,
                  decoration: InputDecoration(
                    labelText: "Confirm New Password",
                    hintText: "Re-enter new password",
                    prefixIcon: const Icon(
                      Icons.lock_reset,
                      size: 19,
                      color: AppColors.primaryDark,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPass
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 18,
                      ),
                      onPressed: () => setState(
                        () => _obscureConfirmPass = !_obscureConfirmPass,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Action button
              ModernButton(
                text: _isEnteringOtp ? "Set New Password" : "Send Reset Link",
                width: double.infinity,
                height: 44,
                isLoading: _isLoading,
                icon: _isEnteringOtp
                    ? Icons.check_circle_outline
                    : Icons.send_rounded,
                onPressed: _isEnteringOtp
                    ? _verifyOtpAndResetPassword
                    : _sendResetEmail,
              ),

              const SizedBox(height: 12),

              // Clearly Clickable Mode toggle button
              if (!_isEnteringOtp)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 2),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? AppColors.primaryLight : AppColors.primaryDark,
                      backgroundColor: isDark
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : AppColors.saffronMuted.withValues(alpha: 0.4),
                      side: BorderSide(
                        color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
                        width: 1.2,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.key_rounded, size: 17),
                    label: const Text(
                      "Have a recovery code? Enter Code & New Password",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    onPressed: () {
                      setState(() {
                        _isEnteringOtp = true;
                        _errorMessage = null;
                      });
                    },
                  ),
                )
              else
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text(
                      "← Back to Send Reset Link",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _isEnteringOtp = false;
                        _errorMessage = null;
                      });
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


/// Dedicated dialog for students arriving via recovery link/deep link
class _RecoveryNewPasswordDialog extends StatefulWidget {
  final VoidCallback onPasswordResetSuccess;

  const _RecoveryNewPasswordDialog({
    required this.onPasswordResetSuccess,
  });

  @override
  State<_RecoveryNewPasswordDialog> createState() => _RecoveryNewPasswordDialogState();
}

class _RecoveryNewPasswordDialogState extends State<_RecoveryNewPasswordDialog> {
  final TextEditingController _newPassCtrl = TextEditingController();
  final TextEditingController _confirmPassCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscureNewPass = true;
  bool _obscureConfirmPass = true;
  String? _errorMessage;

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  void _submitNewPassword() async {
    final newPass = _newPassCtrl.text.trim();
    final confirmPass = _confirmPassCtrl.text.trim();

    if (newPass.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters.');
      return;
    }
    if (newPass != confirmPass) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthProvider>();
    final success = await auth.updateUserPassword(newPass);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
      widget.onPasswordResetSuccess();
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    } else {
      setState(() {
        _errorMessage = auth.errorMessage ?? 'Failed to update password. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      contentPadding: const EdgeInsets.all(20),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : AppColors.saffronMuted,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.lock_reset_rounded,
                      color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Set New Password',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                          ),
                        ),
                        Text(
                          'Choose a new password for your account',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 11.5, color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _newPassCtrl,
                obscureText: _obscureNewPass,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  hintText: 'Min 6 characters',
                  prefixIcon: const Icon(Icons.lock_outline, size: 19, color: AppColors.primaryDark),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNewPass ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _obscureNewPass = !_obscureNewPass),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPassCtrl,
                obscureText: _obscureConfirmPass,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  hintText: 'Re-enter new password',
                  prefixIcon: const Icon(Icons.lock_reset, size: 19, color: AppColors.primaryDark),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPass ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ModernButton(
                text: 'Save New Password',
                width: double.infinity,
                height: 44,
                isLoading: _isLoading,
                icon: Icons.check_circle_outline,
                onPressed: _submitNewPassword,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
