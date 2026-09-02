import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../data/mock_data.dart';

class ManageStudentsScreen extends StatefulWidget {
  const ManageStudentsScreen({super.key});

  @override
  State<ManageStudentsScreen> createState() => _ManageStudentsScreenState();
}

class _ManageStudentsScreenState extends State<ManageStudentsScreen> {
  String _search = "";

  @override
  Widget build(BuildContext context) {
    final students = MockData.allStudents.where((s) {
      return s.name.toLowerCase().contains(_search.toLowerCase()) ||
          s.phone.contains(_search) ||
          s.email.toLowerCase().contains(_search.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Student Management & Roster"),
      ),
      body: Column(
        children: [
          // Search Bar Header
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.surface,
            child: TextField(
              onChanged: (val) => setState(() => _search = val),
              decoration: InputDecoration(
                hintText: "Search by Student Name, Phone, Email...",
                prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textMuted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                isDense: true,
              ),
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),

          // Total Count Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppTheme.surfaceLight,
            child: Row(
              children: [
                Text(
                  "Enrolled Students Directory (${students.length})",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                const Text(
                  "Target: 100k Capacity",
                  style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          // Student List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: students.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final student = students[index];

                return ModernCard(
                  padding: const EdgeInsets.all(14),
                  backgroundColor: AppTheme.surface,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppTheme.primary,
                        child: Text(
                          student.name.substring(0, 1),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.name,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "📱 ${student.phone} • ${student.email}",
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                CustomBadge(
                                  text: "${student.enrolledCourseIds.length} Courses Enrolled",
                                  variant: BadgeVariant.primary,
                                  fontSize: 10,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "Joined ${Formatters.formatDate(student.joinedDate ?? DateTime.now())}",
                                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_note, color: AppTheme.primary),
                        tooltip: "Batch Allocation",
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Editing batch allocation for ${student.name}")),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
