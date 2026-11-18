import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../features/auth/logic/auth_provider.dart';
import '../../features/auth/data/models/user_model.dart';
import '../../features/courses/data/models/course_model.dart';
import '../../features/courses/data/models/batch_model.dart';
import '../../features/courses/logic/course_provider.dart';

class ManageStudentsScreen extends StatefulWidget {
  const ManageStudentsScreen({super.key});

  @override
  State<ManageStudentsScreen> createState() => _ManageStudentsScreenState();
}

class _ManageStudentsScreenState extends State<ManageStudentsScreen> {
  String _search = "";
  List<UserModel> _allStudents = [];
  Map<String, List<String>> _studentEnrolledBatches = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    try {
      final auth = context.read<AuthProvider>();
      final courseProvider = context.read<CourseProvider>();
      final allBatches = courseProvider.batches;
      final allCourses = courseProvider.courses;

      final students = await auth.getAllStudents();
      if (!mounted) return;

      final Map<String, List<String>> batchMap = {};
      final client = _supabase;
      if (client != null) {
        try {
          final res = await client
              .from('enrollments')
              .select('student_id, batch_id')
              .eq('status', 'active');
          for (final row in res as List) {
            final sId = row['student_id']?.toString() ?? '';
            final bId = row['batch_id']?.toString() ?? '';
            if (sId.isNotEmpty && bId.isNotEmpty) {
              final isValid = allBatches.any((b) => b.id == bId && allCourses.any((c) => c.id == b.courseId));
              if (isValid || allBatches.isEmpty) {
                batchMap.putIfAbsent(sId, () => []).add(bId);
              } else {
                // Orphaned record from previously deleted batch/course - auto cleanup
                client.from('enrollments').delete().eq('student_id', sId).eq('batch_id', bId).then((_) {}).catchError((_) {});
              }
            }
          }
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _allStudents = students;
        _studentEnrolledBatches = batchMap;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to load students: $e"),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _deleteStudentAccount(String studentId) async {
    final client = _supabase;
    if (client == null) return;
    try {
      // 1. Prefer atomic administrative RPC that also purges auth.users
      await client.rpc('delete_student_account', params: {'p_student_id': studentId});
    } catch (_) {
      // 2. Client fallback: delete dependent records before deleting profile
      try {
        await client.from('enrollments').delete().eq('student_id', studentId);
      } catch (_) {}
      try {
        await client.from('purchases').delete().eq('student_id', studentId);
      } catch (_) {}
      try {
        await client.from('doubts').delete().eq('student_id', studentId);
      } catch (_) {}
      try {
        await client.from('test_submissions').delete().eq('student_id', studentId);
      } catch (_) {}
      try {
        await client.from('attendance').delete().eq('student_id', studentId);
      } catch (_) {}
      try {
        await client.from('transactions').delete().eq('student_id', studentId);
      } catch (_) {}
      try {
        await client.from('user_device_tokens').delete().eq('user_id', studentId);
      } catch (_) {}
      await client.from('profiles').delete().eq('id', studentId);
    }
  }

  void _cleanupOrphanedEnrollments(String studentId, List<String> orphanBatchIds) {
    final client = _supabase;
    if (client == null || orphanBatchIds.isEmpty) return;
    for (final bId in orphanBatchIds) {
      client
          .from('enrollments')
          .delete()
          .eq('student_id', studentId)
          .eq('batch_id', bId)
          .then((_) {})
          .catchError((_) {});
    }
  }

  SupabaseClient? get _supabase {
    if (!AppConfig.isSupabaseConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> _fetchStudentEnrolledBatchIds(String studentId) async {
    final client = _supabase;
    if (client == null) return [];
    try {
      final res = await client
          .from('enrollments')
          .select('batch_id')
          .eq('student_id', studentId)
          .eq('status', 'active');
      final list = res as List;
      return list
          .map((r) => r['batch_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _enrollStudentInBatch(String studentId, String batchId) async {
    final client = _supabase;
    if (client != null) {
      await client.from('enrollments').upsert({
        'student_id': studentId,
        'batch_id': batchId,
        'status': 'active',
      }, onConflict: 'student_id,batch_id');
    }
  }

  Future<void> _unenrollStudentFromBatch(String studentId, String batchId) async {
    final client = _supabase;
    if (client != null) {
      await client
          .from('enrollments')
          .delete()
          .eq('student_id', studentId)
          .eq('batch_id', batchId);
    }
  }

  Future<void> _updateStudentProfile({
    required String studentId,
    required String name,
    required String targetExam,
    required String medium,
    required bool isActive,
  }) async {
    final client = _supabase;
    if (client != null) {
      await client.from('profiles').update({
        'full_name': name,
        'target_exam': targetExam,
        'medium': medium,
        'is_active': isActive,
      }).eq('id', studentId);
    } else {
      // Fallback via AuthProvider
      await context.read<AuthProvider>().adminUpdateStudentProfile(studentId, name);
    }
  }

  void _showEditStudentDialog(BuildContext context, UserModel student) {
    final nameCtrl = TextEditingController(text: student.name);
    bool isActive = student.isActive;

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
              ),
              title: Text(
                "Edit Student Profile",
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                ),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: "Full Name *",
                          filled: true,
                          fillColor: isDark ? AppColors.darkSurface : AppColors.warmIvory,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                          ),
                        ),
                        maxLength: 30,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return "Name required";
                          }
                          return null;
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Student Account Status",
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "Active accounts can log in and view classes",
                                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch.adaptive(
                            value: isActive,
                            activeTrackColor: AppColors.emerald,
                            onChanged: (val) => setStateDialog(() => isActive = val),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Divider(color: isDark ? AppColors.darkBorder : AppColors.border),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          minimumSize: const Size.fromHeight(40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text(
                          "Delete Student Account",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final confirm = await showDialog<bool>(
                                  context: ctx,
                                  builder: (confirmCtx) {
                                    final confirmCtrl = TextEditingController();
                                    bool canDelete = false;
                                    return StatefulBuilder(
                                      builder: (dialogCtx, setDialogState) {
                                        return AlertDialog(
                                          backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                                          title: const Row(
                                            children: [
                                              Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
                                              SizedBox(width: 8),
                                              Expanded(child: Text("Delete Student Account?")),
                                            ],
                                          ),
                                          content: SingleChildScrollView(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  "Are you sure you want to permanently delete this student account (${student.email})?",
                                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                                ),
                                                const SizedBox(height: 10),
                                                const Text(
                                                  "Warning: This will permanently delete the student's profile, enrollment records, test attempts, and access privileges. This action cannot be undone.",
                                                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                                ),
                                                const SizedBox(height: 16),
                                                Text(
                                                  "Type CONFIRM to proceed with deletion:",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                TextField(
                                                  controller: confirmCtrl,
                                                  textCapitalization: TextCapitalization.characters,
                                                  decoration: InputDecoration(
                                                    hintText: "CONFIRM",
                                                    isDense: true,
                                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                                    focusedBorder: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                      borderSide: const BorderSide(color: AppColors.error, width: 2),
                                                    ),
                                                  ),
                                                  onChanged: (val) {
                                                    setDialogState(() {
                                                      canDelete = val.trim() == "CONFIRM";
                                                    });
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                          actionsOverflowAlignment: OverflowBarAlignment.end,
                                          actionsOverflowButtonSpacing: 8,
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(confirmCtx, false),
                                              child: const Text("Cancel"),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.error,
                                                foregroundColor: Colors.white,
                                                disabledBackgroundColor: AppColors.error.withValues(alpha: 0.3),
                                                disabledForegroundColor: Colors.white70,
                                              ),
                                              onPressed: canDelete ? () => Navigator.pop(confirmCtx, true) : null,
                                              child: const Text("Delete Permanently"),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                );
                                if (confirm == true) {
                                  setStateDialog(() => isSubmitting = true);
                                  try {
                                    await _deleteStudentAccount(student.id);
                                    if (!ctx.mounted) return;
                                    Navigator.pop(ctx);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Student account deleted successfully"),
                                        backgroundColor: AppColors.emerald,
                                      ),
                                    );
                                    _loadStudents();
                                  } catch (e) {
                                    setStateDialog(() => isSubmitting = false);
                                    if (!ctx.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("Failed to delete account: $e"),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                  }
                                }
                              },
                      ),
                    ],
                  ),
                ),
              ),
              actionsOverflowAlignment: OverflowBarAlignment.end,
              actionsOverflowButtonSpacing: 8,
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  child: Text(
                    "Cancel",
                    style: AppTypography.button.copyWith(color: AppColors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepInk,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setStateDialog(() => isSubmitting = true);
                          try {
                            await _updateStudentProfile(
                              studentId: student.id,
                              name: nameCtrl.text.trim(),
                              targetExam: student.targetExam,
                              medium: student.medium,
                              isActive: isActive,
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Student profile updated successfully"),
                                backgroundColor: AppColors.emerald,
                              ),
                            );
                            _loadStudents();
                          } catch (e) {
                            setStateDialog(() => isSubmitting = false);
                            if (!ctx.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Failed to update profile: $e"),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text("Save Changes"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showBatchManagementDialog(BuildContext context, UserModel student) async {
    final courseProvider = context.read<CourseProvider>();
    final allBatches = courseProvider.batches;
    final allCourses = courseProvider.courses;

    List<String> enrolledBatchIds = [];
    bool isFetching = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        String? selectedBatchToAdd;
        bool isProcessing = false;

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            if (isFetching) {
              _fetchStudentEnrolledBatchIds(student.id).then((ids) {
                if (dialogCtx.mounted) {
                  // Find any orphan IDs whose batch or parent course no longer exists
                  final orphanIds = ids.where((id) {
                    final batch = allBatches.cast<BatchModel?>().firstWhere((b) => b?.id == id, orElse: () => null);
                    if (batch == null) return true;
                    return !allCourses.any((c) => c.id == batch.courseId);
                  }).toList();
                  if (orphanIds.isNotEmpty) {
                    _cleanupOrphanedEnrollments(student.id, orphanIds);
                  }
                  final validIds = ids.where((id) => !orphanIds.contains(id)).toList();
                  setDialogState(() {
                    enrolledBatchIds = validIds;
                    isFetching = false;
                  });
                }
              });
            }

            final validBatches = allBatches.where((b) => allCourses.any((c) => c.id == b.courseId)).toList();
            final enrolledBatches = validBatches.where((b) => enrolledBatchIds.contains(b.id)).toList();
            final availableToEnroll = validBatches.where((b) => !enrolledBatchIds.contains(b.id)).toList();

            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
              ),
              title: Row(
                children: [
                  Icon(Icons.school_outlined, color: isDark ? AppColors.primaryLight : AppColors.saffronDark, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Manage Batches: ${student.name}",
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: isFetching
                    ? const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(
                          child: CircularProgressIndicator(color: AppColors.saffronDark),
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Enrolled Batches (${enrolledBatches.length})",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            if (enrolledBatches.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  "Student is not assigned to any batch yet.",
                                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                ),
                              )
                            else
                              ...enrolledBatches.map((b) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.warmIvory,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              b.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                            Text(
                                              "${b.timing} • ${b.medium}",
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      TextButton.icon(
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppColors.error,
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          minimumSize: const Size(0, 30),
                                        ),
                                        icon: const Icon(Icons.close_rounded, size: 14),
                                        label: const Text("Remove", style: TextStyle(fontSize: 11)),
                                        onPressed: isProcessing
                                            ? null
                                            : () async {
                                                setDialogState(() => isProcessing = true);
                                                try {
                                                  await _unenrollStudentFromBatch(student.id, b.id);
                                                  setDialogState(() {
                                                    enrolledBatchIds.remove(b.id);
                                                    isProcessing = false;
                                                  });
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text("Unenrolled from ${b.name}"),
                                                        backgroundColor: AppColors.deepInk,
                                                        duration: const Duration(seconds: 2),
                                                      ),
                                                    );
                                                  }
                                                } catch (e) {
                                                  setDialogState(() => isProcessing = false);
                                                }
                                              },
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            const SizedBox(height: 18),
                            const Divider(color: AppColors.border),
                            const SizedBox(height: 10),
                            const Text(
                              "Assign to New Batch",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            if (availableToEnroll.isEmpty)
                              const Text(
                                "Student is already enrolled in all available batches.",
                                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                              )
                            else ...[
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: selectedBatchToAdd,
                                hint: const Text("Select target batch...", style: TextStyle(fontSize: 12)),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: AppColors.warmIvory,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                items: availableToEnroll.map((b) {
                                  return DropdownMenuItem(
                                    value: b.id,
                                    child: Text("${b.name} (${b.timing})", overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setDialogState(() => selectedBatchToAdd = val);
                                },
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.saffronDark,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 38),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                icon: isProcessing
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.add_circle_outline, size: 16),
                                label: const Text("Assign to Selected Batch"),
                                onPressed: (isProcessing || selectedBatchToAdd == null)
                                    ? null
                                    : () async {
                                        setDialogState(() => isProcessing = true);
                                        try {
                                          await _enrollStudentInBatch(student.id, selectedBatchToAdd!);
                                          final addedId = selectedBatchToAdd!;
                                          setDialogState(() {
                                            enrolledBatchIds.add(addedId);
                                            selectedBatchToAdd = null;
                                            isProcessing = false;
                                          });
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text("Student enrolled in batch successfully!"),
                                                backgroundColor: AppColors.emerald,
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          setDialogState(() => isProcessing = false);
                                        }
                                      },
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Done"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    final students = _allStudents.where((s) {
      return s.name.toLowerCase().contains(_search.toLowerCase()) ||
          s.phone.contains(_search) ||
          s.email.toLowerCase().contains(_search.toLowerCase()) ||
          s.targetExam.toLowerCase().contains(_search.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Student Roster & Directory"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: isDark ? AppColors.darkBorder : AppColors.border,
            height: 1,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.saffronDark),
            )
          : Column(
              children: [
                if (isLandscape)
                  // Compact Landscape Toolbar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: isDark ? AppColors.darkSurface : AppColors.surface,
                    child: Row(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Students (${students.length})",
                              style: AppTypography.subtitle2.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.saffronMuted,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "${students.where((s) => s.isActive).length} Active",
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.saffronDark,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SizedBox(
                            height: 36,
                            child: TextField(
                              onChanged: (val) => setState(() => _search = val),
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                              ),
                              decoration: InputDecoration(
                                hintText: "Search student name, phone, email, exam...",
                                hintStyle: AppTypography.bodySmall.copyWith(
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                ),
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  size: 18,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                filled: true,
                                fillColor: isDark ? AppColors.darkSurfaceCard : AppColors.warmIvory,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                                ),
                                isDense: true,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  // Portrait Search Bar Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: isDark ? AppColors.darkSurface : AppColors.surface,
                    child: TextField(
                      onChanged: (val) => setState(() => _search = val),
                      style: TextStyle(
                        color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                      ),
                      decoration: InputDecoration(
                        hintText: "Search by Student Name, Phone, Email, Target Exam...",
                        hintStyle: AppTypography.bodySmall.copyWith(
                          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: isDark ? AppColors.darkSurfaceCard : AppColors.warmIvory,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  Container(
                    height: 1,
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),

                  // Total Count Bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    color: isDark ? AppColors.darkSurface : AppColors.surfaceMuted,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Enrolled Students Directory (${students.length})",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.subtitle2.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "${students.where((s) => s.isActive).length} Active",
                          style: AppTypography.caption.copyWith(
                            color: AppColors.saffronDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Container(
                  height: 1,
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),

                // Student List
                Expanded(
                  child: students.isEmpty
                      ? const Center(
                          child: AppEmptyState(
                            icon: Icons.people_outline_rounded,
                            title: "No Students Found",
                            description: "No registered students match your current search query.",
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: students.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final student = students[index];

                            final isDarkCard = Theme.of(context).brightness == Brightness.dark;
                            return ModernCard(
                              padding: const EdgeInsets.all(14),
                              backgroundColor: isDarkCard ? AppColors.darkSurfaceCard : AppColors.surface,
                              accentSpineColor: student.isActive ? AppColors.saffron : AppColors.error,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: isDarkCard
                                            ? AppColors.primary.withValues(alpha: 0.2)
                                            : AppColors.saffronMuted,
                                        child: Text(
                                          student.name.isNotEmpty
                                              ? student.name.substring(0, 1).toUpperCase()
                                              : '?',
                                          style: AppTypography.titleMedium.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: isDarkCard ? AppColors.primaryLight : AppColors.saffronDark,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    student.name.isNotEmpty ? student.name : 'Unknown Aspirant',
                                                    style: AppTypography.subtitle1.copyWith(
                                                      fontWeight: FontWeight.w700,
                                                      color: isDarkCard ? AppColors.darkTextPrimary : AppColors.deepInk,
                                                    ),
                                                  ),
                                                ),
                                                CustomBadge(
                                                  text: student.isActive ? "Active" : "Suspended",
                                                  variant: student.isActive ? BadgeVariant.success : BadgeVariant.error,
                                                  fontSize: 9.5,
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              "📱 ${student.phone.isNotEmpty ? student.phone : 'No Phone'} • ✉️ ${student.email}",
                                              style: AppTypography.caption.copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              children: [
                                                if (student.targetExam.isNotEmpty && student.targetExam != "BPSC 71st Civil Services")
                                                  CustomBadge(
                                                    text: "🎯 ${student.targetExam}",
                                                    variant: BadgeVariant.primary,
                                                    fontSize: 9.5,
                                                  ),
                                                if (student.medium.isNotEmpty && student.medium != "Bilingual (Hindi + English)")
                                                  CustomBadge(
                                                    text: "🗣️ ${student.medium}",
                                                    variant: BadgeVariant.outline,
                                                    fontSize: 9.5,
                                                  ),
                                                Text(
                                                  "Joined ${Formatters.formatDate(student.joinedDate ?? DateTime.now())}",
                                                  style: AppTypography.caption.copyWith(
                                                    fontSize: 10,
                                                    color: AppColors.textMuted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Builder(
                                    builder: (context) {
                                      final enrolledBatchIds = _studentEnrolledBatches[student.id] ?? [];
                                      final courseProvider = context.watch<CourseProvider>();
                                      final allBatches = courseProvider.batches;
                                      final allCourses = courseProvider.courses;

                                      final List<String> batchDetails = [];
                                      final List<String> orphanedIds = [];
                                      for (final bId in enrolledBatchIds) {
                                        final batch = allBatches.cast<BatchModel?>().firstWhere(
                                          (b) => b?.id == bId,
                                          orElse: () => null,
                                        );
                                        if (batch != null) {
                                          final course = allCourses.cast<CourseModel?>().firstWhere(
                                            (c) => c?.id == batch.courseId,
                                            orElse: () => null,
                                          );
                                          if (course != null) {
                                            batchDetails.add("${course.title} • ${batch.name} (${batch.timing})");
                                          } else {
                                            orphanedIds.add(bId);
                                          }
                                        } else {
                                          orphanedIds.add(bId);
                                        }
                                      }

                                      if (orphanedIds.isNotEmpty) {
                                        _cleanupOrphanedEnrollments(student.id, orphanedIds);
                                      }

                                      if (batchDetails.isNotEmpty) {
                                        return Container(
                                          width: double.infinity,
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: isDarkCard ? AppColors.darkSurface : AppColors.warmIvory,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isDarkCard ? AppColors.darkBorder : AppColors.border,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(Icons.school, size: 14, color: isDarkCard ? AppColors.primaryLight : AppColors.saffronDark),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    "Enrolled Batches (${batchDetails.length}):",
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: isDarkCard ? AppColors.darkTextPrimary : AppColors.deepInk,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              ...batchDetails.map(
                                                (info) => Padding(
                                                  padding: const EdgeInsets.only(top: 2, left: 4),
                                                  child: Text(
                                                    "• $info",
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: isDarkCard ? AppColors.primaryLight : AppColors.saffronDark,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }

                                      return Container(
                                        width: double.infinity,
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isDarkCard
                                              ? AppColors.darkSurface.withValues(alpha: 0.5)
                                              : AppColors.surfaceMuted,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.info_outline, size: 13, color: AppColors.textMuted),
                                            const SizedBox(width: 6),
                                            const Expanded(
                                              child: Text(
                                                "No course enrollments (Unenrolled / Account not in use)",
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.textMuted,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 4),
                                  Divider(height: 1, color: isDarkCard ? AppColors.darkBorder : AppColors.border),
                                  const SizedBox(height: 8),
                                  // Action Buttons
                                  Wrap(
                                    alignment: WrapAlignment.end,
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: isDarkCard ? AppColors.darkTextPrimary : AppColors.deepInk,
                                          side: BorderSide(color: isDarkCard ? AppColors.darkBorder : AppColors.border),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          minimumSize: const Size(0, 32),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        ),
                                        icon: Icon(
                                          Icons.school_outlined,
                                          size: 15,
                                          color: isDarkCard ? AppColors.primaryLight : AppColors.saffronDark,
                                        ),
                                        label: const Text("Manage Batches", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                        onPressed: () => _showBatchManagementDialog(context, student),
                                      ),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isDarkCard ? AppColors.primary : AppColors.deepInk,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          minimumSize: const Size(0, 32),
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        ),
                                        icon: const Icon(Icons.edit_note_rounded, size: 15),
                                        label: const Text("Edit Profile", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                        onPressed: () => _showEditStudentDialog(context, student),
                                      ),
                                    ],
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
