import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/modern_button.dart';
import '../../models/notification_model.dart';
import '../../providers/notification_provider.dart';

class BroadcastAnnouncementScreen extends StatefulWidget {
  const BroadcastAnnouncementScreen({super.key});

  @override
  State<BroadcastAnnouncementScreen> createState() => _BroadcastAnnouncementScreenState();
}

class _BroadcastAnnouncementScreenState extends State<BroadcastAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  NotificationCategory _category = NotificationCategory.announcement;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _sendBroadcast() {
    if (_formKey.currentState!.validate()) {
      final notifProvider = context.read<NotificationProvider>();
      notifProvider.broadcastAnnouncement(
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        category: _category,
      );

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🚀 Global announcement pushed to all students & app devices!"),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Broadcast Notice & Alerts"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Notification Category", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  NotificationCategory.announcement,
                  NotificationCategory.liveClass,
                  NotificationCategory.test,
                  NotificationCategory.reminder,
                ].map((cat) {
                  final isSelected = _category == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat.name.toUpperCase()),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _category = cat),
                      backgroundColor: AppTheme.surfaceLight,
                      selectedColor: AppTheme.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.black : AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              const Text("Announcement Content", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: "Notice Headline / Title",
                  hintText: "e.g. Special Patna Offline & Online Seminar Schedule",
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? "Enter title" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _messageController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: "Full Announcement Details",
                  hintText: "Enter complete notice description that will be pushed to all student devices...",
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? "Enter message details" : null,
              ),
              const SizedBox(height: 24),

              ModernButton(
                text: "Send Push Broadcast to All Students",
                width: double.infinity,
                icon: Icons.campaign,
                onPressed: _sendBroadcast,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
