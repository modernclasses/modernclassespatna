import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/modern_button.dart';
import '../../core/widgets/modern_card.dart';
import '../../models/notification_model.dart';
import '../../features/courses/logic/course_provider.dart';
import '../../providers/notification_provider.dart';

enum BroadcastAudience { allStudents, specificBatches }

class BroadcastAnnouncementScreen extends StatefulWidget {
  const BroadcastAnnouncementScreen({super.key});

  @override
  State<BroadcastAnnouncementScreen> createState() =>
      _BroadcastAnnouncementScreenState();
}

class _BroadcastAnnouncementScreenState
    extends State<BroadcastAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  NotificationCategory _category = NotificationCategory.announcement;

  BroadcastAudience _audience = BroadcastAudience.allStudents;
  final Set<String> _selectedBatchIds = {};

  bool _isSending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendBroadcast() async {
    if (!_formKey.currentState!.validate() || _isSending) return;

    if (_audience == BroadcastAudience.specificBatches && _selectedBatchIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select at least one target batch"),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSending = true);
    final notifProvider = context.read<NotificationProvider>();
    try {
      if (_audience == BroadcastAudience.allStudents) {
        await notifProvider.broadcastAnnouncement(
          title: _titleController.text.trim(),
          message: _messageController.text.trim(),
          category: _category,
          targetBatchId: null,
        );
      } else {
        for (final bId in _selectedBatchIds) {
          await notifProvider.broadcastAnnouncement(
            title: _titleController.text.trim(),
            message: _messageController.text.trim(),
            category: _category,
            targetBatchId: bId,
          );
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
      final countMsg = _audience == BroadcastAudience.allStudents
          ? "pushed to all students across institute"
          : "pushed to ${_selectedBatchIds.length} targeted batch(es)";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("🚀 Announcement $countMsg!"),
          backgroundColor: AppColors.emerald,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to broadcast: $e"),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final courseProvider = context.watch<CourseProvider>();
    final allBatches = courseProvider.batches;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Institute Broadcast Desk"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDark ? AppColors.darkBorder : AppColors.border,
            height: 1,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              ModernCard(
                padding: const EdgeInsets.all(16),
                backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                accentSpineColor: AppColors.saffron,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.primary.withValues(alpha: 0.2) : AppColors.saffronMuted,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.campaign_rounded,
                        color: isDark ? AppColors.primaryLight : AppColors.saffronDark,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Push Announcement Desk",
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            "Deliver targeted instant notifications to all students or specific batches.",
                            style: AppTypography.caption.copyWith(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // TARGET RECIPIENTS SECTION
              Text(
                "TARGET AUDIENCE *",
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.public, size: 16),
                          SizedBox(width: 6),
                          Text("All Students"),
                        ],
                      ),
                      selected: _audience == BroadcastAudience.allStudents,
                      onSelected: (_) => setState(() => _audience = BroadcastAudience.allStudents),
                      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                      selectedColor: isDark ? AppColors.primary.withValues(alpha: 0.25) : AppColors.saffronMuted,
                      labelStyle: TextStyle(
                        color: _audience == BroadcastAudience.allStudents
                            ? (isDark ? AppColors.primaryLight : AppColors.saffronDark)
                            : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: _audience == BroadcastAudience.allStudents
                              ? (isDark ? AppColors.primary : AppColors.saffronBorder)
                              : (isDark ? AppColors.darkBorder : AppColors.border),
                        ),
                      ),
                      showCheckmark: false,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ChoiceChip(
                      label: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.checklist_rtl_rounded, size: 16),
                          SizedBox(width: 6),
                          Text("Specific Batch(es)"),
                        ],
                      ),
                      selected: _audience == BroadcastAudience.specificBatches,
                      onSelected: (_) => setState(() => _audience = BroadcastAudience.specificBatches),
                      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                      selectedColor: isDark ? AppColors.primary.withValues(alpha: 0.25) : AppColors.saffronMuted,
                      labelStyle: TextStyle(
                        color: _audience == BroadcastAudience.specificBatches
                            ? (isDark ? AppColors.primaryLight : AppColors.saffronDark)
                            : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: _audience == BroadcastAudience.specificBatches
                              ? (isDark ? AppColors.primary : AppColors.saffronBorder)
                              : (isDark ? AppColors.darkBorder : AppColors.border),
                        ),
                      ),
                      showCheckmark: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Batch Selector if specific batches is chosen
              if (_audience == BroadcastAudience.specificBatches) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Select Target Batches:",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            ),
                          ),
                          if (allBatches.isNotEmpty)
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(50, 24),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                setState(() {
                                  if (_selectedBatchIds.length == allBatches.length) {
                                    _selectedBatchIds.clear();
                                  } else {
                                    _selectedBatchIds.addAll(allBatches.map((b) => b.id));
                                  }
                                });
                              },
                              child: Text(
                                _selectedBatchIds.length == allBatches.length
                                    ? "Clear All"
                                    : "Select All",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.primaryLight : AppColors.saffronDark,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (allBatches.isEmpty)
                        Text(
                          "No batches found in the course catalog.",
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: allBatches.map((b) {
                            final isChecked = _selectedBatchIds.contains(b.id);
                            return FilterChip(
                              label: Text("${b.name} (${b.timing})"),
                              selected: isChecked,
                              onSelected: (val) {
                                setState(() {
                                  if (val) {
                                    _selectedBatchIds.add(b.id);
                                  } else {
                                    _selectedBatchIds.remove(b.id);
                                  }
                                });
                              },
                              backgroundColor: isDark ? AppColors.darkSurface : AppColors.warmIvory,
                              selectedColor: isDark ? AppColors.primary.withValues(alpha: 0.25) : AppColors.saffronMuted,
                              labelStyle: TextStyle(
                                fontSize: 11,
                                fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
                                color: isChecked
                                    ? (isDark ? AppColors.primaryLight : AppColors.saffronDark)
                                    : (isDark ? AppColors.darkTextPrimary : AppColors.deepInk),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                                side: BorderSide(
                                  color: isChecked
                                      ? (isDark ? AppColors.primary : AppColors.saffronBorder)
                                      : (isDark ? AppColors.darkBorder : AppColors.border),
                                ),
                              ),
                              showCheckmark: true,
                              checkmarkColor: isDark ? AppColors.primaryLight : AppColors.saffronDark,
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // CATEGORY CHIPS
              Text(
                "NOTIFICATION CATEGORY",
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  NotificationCategory.announcement,
                  NotificationCategory.liveClass,
                  NotificationCategory.test,
                  NotificationCategory.reminder,
                ].map((cat) {
                  final isSelected = _category == cat;
                  return ChoiceChip(
                    label: Text(cat.name.toUpperCase()),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _category = cat),
                    backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                    selectedColor: isDark ? AppColors.primary.withValues(alpha: 0.25) : AppColors.saffronMuted,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? (isDark ? AppColors.primaryLight : AppColors.saffronDark)
                          : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: BorderSide(
                        color: isSelected
                            ? (isDark ? AppColors.primary : AppColors.saffronBorder)
                            : (isDark ? AppColors.darkBorder : AppColors.border),
                      ),
                    ),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              Text(
                "NOTICE HEADLINE *",
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                style: TextStyle(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                ),
                decoration: InputDecoration(
                  hintText: "e.g. 📢 72nd BPSC Mains Mock Test 3 Schedule Released",
                  hintStyle: TextStyle(
                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface : AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                    ),
                  ),
                ),
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? "Notice headline is required"
                    : null,
              ),
              const SizedBox(height: 16),

              Text(
                "BROADCAST MESSAGE BODY *",
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _messageController,
                maxLines: 5,
                style: TextStyle(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                ),
                decoration: InputDecoration(
                  hintText: "Enter the detailed message, instructions, or center notice to broadcast...",
                  hintStyle: TextStyle(
                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface : AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                    ),
                  ),
                ),
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? "Message body is required"
                    : null,
              ),
              const SizedBox(height: 24),

              ModernButton(
                text: _isSending
                    ? "Broadcasting Notice..."
                    : _audience == BroadcastAudience.allStudents
                        ? "Broadcast Notice to All Students"
                        : "Send Notice to ${_selectedBatchIds.length} Selected Batch(es)",
                width: double.infinity,
                icon: Icons.send_rounded,
                isLoading: _isSending,
                variant: ButtonVariant.primary,
                onPressed: _isSending ? null : _sendBroadcast,
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  "Announcements are immediately delivered to enrolled students' notification feed.",
                  style: AppTypography.caption.copyWith(
                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
