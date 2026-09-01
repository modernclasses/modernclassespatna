import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/modern_button.dart';
import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/live_class_provider.dart';
import '../../providers/notification_provider.dart';

class ScheduleLiveClassScreen extends StatefulWidget {
  const ScheduleLiveClassScreen({super.key});

  @override
  State<ScheduleLiveClassScreen> createState() => _ScheduleLiveClassScreenState();
}

class _ScheduleLiveClassScreenState extends State<ScheduleLiveClassScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _streamUrlController = TextEditingController(text: "https://www.youtube.com/watch?v=live_demo_stream");
  final TextEditingController _durationMinutesController = TextEditingController(text: "90");

  String? _selectedCourseId;
  String? _selectedBatchId;
  final DateTime _scheduledTime = DateTime.now().add(const Duration(hours: 2));

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _streamUrlController.dispose();
    _durationMinutesController.dispose();
    super.dispose();
  }

  void _scheduleClass() {
    if (_formKey.currentState!.validate()) {
      final auth = context.read<AuthProvider>();
      final courseProvider = context.read<CourseProvider>();
      final liveProvider = context.read<LiveClassProvider>();
      final notifProvider = context.read<NotificationProvider>();

      final course = courseProvider.getCourseById(_selectedCourseId ?? courseProvider.courses.first.id)!;
      final batch = courseProvider.getBatchById(_selectedBatchId ?? courseProvider.batches.first.id)!;
      final durationMins = int.tryParse(_durationMinutesController.text) ?? 90;

      liveProvider.scheduleLiveClass(
        courseId: course.id,
        batchId: batch.id,
        courseName: course.title,
        batchName: batch.name,
        title: _titleController.text.trim(),
        subject: _subjectController.text.trim(),
        teacherName: auth.currentUser.name,
        teacherAvatar: auth.currentUser.avatarUrl ?? "",
        scheduledStartTime: _scheduledTime,
        duration: Duration(minutes: durationMins),
        streamUrl: _streamUrlController.text.trim(),
      );

      // Broadcast notification to batch students
      notifProvider.broadcastAnnouncement(
        title: "🔴 New Live Class Scheduled!",
        message: "${auth.currentUser.name} scheduled '${_titleController.text.trim()}' for ${batch.name}.",
        category: NotificationCategory.liveClass,
      );

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✨ Live class scheduled successfully! Students notified."),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final courseProvider = context.watch<CourseProvider>();
    final courses = courseProvider.courses;
    final batches = courseProvider.batches;

    _selectedCourseId ??= courses.isNotEmpty ? courses.first.id : null;
    _selectedBatchId ??= batches.isNotEmpty ? batches.first.id : null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Schedule Live Lecture"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Target Batch Card
              const Text("Select Target Course & Batch", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _selectedCourseId,
                dropdownColor: AppTheme.surfaceLight,
                decoration: const InputDecoration(labelText: "Course"),
                items: courses
                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.title, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedCourseId = val;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedBatchId,
                dropdownColor: AppTheme.surfaceLight,
                decoration: const InputDecoration(labelText: "Batch"),
                items: batches
                    .map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedBatchId = val;
                  });
                },
              ),
              const SizedBox(height: 20),

              // Title & Subject
              const Text("Class Information", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: "Live Class Title",
                  hintText: "e.g. Masterclass on Bihar Geography & Rivers",
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? "Please enter class title" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: "Subject / Topic",
                  hintText: "e.g. Geography / GS Paper 1",
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? "Please enter subject" : null,
              ),
              const SizedBox(height: 20),

              // Streaming Config
              const Text("YouTube Live Stream Link / Stream Key", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _streamUrlController,
                decoration: const InputDecoration(
                  labelText: "YouTube Live URL or Stream ID",
                  hintText: "https://www.youtube.com/watch?v=...",
                  prefixIcon: Icon(Icons.link, color: AppTheme.primary),
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? "Please enter stream URL" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _durationMinutesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Expected Duration (Minutes)",
                  hintText: "90",
                  prefixIcon: Icon(Icons.timer_outlined, color: AppTheme.primary),
                ),
              ),
              const SizedBox(height: 24),

              ModernButton(
                text: "Broadcast & Notify Students",
                width: double.infinity,
                icon: Icons.cell_tower,
                onPressed: _scheduleClass,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
