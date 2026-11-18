// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../features/courses/data/models/batch_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';

class ManageTeachersScreen extends StatefulWidget {
  const ManageTeachersScreen({super.key});

  @override
  State<ManageTeachersScreen> createState() => _ManageTeachersScreenState();
}

class _ManageTeachersScreenState extends State<ManageTeachersScreen> {
  List<UserModel> _teachers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final users = await authProvider.getAllProfiles();

      if (!mounted) return;
      setState(() {
        _teachers = users.where((u) => u.role == UserRole.teacher).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showCreateTeacherDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool isCreating = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
            ),
            title: Text(
              'Appoint New Faculty',
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
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Faculty Full Name',
                        hintText: 'e.g. Dr. Rajesh Kumar',
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
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      decoration: InputDecoration(
                        labelText: 'Official Email Address',
                        hintText: 'teacher@modernclasses.in',
                        helperText: 'Must be a full email (e.g. faculty@gmail.com or faculty@modernclasses.in)',
                        helperMaxLines: 2,
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
                      keyboardType: TextInputType.emailAddress,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Email is required';
                        }
                        final email = val.trim();
                        if (!email.contains('@')) {
                          return 'Missing "@" symbol. Enter e.g. $email@gmail.com';
                        }
                        final parts = email.split('@');
                        if (parts.length != 2 || parts[0].isEmpty || !parts[1].contains('.') || parts[1].split('.').last.length < 2) {
                          return 'Invalid domain ("$email" is missing .com or .in). Enter e.g. ${parts[0]}@gmail.com';
                        }
                        final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                        if (!emailRegex.hasMatch(email)) {
                          return 'Enter a valid email with domain (e.g. name@gmail.com)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('Auto-complete:', style: AppTypography.caption.copyWith(color: AppColors.textMuted, fontSize: 11)),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            final current = emailCtrl.text.trim();
                            if (current.isEmpty) {
                              emailCtrl.text = 'faculty@modernclasses.in';
                            } else if (!current.contains('@')) {
                              emailCtrl.text = '$current@modernclasses.in';
                            } else {
                              final prefix = current.split('@').first;
                              emailCtrl.text = '$prefix@modernclasses.in';
                            }
                            emailCtrl.selection = TextSelection.fromPosition(TextPosition(offset: emailCtrl.text.length));
                            setDialogState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                            ),
                            child: Text('@modernclasses.in', style: AppTypography.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 11)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            final current = emailCtrl.text.trim();
                            if (current.isEmpty) {
                              emailCtrl.text = 'faculty@gmail.com';
                            } else if (!current.contains('@')) {
                              emailCtrl.text = '$current@gmail.com';
                            } else {
                              final prefix = current.split('@').first;
                              emailCtrl.text = '$prefix@gmail.com';
                            }
                            emailCtrl.selection = TextSelection.fromPosition(TextPosition(offset: emailCtrl.text.length));
                            setDialogState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                            ),
                            child: Text('@gmail.com', style: AppTypography.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 11)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passCtrl,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Minimum 6 characters',
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
                      obscureText: true,
                      validator: (val) =>
                          val == null || val.length < 6 ? 'Min 6 chars' : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isCreating ? null : () => Navigator.pop(ctx),
                child: Text(
                  'Cancel',
                  style: AppTypography.button.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: isCreating
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isCreating = true);
                        try {
                          await context.read<AuthProvider>().adminCreateTeacher(
                            email: emailCtrl.text.trim().toLowerCase(),
                            password: passCtrl.text.trim(),
                            fullName: nameCtrl.text.trim(),
                          );
                          if (!mounted) return;
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Teacher account created successfully!',
                              ),
                              backgroundColor: AppColors.emerald,
                            ),
                          );
                          _loadTeachers();
                        } catch (e) {
                          setDialogState(() => isCreating = false);
                          String cleanMsg = e
                              .toString()
                              .replaceAll('Exception:', '')
                              .replaceAll('ServerException:', '')
                              .trim();
                          if (cleanMsg.toLowerCase().contains('socket') ||
                              cleanMsg.toLowerCase().contains('broken pipe') ||
                              cleanMsg.toLowerCase().contains('connection reset') ||
                              cleanMsg.toLowerCase().contains('network') ||
                              cleanMsg.toLowerCase().contains('clientexception')) {
                            cleanMsg = 'Network transfer interrupted. Please verify your internet connection and try again.';
                          } else if (cleanMsg.toLowerCase().contains('invalid format') ||
                              cleanMsg.toLowerCase().contains('email')) {
                            cleanMsg = 'Invalid email address. Please enter a full email ending in .com or .in (e.g. anshu@gmail.com or anshu@modernclasses.in).';
                          } else if (cleanMsg.toLowerCase().contains('already')) {
                            cleanMsg = 'A user with this email address is already registered.';
                          } else if (cleanMsg.toLowerCase().contains('forbidden') ||
                              cleanMsg.toLowerCase().contains('admin')) {
                            cleanMsg = 'Administrator privileges required. Please sign out and sign back in to refresh admin credentials.';
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(cleanMsg),
                              backgroundColor: AppColors.error,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepInk,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: isCreating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create Account'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAssignBatchesSheet(UserModel teacher) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _AssignBatchesSheet(teacher: teacher),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text("Faculty & Teacher Roster"),
          backgroundColor: AppColors.surface,
          elevation: 0,
        ),
        body: const Center(child: AppLoadingIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text("Faculty & Teacher Roster"),
          backgroundColor: AppColors.surface,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Failed to load teachers.",
                style: AppTypography.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadTeachers,
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Faculty & Teacher Roster"),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkBorder
                : AppColors.border,
            height: 1,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadTeachers,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Faculty Appointments (${_teachers.length})",
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepInk,
                  ),
                ),
                CustomBadge(
                  text: "${_teachers.length} Active Instructors",
                  variant: BadgeVariant.primary,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_teachers.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40.0),
                child: AppEmptyState(
                  icon: Icons.school_outlined,
                  title: "No Faculty Appointed",
                  description:
                      "Appoint your first teacher using the button below to assign courses and live batches.",
                ),
              )
            else
              ..._teachers.map((teacher) => _buildUserCard(teacher)),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTeacherDialog,
        backgroundColor: AppColors.saffron,
        foregroundColor: AppColors.deepInk,
        icon: const Icon(Icons.person_add_rounded, size: 20),
        label: Text(
          'Appoint Faculty',
          style: AppTypography.button.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildUserCard(UserModel user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ModernCard(
        padding: const EdgeInsets.all(16),
        backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
        accentSpineColor: AppColors.secondary,
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: isDark
                  ? AppColors.secondary.withValues(alpha: 0.25)
                  : AppColors.secondaryMuted,
              child: Text(
                user.name.isNotEmpty
                    ? user.name.substring(0, 1).toUpperCase()
                    : 'T',
                style: AppTypography.titleMedium.copyWith(
                  color: isDark ? AppColors.secondaryLight : AppColors.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: AppTypography.subtitle1.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    style: AppTypography.caption.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: () => _showAssignBatchesSheet(user),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                minimumSize: const Size(0, 34),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                "Batches",
                style: AppTypography.button.copyWith(
                  color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignBatchesSheet extends StatefulWidget {
  final UserModel teacher;
  const _AssignBatchesSheet({required this.teacher});

  @override
  State<_AssignBatchesSheet> createState() => _AssignBatchesSheetState();
}

class _AssignBatchesSheetState extends State<_AssignBatchesSheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _assignments = [];
  List<BatchModel> _adminBatches = [];

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  Future<void> _loadAssignments() async {
    setState(() => _isLoading = true);
    try {
      final res = await context.read<CourseProvider>().getTeacherAssignments(
        widget.teacher.id,
      );
      final batches = await context.read<CourseProvider>().adminGetAllBatches();
      if (mounted) {
        setState(() {
          _assignments = res;
          _adminBatches = batches;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleAssignment(BatchModel batch, bool isAssigned) async {
    try {
      if (isAssigned) {
        await context.read<CourseProvider>().assignTeacherToBatch(
          widget.teacher.id,
          batch.id,
        );
      } else {
        await context.read<CourseProvider>().removeTeacherFromBatch(
          widget.teacher.id,
          batch.id,
        );
      }
      _loadAssignments();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error updating batch assignment'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _markPrimary(BatchModel batch) async {
    try {
      await context.read<CourseProvider>().setPrimaryBatchTeacher(
        widget.teacher.id,
        batch.id,
      );
      _loadAssignments();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error updating primary batch'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final batches = _adminBatches;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "Assign Batches to ${widget.teacher.name}",
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.saffronDark),
            )
          else if (batches.isEmpty)
            const Expanded(
              child: AppEmptyState(
                icon: Icons.groups_outlined,
                title: "No Institute Batches",
                description: "Create course batches first to assign faculty.",
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: batches.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  final batch = batches[index];
                  final assignment = _assignments
                      .where((a) => a['batch_id'] == batch.id)
                      .firstOrNull;
                  final isAssigned = assignment != null;
                  final isPrimary =
                      isAssigned && assignment['is_primary'] == true;

                  return InkWell(
                    onLongPress: isAssigned && !isPrimary
                        ? () => _markPrimary(batch)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    child: ModernCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                      accentSpineColor: isPrimary
                          ? AppColors.saffron
                          : (isAssigned ? AppColors.secondary : null),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  batch.name,
                                  style: AppTypography.subtitle2.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  batch.timing,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                if (isPrimary) ...[
                                  const SizedBox(height: 4),
                                  const CustomBadge(
                                    text: "PRIMARY INSTRUCTOR",
                                    variant: BadgeVariant.primary,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Switch(
                            value: isAssigned,
                            activeThumbColor: AppColors.saffronDark,
                            onChanged: (val) => _toggleAssignment(batch, val),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text(
              "Tip: Long-press or toggle assigned batches to grant faculty teaching access.",
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    ),
  );
}
}
