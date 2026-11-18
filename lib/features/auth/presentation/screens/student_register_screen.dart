import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/modern_button.dart';
import '../../../../core/widgets/modern_card.dart';
import '../../logic/auth_provider.dart';
import '../../../../providers/course_provider.dart';

class StudentRegisterScreen extends StatefulWidget {
  const StudentRegisterScreen({super.key});

  @override
  State<StudentRegisterScreen> createState() => _StudentRegisterScreenState();
}

class _StudentRegisterScreenState extends State<StudentRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final TextEditingController _cityCtrl = TextEditingController(text: "Patna");

  String _selectedMedium = "Bilingual (Hindi + English)";
  bool _isLoading = false;
  bool _obscurePass = true;
  bool _agreedToTerms = false;
  bool _termsError = false;

  final List<String> _mediumOptions = [
    "Bilingual (Hindi + English)",
    "Hindi Medium",
    "English Medium",
  ];

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  void _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreedToTerms) {
      setState(() {
        _termsError = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please confirm age eligibility and accept the Terms of Use & Privacy Policy to register."),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _termsError = false;
    });

    final auth = context.read<AuthProvider>();
    final success = await auth.registerStudent(
      phone: "",
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text.trim(),
      targetExam: "",
      medium: _selectedMedium,
      termsAgreed: _agreedToTerms,
      termsAgreedAt: DateTime.now().toUtc().toIso8601String(),
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    if (success) {
      if (auth.requiresEmailConfirmation) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) {
            final isDarkDialog = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDarkDialog ? AppColors.darkSurfaceCard : AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: isDarkDialog ? AppColors.darkBorder : AppColors.border),
              ),
              title: Text(
                "Verify Your Account",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isDarkDialog ? AppColors.darkTextPrimary : AppColors.deepInk,
                ),
              ),
              content: Text(
                "Check your email to verify your account before logging in.",
                style: TextStyle(color: isDarkDialog ? AppColors.darkTextSecondary : AppColors.textSecondary),
              ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text(
                  "OK",
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      );
    } else {
        if (mounted) {
          context.read<CourseProvider>().fetchMyEnrollments();
        }
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } else if (auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage!),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }


  void _showPolicyDialog(BuildContext context, String title, String body) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              body,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Close",
              style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text("Student Registration")),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.primary.withValues(alpha: 0.2) : AppColors.saffronMuted,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? AppColors.primary.withValues(alpha: 0.4) : AppColors.saffronBorder),
                          ),
                          child: Icon(
                            Icons.person_add_alt_1_outlined,
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
                                "Create Student Account",
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                ),
                              ),
                              Text(
                                "Join Modern Classes Patna academic community",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Registration Form Card
                    ModernCard(
                      padding: const EdgeInsets.all(20),
                      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                      borderColor: isDark ? AppColors.darkBorder : AppColors.border,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "ACADEMIC ENROLLMENT DETAILS",
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(height: 14),



                          // Email Address
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: "Email Address *",
                              hintText: "e.g. student.patna@gmail.com",
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                size: 19,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return "Please enter email address";
                              }
                              if (!v.contains('@')) {
                                return "Enter a valid email";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          // Password
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: _obscurePass,
                            decoration: InputDecoration(
                              labelText: "Password *",
                              hintText: "Create a secure password",
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
                                onPressed: () => setState(
                                  () => _obscurePass = !_obscurePass,
                                ),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return "Please enter a password";
                              }
                              if (v.length < 6) {
                                return "Password must be at least 6 characters";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          // City / District
                          TextFormField(
                            controller: _cityCtrl,
                            decoration: const InputDecoration(
                              labelText: "District / City",
                              hintText: "Patna, Gaya, Muzaffarpur...",
                              prefixIcon: Icon(
                                Icons.location_city_outlined,
                                size: 19,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),



                          // Medium Preference
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _selectedMedium,
                            decoration: const InputDecoration(
                              labelText: "Preferred Medium of Instruction *",
                              prefixIcon: Icon(
                                Icons.language_outlined,
                                size: 19,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            dropdownColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                            items: _mediumOptions.map((opt) {
                              return DropdownMenuItem(
                                value: opt,
                                child: Text(
                                  opt,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _selectedMedium = v);
                              }
                            },
                          ),
                          const SizedBox(height: 16),

                          // Legal Terms & Privacy Consent Checkbox (Mandatory before account creation)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: _termsError
                                  ? AppColors.error.withValues(alpha: 0.08)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: _termsError
                                  ? Border.all(color: AppColors.errorBorder)
                                  : null,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    key: const Key('register_terms_checkbox'),
                                    value: _agreedToTerms,
                                    activeColor: AppColors.primaryDark,
                                    onChanged: (val) {
                                      setState(() {
                                        _agreedToTerms = val ?? false;
                                        if (_agreedToTerms) _termsError = false;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        "I confirm I am 18+ (or have parental consent) and agree to the ",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () => _showPolicyDialog(
                                          context,
                                          "Terms of Use",
                                          "Modern Classes Patna Terms of Use:\n\n"
                                          "1. Eligibility & Age: By creating an account, you affirm that you are at least 18 years of age, or if under 18, that you are accessing the platform with the consent and supervision of a parent or legal guardian who agrees to be bound by these Terms.\n\n"
                                          "2. Single-Device Session: Student accounts are restricted to one active smartphone at a time.\n\n"
                                          "3. Intellectual Property: Lecture archives, PDF notes, and test questions are copyrighted property of Modern Classes Patna. Screen recording, downloading, and external distribution are strictly prohibited.\n\n"
                                          "4. Academic Integrity: Mock tests and doubts must be submitted honestly without unauthorized assistance.\n\n"
                                          "5. Limitation of Liability: Educational coaching services are provided 'as is' without guarantee of specific rank or government selection. Liability is capped at fees paid in the prior 12 months.\n\n"
                                          "6. Jurisdiction: Governed exclusively by the laws of India and courts in Patna, Bihar.",
                                        ),
                                        child: const Text(
                                          "Terms of Use",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryDark,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        " and ",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () => _showPolicyDialog(
                                          context,
                                          "Privacy Policy",
                                          "Modern Classes Patna Privacy Policy:\n\n"
                                          "1. Data Collection: We collect student name, mobile number, email, target exam, and performance scores solely for educational delivery and security.\n\n"
                                          "2. Zero Advertising: We do not display ads, sell student data, or share personal profiles with commercial marketing networks.\n\n"
                                          "3. Cloud Security: Managed via Supabase with PostgreSQL Row Level Security (RLS) and TLS 1.3 encryption.\n\n"
                                          "4. Account Deletion: Students may request complete account and data deletion at any time in Profile Settings or by emailing madhurendrayadav06@gmail.com.\n\n"
                                          "5. Contact: Madhurendra Kumar Yadav, Director, Patna, Bihar.",
                                        ),
                                        child: const Text(
                                          "Privacy Policy",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryDark,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        " *",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_termsError)
                            const Padding(
                              padding: EdgeInsets.only(left: 32, top: 4),
                              child: Text(
                                "Confirmation of age and agreement to Terms & Privacy Policy is required",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          const SizedBox(height: 18),

                          // Submit Button
                          ModernButton(
                            key: const Key('register_submit_button'),
                            text: "Create Account & Start Learning",
                            width: double.infinity,
                            height: 48,
                            isLoading: _isLoading,
                            icon: Icons.check_circle_outline,
                            onPressed: _submitRegistration,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Back to Login
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            "Already have an account?",
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text(
                              "Sign In",
                              style: TextStyle(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
