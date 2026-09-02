import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/custom_badge.dart';
import '../../../../core/widgets/modern_button.dart';
import '../../../../core/widgets/modern_card.dart';
import '../../../../models/user_model.dart';
import '../../logic/auth_provider.dart';

class StaffLoginScreen extends StatefulWidget {
  final int initialTabIndex;

  const StaffLoginScreen({super.key, this.initialTabIndex = 0});

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Faculty form
  final TextEditingController _teacherEmailCtrl = TextEditingController();
  final TextEditingController _teacherPassCtrl = TextEditingController();

  // Admin form
  final TextEditingController _adminEmailCtrl = TextEditingController();
  final TextEditingController _adminPassCtrl = TextEditingController();

  bool _obscureTeacherPass = true;
  bool _obscureAdminPass = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _teacherEmailCtrl.dispose();
    _teacherPassCtrl.dispose();
    _adminEmailCtrl.dispose();
    _adminPassCtrl.dispose();
    super.dispose();
  }

  void _loginFaculty() async {
    final email = _teacherEmailCtrl.text.trim();
    final password = _teacherPassCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your faculty email and password.")),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.loginStaff(
      email: email,
      password: password,
      expectedRole: UserRole.teacher,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? "Invalid faculty credentials."),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _loginAdmin() async {
    final email = _adminEmailCtrl.text.trim();
    final password = _adminPassCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your administrator email and password.")),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.loginStaff(
      email: email,
      password: password,
      expectedRole: UserRole.admin,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? "Invalid administrator credentials."),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Staff & Faculty Portal"),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: AppLogo(size: 64)),
              const SizedBox(height: 12),
              const Text(
                "Modern Classes Patna",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Authorized Institutional Access Only",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),

              // Tab Bar for Faculty vs Admin
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelColor: AppTheme.background,
                  unselectedLabelColor: AppTheme.textSecondary,
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.school, size: 18),
                      text: "Faculty Login",
                    ),
                    Tab(
                      icon: Icon(Icons.admin_panel_settings, size: 18),
                      text: "Admin Login",
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tab Content Area
              SizedBox(
                height: 380,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // --- FACULTY TAB ---
                    ModernCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              CustomBadge(
                                text: "TEACHER / FACULTY",
                                variant: BadgeVariant.primary,
                              ),
                              Spacer(),
                              Icon(Icons.verified_user_outlined, size: 18, color: AppTheme.textSecondary),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text("Faculty Email", style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _teacherEmailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: "faculty@modernclasses.com",
                              prefixIcon: Icon(Icons.email_outlined, size: 20),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text("Password", style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _teacherPassCtrl,
                            obscureText: _obscureTeacherPass,
                            decoration: InputDecoration(
                              hintText: "Enter your password",
                              prefixIcon: const Icon(Icons.lock_outline, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureTeacherPass ? Icons.visibility_off : Icons.visibility,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscureTeacherPass = !_obscureTeacherPass),
                              ),
                            ),
                          ),
                          const Spacer(),
                          ModernButton(
                            text: "Sign In as Faculty",
                            isLoading: auth.isLoading,
                            onPressed: _loginFaculty,
                          ),
                        ],
                      ),
                    ),

                    // --- ADMIN TAB ---
                    ModernCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              CustomBadge(
                                text: "MASTER ADMINISTRATOR",
                                variant: BadgeVariant.secondary,
                              ),
                              Spacer(),
                              Icon(Icons.security, size: 18, color: AppTheme.secondary),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text("Admin Email", style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _adminEmailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: "admin@modernclassespatna.com",
                              prefixIcon: Icon(Icons.email_outlined, size: 20),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text("Master Password", style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _adminPassCtrl,
                            obscureText: _obscureAdminPass,
                            decoration: InputDecoration(
                              hintText: "Enter master admin password",
                              prefixIcon: const Icon(Icons.lock_outline, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureAdminPass ? Icons.visibility_off : Icons.visibility,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscureAdminPass = !_obscureAdminPass),
                              ),
                            ),
                          ),
                          const Spacer(),
                          ModernButton(
                            text: "Authenticate as Admin",
                            isLoading: auth.isLoading,
                            onPressed: _loginAdmin,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Notice: All staff logins and administrative actions are logged and authenticated via server-side cryptographic tokens.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
