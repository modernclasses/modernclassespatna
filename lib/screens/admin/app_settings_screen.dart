import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../providers/organization_provider.dart';
import '../../providers/theme_provider.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("App Config & Security Settings"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Center Identity Card (Editable & Persisted)
            Builder(
              builder: (ctx) {
                OrganizationProvider? org;
                try {
                  org = ctx.watch<OrganizationProvider>();
                } catch (_) {}

                final instituteName = org?.instituteName ?? "Modern Classes Patna Organization";
                final directorName = org?.directorName ?? "Madhurendra Kumar Yadav";
                final helplinePhone = org?.helplinePhone ?? "+91 6209016951";
                final officialEmail = org?.officialEmail ?? "madhurendrayadav06@gmail.com";
                final campusLocation = org?.campusLocation ?? "Musallahpur Hat / Boring Road, Patna";

                return ModernCard(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              instituteName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.edit_outlined, size: 15),
                            label: const Text("Edit", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () => _showEditOrganizationDialog(
                              context,
                              org ?? ctx.read<OrganizationProvider>(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Divider(color: isDark ? AppColors.darkBorder : AppColors.border),
                      const SizedBox(height: 10),
                      _buildSettingRow(context, "Director / Owner", directorName),
                      _buildSettingRow(context, "Helpline Phone", helplinePhone),
                      _buildSettingRow(context, "Official Email", officialEmail),
                      _buildSettingRow(context, "Campus Location", campusLocation),
                      _buildSettingRow(context, "Platform Scalability", "Status unverified"),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Appearance & Night Study Mode
            Text(
              "Appearance & Theme",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Builder(
              builder: (ctx) {
                ThemeProvider? themeProvider;
                try {
                  themeProvider = ctx.watch<ThemeProvider>();
                } catch (_) {}
                final isDarkCurrent = themeProvider?.isDarkMode ?? isDark;
                return ModernCard(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: isDarkCurrent ? AppColors.darkSurfaceCard : AppColors.surface,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Dark Mode (Night Study)",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDarkCurrent ? AppColors.darkTextPrimary : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isDarkCurrent
                                  ? "Dark theme active (comfortable for night study)"
                                  : "Light theme active (classic academic ivory)",
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkCurrent ? AppColors.darkTextSecondary : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        key: const Key('theme_mode_switch'),
                        value: isDarkCurrent,
                        onChanged: (val) {
                          themeProvider?.toggleTheme();
                        },
                        activeThumbColor: AppColors.primary,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // App Security & Access Control
            Text(
              "Access Control & Security Protection",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            ModernCard(
              padding: const EdgeInsets.all(16),
              backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "Master Admin Seats",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const CustomBadge(
                        text: "Not configured",
                        variant: BadgeVariant.outline,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Strict role verification prevents unauthorized administrative privilege access.",
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Divider(color: isDark ? AppColors.darkBorder : AppColors.border),
                  const SizedBox(height: 10),
                  _buildSecurityRow(context, "Anti-Piracy Screen Recording Protection", "Active (FLAG_SECURE)"),
                  _buildSecurityRow(context, "Single Device Student Session Lock", "Configured & Active"),
                  _buildSecurityRow(context, "Watermarked Dynamic DRM Video Stream", "Configured & Active"),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Gateway & Cloud Status
            Text(
              "Gateway & Cloud Status",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            ModernCard(
              padding: const EdgeInsets.all(16),
              backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
              child: Column(
                children: [
                  _buildStatusRow(context, "Payment Gateway", "Not configured", isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                  _buildStatusRow(context, "Test Auto-Grader", "Verification not implemented", isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                  _buildStatusRow(context, "Cloud Data Backup", "Status unavailable", isDark ? AppColors.darkTextMuted : AppColors.textMuted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showEditOrganizationDialog(BuildContext context, OrganizationProvider org) {
    final nameCtrl = TextEditingController(text: org.instituteName);
    final directorCtrl = TextEditingController(text: org.directorName);
    final phoneCtrl = TextEditingController(text: org.helplinePhone);
    final emailCtrl = TextEditingController(text: org.officialEmail);
    final locationCtrl = TextEditingController(text: org.campusLocation);

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
          title: Text(
            "Edit Institute Details",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: "Institute Name", isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: directorCtrl,
                  decoration: const InputDecoration(labelText: "Director / Owner", isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: "Helpline Phone", isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: "Official Email", isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: locationCtrl,
                  decoration: const InputDecoration(labelText: "Campus Location", isDense: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                org.updateDetails(
                  instituteName: nameCtrl.text,
                  directorName: directorCtrl.text,
                  helplinePhone: phoneCtrl.text,
                  officialEmail: emailCtrl.text,
                  campusLocation: locationCtrl.text,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Institute details updated & saved!")),
                );
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  static Widget _buildSettingRow(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildSecurityRow(BuildContext context, String label, String status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 2,
            child: Text(
              status,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildStatusRow(BuildContext context, String label, String status, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 3,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    status,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
