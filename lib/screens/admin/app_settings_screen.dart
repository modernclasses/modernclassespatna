import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("App Config & Security Settings"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Center Identity Card
            ModernCard(
              padding: const EdgeInsets.all(16),
              backgroundColor: AppTheme.surfaceCard,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified, color: AppTheme.primary, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Modern Classes Patna Organization",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: AppTheme.border),
                  const SizedBox(height: 10),
                  _buildSettingRow("Director / Owner", "Madhurendra Kumar Yadav"),
                  _buildSettingRow("Helpline Phone", "+91 6209016951"),
                  _buildSettingRow("Official Email", "madhurendrayadav06@gmail.com"),
                  _buildSettingRow("Campus Location", "Musallahpur Hat / Boring Road, Patna"),
                  _buildSettingRow("Platform Scalability", "100k Concurrent Students Ready"),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // App Security & Role Lock (Requirement 59: "Another person not control my app")
            const Text(
              "Access Control & Security Protection",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ModernCard(
              padding: const EdgeInsets.all(16),
              backgroundColor: AppTheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Master Admin Seats",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      CustomBadge(text: "5 / 5 Seats Locked", variant: BadgeVariant.success),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Strict role verification prevents unauthorized administrative privilege access.",
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: AppTheme.border),
                  const SizedBox(height: 10),
                  _buildSecurityToggle("Anti-Piracy Screen Recording Protection", true),
                  _buildSecurityToggle("Single Device Student Session Lock", true),
                  _buildSecurityToggle("Watermarked Dynamic DRM Video Stream", true),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Gateway & Integration Status
            const Text(
              "Gateway & Cloud Status",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ModernCard(
              padding: const EdgeInsets.all(16),
              backgroundColor: AppTheme.surface,
              child: Column(
                children: [
                  _buildStatusRow("Payment Gateway", "Razorpay / UPI Live", AppTheme.success),
                  _buildStatusRow("Live Streaming Engine", "YouTube Live RTMP Integrated", AppTheme.success),
                  _buildStatusRow("Test Auto-Grader", "Instant Rank Engine Active", AppTheme.success),
                  _buildStatusRow("Cloud Data Backup", "Secured & Encrypted Daily", AppTheme.secondaryLight),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildSecurityToggle(String label, bool value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
          ),
          const Icon(Icons.check_circle, size: 18, color: AppTheme.success),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}
