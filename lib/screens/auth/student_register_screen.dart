import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/modern_button.dart';
import '../../core/widgets/modern_card.dart';
import '../../providers/auth_provider.dart';

class StudentRegisterScreen extends StatefulWidget {
  const StudentRegisterScreen({super.key});

  @override
  State<StudentRegisterScreen> createState() => _StudentRegisterScreenState();
}

class _StudentRegisterScreenState extends State<StudentRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _cityCtrl = TextEditingController(text: "Patna");

  String _selectedExam = "BPSC 71st Civil Services";
  String _selectedMedium = "Bilingual (Hindi + English)";
  bool _isLoading = false;

  final List<String> _examOptions = [
    "BPSC 71st Civil Services",
    "Bihar SSC Inter Level / CGL",
    "Railway NTPC & Group D",
    "12th Board Science Special",
    "General Studies Comprehensive",
  ];

  final List<String> _mediumOptions = [
    "Bilingual (Hindi + English)",
    "Hindi Medium",
    "English Medium",
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  void _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    auth.registerStudent(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim().isNotEmpty
          ? _emailCtrl.text.trim()
          : "${_phoneCtrl.text.trim()}@student.modernclasses.com",
      targetExam: _selectedExam,
      medium: _selectedMedium,
    );

    // Pop back to root gate
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Student Registration"),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
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
                            color: AppTheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.person_add, color: AppTheme.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Create Student Account",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "Join Modern Classes Patna community",
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Registration Form Card
                    ModernCard(
                      padding: const EdgeInsets.all(20),
                      backgroundColor: AppTheme.surface,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Full Name
                          TextFormField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              labelText: "Student Full Name *",
                              hintText: "e.g. Amit Kumar",
                              prefixIcon: Icon(Icons.person_outline, size: 20, color: AppTheme.primary),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? "Please enter your name" : null,
                          ),
                          const SizedBox(height: 14),

                          // Phone Number
                          TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: "Mobile Number (for OTP & Class Alerts) *",
                              hintText: "e.g. 9876543210",
                              prefixIcon: Icon(Icons.phone_android, size: 20, color: AppTheme.primary),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return "Please enter mobile number";
                              if (v.trim().length < 10) return "Enter valid 10-digit number";
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Email Address
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: "Email Address (Optional)",
                              hintText: "e.g. amit.patna@gmail.com",
                              prefixIcon: Icon(Icons.email_outlined, size: 20, color: AppTheme.primary),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // City / District
                          TextFormField(
                            controller: _cityCtrl,
                            decoration: const InputDecoration(
                              labelText: "District / City",
                              hintText: "Patna, Gaya, Muzaffarpur...",
                              prefixIcon: Icon(Icons.location_city, size: 20, color: AppTheme.primary),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Target Exam Dropdown
                          DropdownButtonFormField<String>(
                            initialValue: _selectedExam,
                            decoration: const InputDecoration(
                              labelText: "Primary Target Exam Goal *",
                              prefixIcon: Icon(Icons.emoji_events_outlined, size: 20, color: AppTheme.primary),
                            ),
                            dropdownColor: AppTheme.surfaceCard,
                            items: _examOptions.map((opt) {
                              return DropdownMenuItem(value: opt, child: Text(opt, style: const TextStyle(fontSize: 13)));
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _selectedExam = v);
                            },
                          ),
                          const SizedBox(height: 14),

                          // Medium Preference
                          DropdownButtonFormField<String>(
                            initialValue: _selectedMedium,
                            decoration: const InputDecoration(
                              labelText: "Preferred Medium of Instruction *",
                              prefixIcon: Icon(Icons.language, size: 20, color: AppTheme.primary),
                            ),
                            dropdownColor: AppTheme.surfaceCard,
                            items: _mediumOptions.map((opt) {
                              return DropdownMenuItem(value: opt, child: Text(opt, style: const TextStyle(fontSize: 13)));
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _selectedMedium = v);
                            },
                          ),
                          const SizedBox(height: 24),

                          // Submit Button
                          ModernButton(
                            text: "Create Account & Start Learning",
                            width: double.infinity,
                            height: 50,
                            isLoading: _isLoading,
                            icon: Icons.check_circle_outline,
                            onPressed: _submitRegistration,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Quick Fill Demo button for testing convenience
                    Center(
                      child: TextButton.icon(
                        icon: const Icon(Icons.flash_on, size: 16, color: AppTheme.primary),
                        label: const Text(
                          "Auto-Fill Demo Student Details",
                          style: TextStyle(fontSize: 12, color: AppTheme.primary),
                        ),
                        onPressed: () {
                          setState(() {
                            _nameCtrl.text = "Ananya Singh";
                            _phoneCtrl.text = "9123456780";
                            _emailCtrl.text = "ananya.patna@gmail.com";
                            _cityCtrl.text = "Patna";
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Back to Login
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Already have an account?", style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text("Sign In", style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
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
