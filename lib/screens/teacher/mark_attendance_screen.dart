import '../../features/auth/data/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/modern_button.dart';
import '../../core/widgets/modern_card.dart';
import '../../models/attendance_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/attendance_provider.dart';

class MarkAttendanceScreen extends StatefulWidget {
  const MarkAttendanceScreen({super.key});

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  String? _selectedBatchId;
  final DateTime _selectedDate = DateTime.now();
  final Map<String, AttendanceStatus> _studentStatus = {};
  List<UserModel> _students = [];
  bool _isLoadingRoster = false;
  String? _rosterError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedBatchId != null) {
        _fetchRoster(_selectedBatchId!);
      } else {
        // try to auto-select
        final courseProvider = context.read<CourseProvider>();
        final batches = courseProvider.batches
            .where((b) => courseProvider.myAssignedBatchIds.contains(b.id))
            .toList();
        if (batches.isNotEmpty) {
          setState(() {
            _selectedBatchId = batches.first.id;
          });
          _fetchRoster(batches.first.id);
        }
      }
    });
  }

  Future<void> _fetchRoster(String batchId) async {
    setState(() {
      _isLoadingRoster = true;
      _rosterError = null;
      _students = [];
      _studentStatus.clear();
    });
    try {
      final auth = context.read<AuthProvider>();
      final roster = await auth.getBatchStudents(batchId);
      if (!mounted) return;
      setState(() {
        _students = roster;
        _isLoadingRoster = false;
        for (var s in roster) {
          _studentStatus[s.id] = AttendanceStatus.present;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingRoster = false;
        _rosterError = "Failed to load roster. Please try again.";
      });
    }
  }

  void _markAll(AttendanceStatus status) {
    setState(() {
      _studentStatus.updateAll((key, _) => status);
    });
  }

  void _submitAttendance() {
    final auth = context.read<AuthProvider>();
    final courseProvider = context.read<CourseProvider>();
    final attProvider = context.read<AttendanceProvider>();

    if (_selectedBatchId == null) return;
    final batch = courseProvider.getBatchById(_selectedBatchId!);
    if (batch == null) {
      return;
    }
    final Map<String, String> namesMap = {
      for (var s in _students) s.id: s.name,
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
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final courseProvider = context.watch<CourseProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final batches = courseProvider.batches
        .where((b) => courseProvider.myAssignedBatchIds.contains(b.id))
        .toList();

    if (batches.isEmpty) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: const Text("Batch Attendance Register")),
        body: const Center(
          child: AppEmptyState(
            icon: Icons.school_outlined,
            title: "No Assigned Batches",
            description:
                "You do not have any teaching batches assigned. Contact your center administrator.",
          ),
        ),
      );
    }

    final presentCount = _studentStatus.values
        .where((v) => v == AttendanceStatus.present)
        .length;
    final absentCount = _studentStatus.values
        .where((v) => v == AttendanceStatus.absent)
        .length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Batch Attendance Register"),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDark ? AppColors.darkBorder : AppColors.border,
            height: 1,
          ),
        ),
      ),
      body: Column(
        children: [
          // Batch Selector & Date Header
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _selectedBatchId,
                  dropdownColor: isDark
                      ? AppColors.darkSurface
                      : AppColors.surface,
                  decoration: InputDecoration(
                    labelText: "Select Assigned Batch",
                    labelStyle: AppTypography.caption.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkSurfaceCard
                        : AppColors.warmIvory,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
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
                  items: batches
                      .map(
                        (b) => DropdownMenuItem(
                          value: b.id,
                          child: Text(
                            b.name,
                            style: AppTypography.bodyMedium.copyWith(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.deepInk,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null && val != _selectedBatchId) {
                      setState(() => _selectedBatchId = val);
                      _fetchRoster(val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Text(
                      "Date: ${Formatters.formatDate(_selectedDate)}",
                      style: AppTypography.subtitle2.copyWith(
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.deepInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isDark
                                  ? AppColors.emerald.withValues(alpha: 0.4)
                                  : AppColors.emeraldBorder,
                            ),
                            backgroundColor: isDark
                                ? AppColors.emerald.withValues(alpha: 0.15)
                                : AppColors.emeraldBg,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            minimumSize: const Size(0, 30),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          onPressed: () => _markAll(AttendanceStatus.present),
                          child: Text(
                            "All Present",
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFF86EFAC)
                                  : AppColors.emerald,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isDark
                                  ? AppColors.error.withValues(alpha: 0.4)
                                  : AppColors.errorBorder,
                            ),
                            backgroundColor: isDark
                                ? AppColors.error.withValues(alpha: 0.15)
                                : AppColors.errorBg,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            minimumSize: const Size(0, 30),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          onPressed: () => _markAll(AttendanceStatus.absent),
                          child: Text(
                            "All Absent",
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFFFDA4AF)
                                  : AppColors.error,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Summary Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceCard
                        : AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.borderSubtle,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: AppColors.emerald,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                "Present: $presentCount",
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10.5,
                                  color: isDark
                                      ? const Color(0xFF86EFAC)
                                      : AppColors.emerald,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 14,
                        width: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        color: isDark ? AppColors.darkBorder : AppColors.border,
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                "Absent: $absentCount",
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10.5,
                                  color: isDark
                                      ? const Color(0xFFFDA4AF)
                                      : AppColors.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 14,
                        width: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        color: isDark ? AppColors.darkBorder : AppColors.border,
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                "Total: ${_students.length}",
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10.5,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),

          // Students Roster Checklist
          Expanded(
            child: _isLoadingRoster
                ? const Center(child: CircularProgressIndicator())
                : _rosterError != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _rosterError!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () => _fetchRoster(_selectedBatchId!),
                          child: const Text("Retry"),
                        ),
                      ],
                    ),
                  )
                : _students.isEmpty
                ? const Center(
                    child: AppEmptyState(
                      icon: Icons.people_outline_rounded,
                      title: "No Enrolled Students",
                      description:
                          "There are currently no students registered in this batch.",
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _students.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final student = _students[index];
                      final status =
                          _studentStatus[student.id] ??
                          AttendanceStatus.present;
                      final isPresent = status == AttendanceStatus.present;

                      return ModernCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        backgroundColor: isDark
                            ? AppColors.darkSurfaceCard
                            : AppColors.surface,
                        accentSpineColor: isPresent
                            ? AppColors.emerald
                            : AppColors.error,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 17,
                              backgroundColor: isDark
                                  ? AppColors.darkSurface
                                  : AppColors.surfaceMuted,
                              child: Text(
                                student.name.isNotEmpty
                                    ? student.name.substring(0, 1).toUpperCase()
                                    : '?',
                                style: AppTypography.subtitle2.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.deepInk,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    student.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.subtitle2.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.deepInk,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    student.phone.isNotEmpty
                                        ? "📱 ${student.phone}"
                                        : student.email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.caption.copyWith(
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Status Toggle Pill
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _studentStatus[student.id] =
                                          AttendanceStatus.present;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isPresent
                                          ? AppColors.emerald
                                          : (isDark
                                                ? AppColors.darkSurface
                                                : AppColors.surfaceMuted),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isPresent
                                            ? AppColors.emerald
                                            : (isDark
                                                  ? AppColors.darkBorder
                                                  : AppColors.border),
                                      ),
                                    ),
                                    child: Text(
                                      "Present",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10.5,
                                        color: isPresent
                                            ? Colors.white
                                            : (isDark
                                                  ? AppColors.darkTextSecondary
                                                  : AppColors.textSecondary),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _studentStatus[student.id] =
                                          AttendanceStatus.absent;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: !isPresent
                                          ? AppColors.error
                                          : (isDark
                                                ? AppColors.darkSurface
                                                : AppColors.surfaceMuted),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: !isPresent
                                            ? AppColors.error
                                            : (isDark
                                                  ? AppColors.darkBorder
                                                  : AppColors.border),
                                      ),
                                    ),
                                    child: Text(
                                      "Absent",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10.5,
                                        color: !isPresent
                                            ? Colors.white
                                            : (isDark
                                                  ? AppColors.darkTextSecondary
                                                  : AppColors.textSecondary),
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
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.surface,
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
              ),
            ),
            child: SafeArea(
              child: ModernButton(
                text: "Save & Record Attendance",
                width: double.infinity,
                icon: Icons.check_circle_outline,
                variant: ButtonVariant.primary,
                onPressed: _submitAttendance,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
