import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/custom_badge.dart';
import '../../../../core/widgets/modern_button.dart';
import '../../../../core/widgets/modern_card.dart';
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
  final TextEditingController _teacherIdCtrl = TextEditingController(text: "tch_001");
  final TextEditingController _teacherPassCtrl = TextEditingController(text: "••••••••");

  // Admin form
  final TextEditingController _adminIdCtrl = TextEditingController(text: "admin@modernclasses.com");
  final TextEditingController _adminPassCtrl = TextEditingController(text: "••••••••");
  final TextEditingController _adminPinCtrl = TextEditingController(text: "123456");

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _teacherIdCtrl.dispose();
    _teacherPassCtrl.dispose();
    _adminIdCtrl.dispose();
    _adminPassCtrl.dispose();
    _adminPinCtrl.dispose();
    super.dispose();
  }

  void _loginFaculty() async {
    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();
    final success = await auth.loginTeacher(
      staffId: _teacherIdCtrl.text.trim(),
      password: _teacherPassCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else if (auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage!)),
      );
    }
  }

  void _loginAdmin() async {
    final pin = _adminPinCtrl.text.trim();
    if (pin.isEmpty || pin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the 6-digit Master Security PIN (123456)")),
      );
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    final success = auth.loginAdmin(
      adminId: _adminIdCtrl.text.trim(),
      securityPin: pin,
    );

    if (success) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid Master PIN. Please enter correct PIN.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Staff & Management Gateway"),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  const AppLogo(size: 64),
                  const SizedBox(height: 14),

                  // Management Brand Crest
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_outlined, size: 16, color: AppTheme.primary),
                        SizedBox(width: 6),
                        Text(
                          "Modern Classes Management Console",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tab Bar
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: AppTheme.primary,
                      labelColor: AppTheme.primary,
                      unselectedLabelColor: AppTheme.textSecondary,
                      tabs: const [
                        Tab(
                          icon: Icon(Icons.cast_for_education, size: 20),
                          text: "Faculty Login",
                        ),
                        Tab(
                          icon: Icon(Icons.admin_panel_settings, size: 20),
                          text: "Admin Command",
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tab Views
                  SizedBox(
                    height: 420,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildFacultyTab(),
                        _buildAdminTab(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    "Madhurendra Kumar Yadav • Modern Classes Patna (+91 6209016951)",
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

  Widget _buildFacultyTab() {
    return ModernCard(
      padding: const EdgeInsets.all(20),
      backgroundColor: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Faculty Staff Sign In",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              CustomBadge(text: "Teaching Faculty", variant: BadgeVariant.secondary),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            "Access assigned batches, upload lecture notes, schedule live YouTube streams and resolve student doubts.",
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _teacherIdCtrl,
            decoration: const InputDecoration(
              labelText: "Faculty Staff ID",
              hintText: "e.g. MCP-FAC-01 or tch_001",
              prefixIcon: Icon(Icons.badge_outlined, size: 20, color: AppTheme.secondaryLight),
            ),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _teacherPassCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: "Faculty Password",
              prefixIcon: Icon(Icons.lock_outline, size: 20, color: AppTheme.secondaryLight),
            ),
          ),
          const SizedBox(height: 24),

          ModernButton(
            text: "Sign In as Faculty (Madhurendra Sir)",
            width: double.infinity,
            height: 48,
            isLoading: _isLoading,
            icon: Icons.cast_for_education,
            onPressed: _loginFaculty,
          ),
          const Spacer(),

          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.flash_on, size: 14, color: AppTheme.secondaryLight),
              label: const Text("1-Tap Demo Faculty Fill", style: TextStyle(fontSize: 11)),
              onPressed: () {
                _teacherIdCtrl.text = "tch_001";
                _loginFaculty();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminTab() {
    return ModernCard(
      padding: const EdgeInsets.all(20),
      backgroundColor: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Executive Admin Suite",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              CustomBadge(text: "5 Admin Seats Lock", variant: BadgeVariant.purple),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            "Central administration for course pricing, batch management, revenue ledger, student roster, and global push broadcasts.",
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _adminIdCtrl,
            decoration: const InputDecoration(
              labelText: "Admin Email / Key",
              prefixIcon: Icon(Icons.admin_panel_settings, size: 20, color: AppTheme.purple),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _adminPassCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: "Master Password",
              prefixIcon: Icon(Icons.lock_outline, size: 20, color: AppTheme.purple),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _adminPinCtrl,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: "6-Digit Master Security PIN *",
              hintText: "123456",
              counterText: "",
              prefixIcon: Icon(Icons.pin, size: 20, color: AppTheme.primary),
            ),
          ),
          const SizedBox(height: 16),

          ModernButton(
            text: "Unlock Admin Command Center",
            width: double.infinity,
            height: 48,
            isLoading: _isLoading,
            icon: Icons.vpn_key_outlined,
            onPressed: _loginAdmin,
          ),
          const Spacer(),

          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.flash_on, size: 14, color: AppTheme.purple),
              label: const Text("1-Tap Demo Admin Unlock (PIN: 123456)", style: TextStyle(fontSize: 11)),
              onPressed: () {
                _adminPinCtrl.text = "123456";
                _loginAdmin();
              },
            ),
          ),
        ],
      ),
    );
  }
}
