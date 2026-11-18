import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../models/user_model.dart';

/// Reusable Multi-Teacher Selection Widget for Batches & Course Wizard.
class MultiTeacherSelector extends StatelessWidget {
  final List<UserModel> allTeachers;
  final List<String> selectedTeacherIds;
  final ValueChanged<List<String>> onChanged;
  final bool enabled;

  const MultiTeacherSelector({
    super.key,
    required this.allTeachers,
    required this.selectedTeacherIds,
    required this.onChanged,
    this.enabled = true,
  });

  void _showTeacherSelectionModal(BuildContext context) {
    if (!enabled) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tempSelected = List<String>.from(selectedTeacherIds);
    String searchQuery = "";

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setModalState) {
          final mediaQuery = MediaQuery.of(dialogCtx);
          final isLandscape = mediaQuery.orientation == Orientation.landscape;
          final screenHeight = mediaQuery.size.height;
          final maxListHeight = isLandscape
              ? (screenHeight * 0.35).clamp(100.0, 150.0)
              : 260.0;

          final filtered = allTeachers.where((t) {
            if (searchQuery.trim().isEmpty) return true;
            return t.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                t.email.toLowerCase().contains(searchQuery.toLowerCase());
          }).toList();

          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
            insetPadding: EdgeInsets.symmetric(
              horizontal: isLandscape ? 32 : 24,
              vertical: isLandscape ? 12 : 24,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.school, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Assign Faculty Members",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  "${tempSelected.length} selected",
                  style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: "Search faculty by name...",
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onChanged: (val) {
                      setModalState(() => searchQuery = val);
                    },
                  ),
                  const SizedBox(height: 10),
                  if (allTeachers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        "No teacher profiles found in system.",
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      ),
                    )
                  else if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        "No faculty matching search.",
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxListHeight),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (ctx, idx) {
                          final teacher = filtered[idx];
                          final isChecked = tempSelected.contains(teacher.id);

                          return CheckboxListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                            dense: true,
                            value: isChecked,
                            title: Text(
                              teacher.name,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              teacher.email,
                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              overflow: TextOverflow.ellipsis,
                            ),
                            secondary: CircleAvatar(
                              radius: 14,
                              backgroundColor: isChecked ? AppTheme.primary : AppColors.border,
                              child: Text(
                                teacher.name.isNotEmpty ? teacher.name[0].toUpperCase() : 'T',
                                style: TextStyle(
                                  color: isChecked ? Colors.white : AppTheme.textPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            activeColor: AppTheme.primary,
                            onChanged: (bool? val) {
                              setModalState(() {
                                if (val == true) {
                                  if (!tempSelected.contains(teacher.id)) {
                                    tempSelected.add(teacher.id);
                                  }
                                } else {
                                  tempSelected.remove(teacher.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actionsPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: isLandscape ? 6 : 12,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: () {
                  Navigator.pop(dialogCtx);
                  onChanged(tempSelected);
                },
                child: const Text("Apply Selection"),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVeryNarrow = MediaQuery.sizeOf(context).width < 340;
    final selectedTeachers = allTeachers.where((t) => selectedTeacherIds.contains(t.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.people_outline, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Assigned Faculty (${selectedTeacherIds.length})",
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: isVeryNarrow ? 4 : 6, vertical: 2),
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: enabled ? () => _showTeacherSelectionModal(context) : null,
              icon: Icon(Icons.person_add_alt_1, size: isVeryNarrow ? 14 : 15),
              label: Text(
                isVeryNarrow
                    ? (selectedTeacherIds.isEmpty ? "Assign" : "Edit")
                    : (selectedTeacherIds.isEmpty ? "Assign Faculty" : "Edit Faculty"),
                style: TextStyle(fontSize: isVeryNarrow ? 11 : 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (selectedTeachers.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.warmIvory,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppTheme.textMuted),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "No faculty assigned. Tap 'Assign Faculty' to allocate teachers.",
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: selectedTeachers.map((teacher) {
              final screenWidth = MediaQuery.sizeOf(context).width;
              final maxLabelWidth = (screenWidth * 0.38).clamp(60.0, 240.0);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 9,
                      backgroundColor: AppTheme.primary,
                      child: Text(
                        teacher.name.isNotEmpty ? teacher.name[0].toUpperCase() : 'T',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxLabelWidth),
                      child: Text(
                        teacher.name,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (enabled) ...[
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () {
                          final updated = List<String>.from(selectedTeacherIds)..remove(teacher.id);
                          onChanged(updated);
                        },
                        child: const Icon(Icons.cancel, size: 15, color: AppColors.textMuted),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
