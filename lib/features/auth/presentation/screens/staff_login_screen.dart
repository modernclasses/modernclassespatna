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

class _StaffLoginScreenState extends State<StaffLoginScreen>
    with SingleTickerProviderStateMixin {
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
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
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
        const SnackBar(
          content: Text("Please enter your faculty email and password."),
        ),
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
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _loginAdmin() async {
    final email = _adminEmailCtrl.text.trim();
    final password = _adminPassCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter your administrator email and password."),
        ),
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
          content: Text(
            auth.errorMessage ?? "Invalid administrator credentials.",
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text("Staff & Faculty Portal")),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: AppLogo(size: 64, showShadow: false)),
                  const SizedBox(height: 12),
                  Text(
                    "MODERN CLASSES PATNA",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Authorized Institutional & Faculty Access",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tab Bar for Faculty vs Admin
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      labelColor: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                      unselectedLabelColor: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.school_outlined, size: 17),
                          text: "Faculty Login",
                        ),
                        Tab(
                          icon: Icon(
                            Icons.admin_panel_settings_outlined,
                            size: 17,
                          ),
                          text: "Admin Login",
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tab Content Area
                  SizedBox(
                    height: 380,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // --- FACULTY TAB ---
                        ModernCard(
                          accentSpineColor: AppColors.secondary,
                          padding: const EdgeInsets.all(20),
                          backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const CustomBadge(
                                    text: "TEACHER / FACULTY",
                                    variant: BadgeVariant.secondary,
                                  ),
                                  const Spacer(),
                                  Icon(
                                    Icons.verified_user_outlined,
                                    size: 17,
                                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "FACULTY EMAIL",
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _teacherEmailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  hintText: "faculty@modernclasses.com",
                                  prefixIcon: Icon(
                                    Icons.email_outlined,
                                    size: 19,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                "PASSWORD",
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _teacherPassCtrl,
                                obscureText: _obscureTeacherPass,
                                decoration: InputDecoration(
                                  hintText: "Enter faculty password",
                                  prefixIcon: const Icon(
                                    Icons.lock_outline,
                                    size: 19,
                                    color: AppColors.secondary,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureTeacherPass
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      size: 19,
                                      color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureTeacherPass =
                                          !_obscureTeacherPass,
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              ModernButton(
                                text: "Sign In as Faculty",
                                width: double.infinity,
                                height: 46,
                                isLoading: auth.isLoading,
                                onPressed: _loginFaculty,
                              ),
                            ],
                          ),
                        ),

                        // --- ADMIN TAB ---
                        ModernCard(
                          accentSpineColor: AppColors.purple,
                          padding: const EdgeInsets.all(20),
                          backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  CustomBadge(
                                    text: "MASTER ADMINISTRATOR",
                                    variant: BadgeVariant.purple,
                                  ),
                                  Spacer(),
                                  Icon(
                                    Icons.security,
                                    size: 17,
                                    color: AppColors.purple,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "ADMIN EMAIL",
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _adminEmailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  hintText: "admin@modernclassespatna.com",
                                  prefixIcon: Icon(
                                    Icons.email_outlined,
                                    size: 19,
                                    color: AppColors.purple,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                "MASTER PASSWORD",
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _adminPassCtrl,
                                obscureText: _obscureAdminPass,
                                decoration: InputDecoration(
                                  hintText: "Enter master admin password",
                                  prefixIcon: const Icon(
                                    Icons.lock_outline,
                                    size: 19,
                                    color: AppColors.purple,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureAdminPass
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      size: 19,
                                      color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureAdminPass =
                                          !_obscureAdminPass,
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              ModernButton(
                                text: "Authenticate as Admin",
                                width: double.infinity,
                                height: 46,
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
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
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
