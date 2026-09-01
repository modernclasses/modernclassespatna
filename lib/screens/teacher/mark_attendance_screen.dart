import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_button.dart';
import '../../core/widgets/modern_card.dart';
import '../../models/attendance_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../data/mock_data.dart';

class MarkAttendanceScreen extends StatefulWidget {
  const MarkAttendanceScreen({super.key});

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  String? _selectedBatchId;
  final Map<String, AttendanceStatus> _studentStatus = {};
  final DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final allStudents = MockData.allStudents;
    for (var s in allStudents) {
      _studentStatus[s.id] = AttendanceStatus.present;
    }
  }

  void _markAll(AttendanceStatus status) {
    setState(() {
      _studentStatus.updateAll((key, value) => status);
    });
  }

  void _submitAttendance() {
    final auth = context.read<AuthProvider>();
    final courseProvider = context.read<CourseProvider>();
    final attProvider = context.read<AttendanceProvider>();

    final batch = courseProvider.getBatchById(_selectedBatchId ?? courseProvider.batches.first.id)!;
    final Map<String, String> namesMap = {
      for (var s in MockData.allStudents) s.id: s.name,
    };

    attProvider.markBatchAttendance(
      batchId: batch.id,
      batchName: batch.name,
      studentStatusMap: _studentStatus,
      studentNames: namesMap,
      teacherName: auth.currentUser.name,
      date: _selectedDate,
    );

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("✅ Attendance for ${batch.name} successfully recorded!"),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final courseProvider = context.watch<CourseProvider>();
    final batches = courseProvider.batches;
    final students = MockData.allStudents;

    _selectedBatchId ??= batches.isNotEmpty ? batches.first.id : null;

    final presentCount = _studentStatus.values.where((s) => s == AttendanceStatus.present).length;
    final absentCount = _studentStatus.values.where((s) => s == AttendanceStatus.absent).length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Batch Attendance Register"),
      ),
      body: Column(
        children: [
          // Batch Selector & Date Header
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedBatchId,
                  dropdownColor: AppTheme.surfaceLight,
                  decoration: const InputDecoration(
                    labelText: "Select Batch",
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  items: batches
                      .map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedBatchId = val),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Date: ${Formatters.formatDate(_selectedDate)}",
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: const Size(0, 30),
                          ),
                          onPressed: () => _markAll(AttendanceStatus.present),
                          child: const Text("All Present", style: TextStyle(fontSize: 11)),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: const Size(0, 30),
                          ),
                          onPressed: () => _markAll(AttendanceStatus.absent),
                          child: const Text("All Absent", style: TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    CustomBadge(text: "Present: $presentCount", variant: BadgeVariant.success),
                    const SizedBox(width: 8),
                    CustomBadge(text: "Absent: $absentCount", variant: BadgeVariant.error),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),

          // Students Roster Checklist
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: students.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final student = students[index];
                final status = _studentStatus[student.id] ?? AttendanceStatus.present;

                return ModernCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  backgroundColor: AppTheme.surface,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppTheme.surfaceElevated,
                        child: Text(
                          student.name.substring(0, 1),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.name,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "Roll: ${student.id.toUpperCase()} • 📱 ${student.phone}",
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      // Status Segmented Selector
                      Row(
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                _studentStatus[student.id] = AttendanceStatus.present;
                              });
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: status == AttendanceStatus.present
                                    ? AppTheme.success
                                    : AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "P",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: status == AttendanceStatus.present ? Colors.white : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _studentStatus[student.id] = AttendanceStatus.absent;
                              });
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: status == AttendanceStatus.absent
                                    ? AppTheme.error
                                    : AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "A",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: status == AttendanceStatus.absent ? Colors.white : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Bottom Submit Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: SafeArea(
              child: ModernButton(
                text: "Save & Record Attendance",
                width: double.infinity,
                icon: Icons.check_circle_outline,
                onPressed: _submitAttendance,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
