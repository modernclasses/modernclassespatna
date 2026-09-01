import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_button.dart';
import '../../core/widgets/modern_card.dart';
import '../../models/test_model.dart';
import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/test_provider.dart';
import '../../providers/notification_provider.dart';

class CreateTestScreen extends StatefulWidget {
  const CreateTestScreen({super.key});

  @override
  State<CreateTestScreen> createState() => _CreateTestScreenState();
}

class _CreateTestScreenState extends State<CreateTestScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _durationMinutes = TextEditingController(text: "30");

  String? _selectedCourseId;
  String? _selectedBatchId;

  // New Question form controllers
  final TextEditingController _qTextController = TextEditingController();
  final TextEditingController _qOptAController = TextEditingController();
  final TextEditingController _qOptBController = TextEditingController();
  final TextEditingController _qOptCController = TextEditingController();
  final TextEditingController _qOptDController = TextEditingController();
  final TextEditingController _qExplanationController = TextEditingController();
  int _correctOption = 0; // 0=A, 1=B, 2=C, 3=D

  final List<QuestionModel> _addedQuestions = [];

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _durationMinutes.dispose();
    _qTextController.dispose();
    _qOptAController.dispose();
    _qOptBController.dispose();
    _qOptCController.dispose();
    _qOptDController.dispose();
    _qExplanationController.dispose();
    super.dispose();
  }

  void _addQuestionToList() {
    if (_qTextController.text.trim().isEmpty ||
        _qOptAController.text.trim().isEmpty ||
        _qOptBController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill question text and at least options A & B")),
      );
      return;
    }

    final newQ = QuestionModel(
      id: "q_${DateTime.now().millisecondsSinceEpoch}_${_addedQuestions.length}",
      text: _qTextController.text.trim(),
      type: QuestionType.singleChoice,
      options: [
        _qOptAController.text.trim(),
        _qOptBController.text.trim(),
        if (_qOptCController.text.trim().isNotEmpty) _qOptCController.text.trim(),
        if (_qOptDController.text.trim().isNotEmpty) _qOptDController.text.trim(),
      ],
      correctOptionIndices: [_correctOption],
      explanation: _qExplanationController.text.trim().isNotEmpty
          ? _qExplanationController.text.trim()
          : "Correct answer is option ${String.fromCharCode(65 + _correctOption)}.",
      marks: 2.0,
    );

    setState(() {
      _addedQuestions.add(newQ);
      _qTextController.clear();
      _qOptAController.clear();
      _qOptBController.clear();
      _qOptCController.clear();
      _qOptDController.clear();
      _qExplanationController.clear();
      _correctOption = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Question ${_addedQuestions.length} added!"), duration: const Duration(seconds: 1)),
    );
  }

  void _saveAndPublishTest() {
    if (_formKey.currentState!.validate()) {
      if (_addedQuestions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please add at least 1 question before publishing")),
        );
        return;
      }

      final courseProvider = context.read<CourseProvider>();
      final testProvider = context.read<TestProvider>();
      final notifProvider = context.read<NotificationProvider>();
      final auth = context.read<AuthProvider>();

      final course = courseProvider.getCourseById(_selectedCourseId ?? courseProvider.courses.first.id)!;
      final batch = courseProvider.getBatchById(_selectedBatchId ?? courseProvider.batches.first.id)!;
      final durationMins = int.tryParse(_durationMinutes.text) ?? 30;

      final totalMarks = _addedQuestions.fold<double>(0, (sum, q) => sum + q.marks);

      final newTest = TestModel(
        id: "test_${DateTime.now().millisecondsSinceEpoch}",
        courseId: course.id,
        batchId: batch.id,
        title: _titleController.text.trim(),
        subject: _subjectController.text.trim(),
        duration: Duration(minutes: durationMins),
        totalMarks: totalMarks,
        passingMarks: totalMarks * 0.4,
        totalQuestions: _addedQuestions.length,
        questions: List.from(_addedQuestions),
        scheduledDate: DateTime.now(),
        isLive: true,
        allowsRetake: true,
      );

      testProvider.addTest(newTest);

      // Broadcast notification
      notifProvider.broadcastAnnouncement(
        title: "📝 New Mock Test Published!",
        message: "${auth.currentUser.name} published '${_titleController.text.trim()}' with ${_addedQuestions.length} questions.",
        category: NotificationCategory.test,
      );

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🎉 Mock Test published live! Students can now take the exam."),
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
        title: const Text("Create Mock Test / Exam"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Test Meta Config
              const Text("Test Information", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _selectedCourseId,
                dropdownColor: AppTheme.surfaceLight,
                decoration: const InputDecoration(labelText: "Course"),
                items: courses
                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.title, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (val) => setState(() => _selectedCourseId = val),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedBatchId,
                dropdownColor: AppTheme.surfaceLight,
                decoration: const InputDecoration(labelText: "Target Batch"),
                items: batches
                    .map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (val) => setState(() => _selectedBatchId = val),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: "Exam Title",
                  hintText: "e.g. BPSC Weekly Speed Test 03",
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? "Enter exam title" : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _subjectController,
                      decoration: const InputDecoration(
                        labelText: "Subject / Topic",
                        hintText: "e.g. Modern Bihar History",
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty) ? "Enter subject" : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _durationMinutes,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Duration (Minutes)",
                        hintText: "30",
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(color: AppTheme.border),
              const SizedBox(height: 16),

              // Question Builder Box
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Add Questions (${_addedQuestions.length} added)",
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  CustomBadge(
                    text: "${_addedQuestions.length * 2} Marks",
                    variant: BadgeVariant.primary,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              ModernCard(
                padding: const EdgeInsets.all(16),
                backgroundColor: AppTheme.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _qTextController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: "Question Text",
                        hintText: "e.g. In which year was the Bihar Provincial Congress Committee formed?",
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Options A, B, C, D
                    TextFormField(
                      controller: _qOptAController,
                      decoration: const InputDecoration(labelText: "Option A", hintText: "e.g. 1906"),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _qOptBController,
                      decoration: const InputDecoration(labelText: "Option B", hintText: "e.g. 1908"),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _qOptCController,
                      decoration: const InputDecoration(labelText: "Option C", hintText: "e.g. 1912"),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _qOptDController,
                      decoration: const InputDecoration(labelText: "Option D", hintText: "e.g. 1916"),
                    ),
                    const SizedBox(height: 14),

                    // Correct Option Selector
                    const Text("Correct Option Answer:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Row(
                      children: [0, 1, 2, 3].map((opt) {
                        final label = String.fromCharCode(65 + opt);
                        final isSelected = _correctOption == opt;
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: isSelected,
                            onSelected: (_) => setState(() => _correctOption = opt),
                            backgroundColor: AppTheme.surfaceLight,
                            selectedColor: AppTheme.success,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _qExplanationController,
                      decoration: const InputDecoration(
                        labelText: "Explanation / Concept Key (Optional)",
                        hintText: "e.g. Formed under Syed Ali Imam in Patna in 1908.",
                      ),
                    ),
                    const SizedBox(height: 16),

                    OutlinedButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text("Add Question to Exam"),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                        side: const BorderSide(color: AppTheme.primary),
                        foregroundColor: AppTheme.primary,
                      ),
                      onPressed: _addQuestionToList,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Publish Button
              ModernButton(
                text: "Publish Mock Exam Live (${_addedQuestions.length} Questions)",
                width: double.infinity,
                icon: Icons.rocket_launch,
                onPressed: _saveAndPublishTest,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
