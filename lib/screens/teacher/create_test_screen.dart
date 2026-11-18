import 'dart:math';
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

enum CaseSubQuestionFormat {
  singleChoice,
  multipleChoice,
  shortAnswer,
  longAnswer,
}

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
  QuestionType _selectedQType = QuestionType.singleChoice;
  CaseSubQuestionFormat _caseSubFormat = CaseSubQuestionFormat.singleChoice;
  final TextEditingController _qTextController = TextEditingController();
  final TextEditingController _qPassageController = TextEditingController();
  final TextEditingController _qOptAController = TextEditingController();
  final TextEditingController _qOptBController = TextEditingController();
  final TextEditingController _qOptCController = TextEditingController();
  final TextEditingController _qOptDController = TextEditingController();
  final TextEditingController _qSampleAnswerController = TextEditingController();
  final TextEditingController _qExplanationController = TextEditingController();
  final TextEditingController _qMarksController = TextEditingController(text: "2.0");

  int _correctOption = 0; // 0=A, 1=B, 2=C, 3=D for singleChoice
  final Set<int> _correctMultiOptions = {0}; // for multipleChoice
  int _trueFalseOption = 0; // 0=True, 1=False

  final List<QuestionModel> _addedQuestions = [];

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _durationMinutes.dispose();
    _qTextController.dispose();
    _qPassageController.dispose();
    _qOptAController.dispose();
    _qOptBController.dispose();
    _qOptCController.dispose();
    _qOptDController.dispose();
    _qSampleAnswerController.dispose();
    _qExplanationController.dispose();
    _qMarksController.dispose();
    super.dispose();
  }

  void _onQuestionTypeChanged(QuestionType newType) {
    setState(() {
      _selectedQType = newType;
      switch (newType) {
        case QuestionType.singleChoice:
        case QuestionType.trueFalse:
          _qMarksController.text = "2.0";
          break;
        case QuestionType.multipleChoice:
          _qMarksController.text = "4.0";
          break;
        case QuestionType.caseBased:
          _caseSubFormat = CaseSubQuestionFormat.singleChoice;
          _qMarksController.text = "2.0";
          break;
        case QuestionType.shortAnswer:
          _qMarksController.text = "5.0";
          break;
        case QuestionType.longAnswer:
        case QuestionType.descriptive:
          _qMarksController.text = "10.0";
          break;
      }
    });
  }

  void _addQuestionToList({bool keepPassage = false}) {
    final text = _qTextController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter question text / prompt.")),
      );
      return;
    }

    final marks = double.tryParse(_qMarksController.text.trim()) ?? 2.0;
    final explanation = _qExplanationController.text.trim();
    final sampleAnswer = _qSampleAnswerController.text.trim();
    final passage = _qPassageController.text.trim();

    QuestionModel newQ;

    switch (_selectedQType) {
      case QuestionType.singleChoice:
        if (_qOptAController.text.trim().isEmpty || _qOptBController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please provide at least Options A and B")),
          );
          return;
        }
        final options = [
          _qOptAController.text.trim(),
          _qOptBController.text.trim(),
          if (_qOptCController.text.trim().isNotEmpty) _qOptCController.text.trim(),
          if (_qOptDController.text.trim().isNotEmpty) _qOptDController.text.trim(),
        ];
        newQ = QuestionModel(
          id: "q_${DateTime.now().millisecondsSinceEpoch}_${_addedQuestions.length}",
          text: text,
          type: QuestionType.singleChoice,
          options: options,
          correctOptionIndices: [_correctOption],
          explanation: explanation.isNotEmpty
              ? explanation
              : "Correct answer is Option ${String.fromCharCode(65 + _correctOption)}.",
          marks: marks,
        );
        break;

      case QuestionType.multipleChoice:
        if (_qOptAController.text.trim().isEmpty || _qOptBController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please provide at least Options A and B")),
          );
          return;
        }
        if (_correctMultiOptions.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Select at least 1 correct option")),
          );
          return;
        }
        final multiOpts = [
          _qOptAController.text.trim(),
          _qOptBController.text.trim(),
          if (_qOptCController.text.trim().isNotEmpty) _qOptCController.text.trim(),
          if (_qOptDController.text.trim().isNotEmpty) _qOptDController.text.trim(),
        ];
        newQ = QuestionModel(
          id: "q_${DateTime.now().millisecondsSinceEpoch}_${_addedQuestions.length}",
          text: text,
          type: QuestionType.multipleChoice,
          options: multiOpts,
          correctOptionIndices: _correctMultiOptions.toList()..sort(),
          explanation: explanation.isNotEmpty
              ? explanation
              : "Correct options: ${_correctMultiOptions.map((i) => String.fromCharCode(65 + i)).join(', ')}.",
          marks: marks,
        );
        break;

      case QuestionType.trueFalse:
        newQ = QuestionModel(
          id: "q_${DateTime.now().millisecondsSinceEpoch}_${_addedQuestions.length}",
          text: text,
          type: QuestionType.trueFalse,
          options: const ["True", "False"],
          correctOptionIndices: [_trueFalseOption],
          explanation: explanation.isNotEmpty
              ? explanation
              : "Statement is ${_trueFalseOption == 0 ? 'True' : 'False'}.",
          marks: marks,
        );
        break;

      case QuestionType.shortAnswer:
        newQ = QuestionModel(
          id: "q_${DateTime.now().millisecondsSinceEpoch}_${_addedQuestions.length}",
          text: text,
          type: QuestionType.shortAnswer,
          options: const [],
          correctOptionIndices: const [],
          explanation: explanation,
          sampleAnswer: sampleAnswer,
          marks: marks,
        );
        break;

      case QuestionType.longAnswer:
      case QuestionType.descriptive:
        newQ = QuestionModel(
          id: "q_${DateTime.now().millisecondsSinceEpoch}_${_addedQuestions.length}",
          text: text,
          type: QuestionType.longAnswer,
          options: const [],
          correctOptionIndices: const [],
          explanation: explanation,
          sampleAnswer: sampleAnswer,
          marks: marks,
        );
        break;

      case QuestionType.caseBased:
        if (passage.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please provide the Case Study passage/narrative.")),
          );
          return;
        }

        if (_caseSubFormat == CaseSubQuestionFormat.singleChoice) {
          if (_qOptAController.text.trim().isEmpty || _qOptBController.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Please provide at least Options A and B")),
            );
            return;
          }
          final options = [
            _qOptAController.text.trim(),
            _qOptBController.text.trim(),
            if (_qOptCController.text.trim().isNotEmpty) _qOptCController.text.trim(),
            if (_qOptDController.text.trim().isNotEmpty) _qOptDController.text.trim(),
          ];
          newQ = QuestionModel(
            id: "q_${DateTime.now().millisecondsSinceEpoch}_${_addedQuestions.length}",
            text: text,
            type: QuestionType.caseBased,
            casePassage: passage,
            options: options,
            correctOptionIndices: [_correctOption],
            explanation: explanation.isNotEmpty
                ? explanation
                : "Correct answer is Option ${String.fromCharCode(65 + _correctOption)}.",
            marks: marks,
          );
        } else if (_caseSubFormat == CaseSubQuestionFormat.multipleChoice) {
          if (_qOptAController.text.trim().isEmpty || _qOptBController.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Please provide at least Options A and B")),
            );
            return;
          }
          if (_correctMultiOptions.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Select at least 1 correct option")),
            );
            return;
          }
          final multiOpts = [
            _qOptAController.text.trim(),
            _qOptBController.text.trim(),
            if (_qOptCController.text.trim().isNotEmpty) _qOptCController.text.trim(),
            if (_qOptDController.text.trim().isNotEmpty) _qOptDController.text.trim(),
          ];
          newQ = QuestionModel(
            id: "q_${DateTime.now().millisecondsSinceEpoch}_${_addedQuestions.length}",
            text: text,
            type: QuestionType.caseBased,
            casePassage: passage,
            options: multiOpts,
            correctOptionIndices: _correctMultiOptions.toList()..sort(),
            explanation: explanation.isNotEmpty
                ? explanation
                : "Correct options: ${_correctMultiOptions.map((i) => String.fromCharCode(65 + i)).join(', ')}.",
            marks: marks,
          );
        } else if (_caseSubFormat == CaseSubQuestionFormat.shortAnswer) {
          newQ = QuestionModel(
            id: "q_${DateTime.now().millisecondsSinceEpoch}_${_addedQuestions.length}",
            text: text,
            type: QuestionType.caseBased,
            casePassage: passage,
            options: const [],
            correctOptionIndices: const [],
            explanation: explanation,
            sampleAnswer: sampleAnswer,
            marks: marks,
          );
        } else {
          // CaseSubQuestionFormat.longAnswer
          newQ = QuestionModel(
            id: "q_${DateTime.now().millisecondsSinceEpoch}_${_addedQuestions.length}",
            text: text,
            type: QuestionType.caseBased,
            casePassage: passage,
            options: const [],
            correctOptionIndices: const [],
            explanation: explanation,
            sampleAnswer: sampleAnswer,
            marks: marks,
          );
        }
        break;
    }

    setState(() {
      _addedQuestions.add(newQ);
      _qTextController.clear();
      _qOptAController.clear();
      _qOptBController.clear();
      _qOptCController.clear();
      _qOptDController.clear();
      _qSampleAnswerController.clear();
      _qExplanationController.clear();
      _correctOption = 0;
      _correctMultiOptions.clear();
      _correctMultiOptions.add(0);
      _trueFalseOption = 0;
      if (!keepPassage) {
        _qPassageController.clear();
      }
    });

    final subQCount = _addedQuestions.where((q) => q.casePassage == passage).length;
    final message = (keepPassage && _selectedQType == QuestionType.caseBased)
        ? "Sub-question $subQCount added to case study! Passage kept for next sub-question."
        : "Question ${_addedQuestions.length} added!";

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

    String _generateUuidV4() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  Future<void> _saveAndPublishTest() async {
    if (_formKey.currentState!.validate()) {
      if (_addedQuestions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please add at least 1 question before publishing"),
          ),
        );
        return;
      }

      final courseProvider = context.read<CourseProvider>();
      final testProvider = context.read<TestProvider>();
      final notifProvider = context.read<NotificationProvider>();
      final auth = context.read<AuthProvider>();

      final course = courseProvider.getCourseById(
        _selectedCourseId ?? courseProvider.courses.first.id,
      )!;
      final batch = courseProvider.getBatchById(
        _selectedBatchId ?? courseProvider.batches.first.id,
      )!;
      final durationMins = int.tryParse(_durationMinutes.text) ?? 30;

      final totalMarks = _addedQuestions.fold<double>(
        0,
        (sum, q) => sum + q.marks,
      );

      final newTest = TestModel(
        id: _generateUuidV4(),
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
        attemptsCount: 0,
      );

      try {
        await testProvider.addTest(newTest);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Warning: Saved locally, remote sync error: $e"),
              backgroundColor: AppTheme.warning,
            ),
          );
        }
      }

      // Broadcast notification
      notifProvider.broadcastAnnouncement(
        title: "New Mock Test Published!",
        message:
            "${auth.currentUser.name} published '${_titleController.text.trim()}' with ${_addedQuestions.length} questions.",
        category: NotificationCategory.test,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Mock Test published live! Students can now take the exam.",
          ),
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

    final totalMarks = _addedQuestions.fold<double>(0.0, (sum, q) => sum + q.marks);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text("Create Mock Test / Exam")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Test Meta Config
              const Text(
                "Test Information",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _selectedCourseId,
                dropdownColor: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkSurface
                    : AppTheme.surfaceLight,
                decoration: const InputDecoration(labelText: "Course"),
                items: courses
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(
                          c.title,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedCourseId = val),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _selectedBatchId,
                dropdownColor: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkSurface
                    : AppTheme.surfaceLight,
                decoration: const InputDecoration(labelText: "Target Batch"),
                items: batches
                    .map(
                      (b) => DropdownMenuItem(
                        value: b.id,
                        child: Text(
                          b.name,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    )
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
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? "Enter exam title"
                    : null,
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
                      validator: (val) => (val == null || val.trim().isEmpty)
                          ? "Enter subject"
                          : null,
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
              Divider(color: isDark ? AppColors.darkBorder : AppTheme.border),
              const SizedBox(height: 16),

              // Question Builder Box
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Text(
                    "Add Questions (${_addedQuestions.length} added)",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  CustomBadge(
                    text: "${totalMarks.toStringAsFixed(1)} Total Marks",
                    variant: BadgeVariant.primary,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              ModernCard(
                padding: const EdgeInsets.all(16),
                backgroundColor: isDark ? AppColors.darkSurfaceCard : AppTheme.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question Type Dropdown / Segment
                    const Text(
                      "Question Format / Type *",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<QuestionType>(
                      isExpanded: true,
                      initialValue: _selectedQType,
                      dropdownColor: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.darkSurface
                          : AppTheme.surfaceLight,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: QuestionType.singleChoice,
                          child: Text(
                            "Single Choice (MCQ)",
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        DropdownMenuItem(
                          value: QuestionType.multipleChoice,
                          child: Text(
                            "Multiple Choice",
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        DropdownMenuItem(
                          value: QuestionType.trueFalse,
                          child: Text(
                            "True / False",
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        DropdownMenuItem(
                          value: QuestionType.shortAnswer,
                          child: Text(
                            "Short Answer",
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        DropdownMenuItem(
                          value: QuestionType.longAnswer,
                          child: Text(
                            "Long Answer",
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        DropdownMenuItem(
                          value: QuestionType.caseBased,
                          child: Text(
                            "Case Study",
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) _onQuestionTypeChanged(val);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Marks and Weightage
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        const Text(
                          "Marks Awarded:",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(
                          width: 80,
                          child: TextFormField(
                            controller: _qMarksController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Case Study Passage if Case-Based is selected
                    if (_selectedQType == QuestionType.caseBased) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.saffronMuted,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.saffronBorder),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: AppColors.saffronDark),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Case Study: You can add multiple sub-questions (MCQ, Short, or Long Answer) under this single passage. Click 'Add Sub-Question & Keep Passage' to add multiple questions under it.",
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.saffronDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _qPassageController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: "Case Study Passage / Context Narrative *",
                          hintText: "Enter the background context or reading passage for this question set...",
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Sub-Question Format Selector
                      const Text(
                        "Sub-Question Format:",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          ChoiceChip(
                            label: const Text("MCQ (Single Choice)"),
                            selected: _caseSubFormat == CaseSubQuestionFormat.singleChoice,
                            onSelected: (_) => setState(() {
                              _caseSubFormat = CaseSubQuestionFormat.singleChoice;
                              _qMarksController.text = "2.0";
                            }),
                            backgroundColor: isDark ? AppColors.darkSurface : AppTheme.surfaceLight,
                            selectedColor: AppTheme.primary,
                            labelStyle: TextStyle(
                              color: _caseSubFormat == CaseSubQuestionFormat.singleChoice
                                  ? Colors.white
                                  : (isDark ? AppColors.darkTextPrimary : AppColors.deepInk),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          ChoiceChip(
                            label: const Text("MCQ (Multi Choice)"),
                            selected: _caseSubFormat == CaseSubQuestionFormat.multipleChoice,
                            onSelected: (_) => setState(() {
                              _caseSubFormat = CaseSubQuestionFormat.multipleChoice;
                              _qMarksController.text = "4.0";
                            }),
                            backgroundColor: isDark ? AppColors.darkSurface : AppTheme.surfaceLight,
                            selectedColor: AppTheme.primary,
                            labelStyle: TextStyle(
                              color: _caseSubFormat == CaseSubQuestionFormat.multipleChoice
                                  ? Colors.white
                                  : (isDark ? AppColors.darkTextPrimary : AppColors.deepInk),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          ChoiceChip(
                            label: const Text("Short Answer"),
                            selected: _caseSubFormat == CaseSubQuestionFormat.shortAnswer,
                            onSelected: (_) => setState(() {
                              _caseSubFormat = CaseSubQuestionFormat.shortAnswer;
                              _qMarksController.text = "3.0";
                            }),
                            backgroundColor: isDark ? AppColors.darkSurface : AppTheme.surfaceLight,
                            selectedColor: AppTheme.primary,
                            labelStyle: TextStyle(
                              color: _caseSubFormat == CaseSubQuestionFormat.shortAnswer
                                  ? Colors.white
                                  : (isDark ? AppColors.darkTextPrimary : AppColors.deepInk),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          ChoiceChip(
                            label: const Text("Long Answer"),
                            selected: _caseSubFormat == CaseSubQuestionFormat.longAnswer,
                            onSelected: (_) => setState(() {
                              _caseSubFormat = CaseSubQuestionFormat.longAnswer;
                              _qMarksController.text = "6.0";
                            }),
                            backgroundColor: isDark ? AppColors.darkSurface : AppTheme.surfaceLight,
                            selectedColor: AppTheme.primary,
                            labelStyle: TextStyle(
                              color: _caseSubFormat == CaseSubQuestionFormat.longAnswer
                                  ? Colors.white
                                  : (isDark ? AppColors.darkTextPrimary : AppColors.deepInk),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Question Text
                    TextFormField(
                      controller: _qTextController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: _selectedQType == QuestionType.trueFalse
                            ? "Statement Prompt *"
                            : (_selectedQType == QuestionType.caseBased
                                ? "Sub-Question Prompt *"
                                : "Question Text / Prompt *"),
                        hintText: _selectedQType == QuestionType.caseBased
                            ? "e.g. Based on the passage above, what was the primary economic factor?"
                            : "e.g. In which year was the Bihar Provincial Congress Committee formed?",
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Conditional inputs for options / rubric
                    if (_selectedQType == QuestionType.singleChoice ||
                        _selectedQType == QuestionType.multipleChoice ||
                        (_selectedQType == QuestionType.caseBased &&
                            (_caseSubFormat == CaseSubQuestionFormat.singleChoice ||
                                _caseSubFormat == CaseSubQuestionFormat.multipleChoice))) ...[
                      TextFormField(
                        controller: _qOptAController,
                        decoration: const InputDecoration(
                          labelText: "Option A",
                          hintText: "e.g. 1906",
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _qOptBController,
                        decoration: const InputDecoration(
                          labelText: "Option B",
                          hintText: "e.g. 1908",
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _qOptCController,
                        decoration: const InputDecoration(
                          labelText: "Option C (Optional)",
                          hintText: "e.g. 1912",
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _qOptDController,
                        decoration: const InputDecoration(
                          labelText: "Option D (Optional)",
                          hintText: "e.g. 1916",
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Correct Answer Selector for Single Choice
                      if (_selectedQType == QuestionType.singleChoice ||
                          (_selectedQType == QuestionType.caseBased &&
                              _caseSubFormat == CaseSubQuestionFormat.singleChoice)) ...[
                        const Text(
                          "Correct Option Answer:",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [0, 1, 2, 3].map((opt) {
                            final label = String.fromCharCode(65 + opt);
                            final isSelected = _correctOption == opt;
                            return ChoiceChip(
                              label: Text(label),
                              selected: isSelected,
                              onSelected: (_) => setState(() => _correctOption = opt),
                              backgroundColor: isDark ? AppColors.darkSurface : AppTheme.surfaceLight,
                              selectedColor: AppTheme.success,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.deepInk),
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }).toList(),
                        ),
                      ],

                      // Multi-Select checkboxes for Multiple Choice
                      if (_selectedQType == QuestionType.multipleChoice ||
                          (_selectedQType == QuestionType.caseBased &&
                              _caseSubFormat == CaseSubQuestionFormat.multipleChoice)) ...[
                        const Text(
                          "Select ALL Correct Options (Multi-Correct):",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [0, 1, 2, 3].map((opt) {
                            final label = String.fromCharCode(65 + opt);
                            final isSelected = _correctMultiOptions.contains(opt);
                            return FilterChip(
                              label: Text(label),
                              selected: isSelected,
                              onSelected: (val) {
                                setState(() {
                                  if (val) {
                                    _correctMultiOptions.add(opt);
                                  } else {
                                    _correctMultiOptions.remove(opt);
                                  }
                                });
                              },
                              backgroundColor: isDark ? AppColors.darkSurface : AppTheme.surfaceLight,
                              selectedColor: AppTheme.success,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.deepInk),
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],

                    if (_selectedQType == QuestionType.trueFalse) ...[
                      const Text(
                        "Correct Answer:",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text("True"),
                            selected: _trueFalseOption == 0,
                            onSelected: (_) => setState(() => _trueFalseOption = 0),
                            selectedColor: AppTheme.success,
                            labelStyle: TextStyle(
                              color: _trueFalseOption == 0 ? Colors.white : AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ChoiceChip(
                            label: const Text("False"),
                            selected: _trueFalseOption == 1,
                            onSelected: (_) => setState(() => _trueFalseOption = 1),
                            selectedColor: AppTheme.error,
                            labelStyle: TextStyle(
                              color: _trueFalseOption == 1 ? Colors.white : AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (_selectedQType == QuestionType.shortAnswer ||
                        _selectedQType == QuestionType.longAnswer ||
                        _selectedQType == QuestionType.descriptive ||
                        (_selectedQType == QuestionType.caseBased &&
                            (_caseSubFormat == CaseSubQuestionFormat.shortAnswer ||
                                _caseSubFormat == CaseSubQuestionFormat.longAnswer))) ...[
                      TextFormField(
                        controller: _qSampleAnswerController,
                        maxLines: (_selectedQType == QuestionType.shortAnswer ||
                                (_selectedQType == QuestionType.caseBased &&
                                    _caseSubFormat == CaseSubQuestionFormat.shortAnswer))
                            ? 3
                            : 5,
                        decoration: InputDecoration(
                          labelText: "Model Answer / Grading Rubric (Optional)",
                          hintText: (_selectedQType == QuestionType.shortAnswer ||
                                  (_selectedQType == QuestionType.caseBased &&
                                      _caseSubFormat == CaseSubQuestionFormat.shortAnswer))
                              ? "Enter key points expected from students..."
                              : "Enter detailed evaluation rubric, key facts, and marking criteria...",
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _qExplanationController,
                      decoration: const InputDecoration(
                        labelText: "Explanation / Concept Key (Optional)",
                        hintText: "e.g. Formed under Syed Ali Imam in Patna in 1908.",
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_selectedQType == QuestionType.caseBased) ...[
                      ElevatedButton.icon(
                        icon: const Icon(Icons.playlist_add_rounded, size: 20),
                        label: const Text("Add Sub-Question & Keep Passage"),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                          backgroundColor: AppColors.saffronDark,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _addQuestionToList(keepPassage: true),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text("Add Sub-Question & Clear Passage"),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                          side: const BorderSide(color: AppTheme.primary),
                          foregroundColor: AppTheme.primary,
                        ),
                        onPressed: () => _addQuestionToList(keepPassage: false),
                      ),
                    ] else ...[
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text("Add Question to Exam"),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                          side: const BorderSide(color: AppTheme.primary),
                          foregroundColor: AppTheme.primary,
                        ),
                        onPressed: () => _addQuestionToList(keepPassage: false),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Added Questions List View
              if (_addedQuestions.isNotEmpty) ...[
                const Text(
                  "Questions in this Paper",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...List.generate(_addedQuestions.length, (index) {
                  final q = _addedQuestions[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceCard : AppTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppTheme.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                          child: Text(
                            "${index + 1}",
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CustomBadge(
                                    text: _typeBadgeName(q),
                                    variant: BadgeVariant.primary,
                                    fontSize: 9.5,
                                  ),
                                  const SizedBox(width: 6),
                                  CustomBadge(
                                    text: "+${q.marks.toStringAsFixed(1)} Marks",
                                    variant: BadgeVariant.success,
                                    fontSize: 9.5,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                q.text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                ),
                              ),
                              if (q.casePassage != null && q.casePassage!.trim().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    "Passage: ${q.casePassage!.trim()}",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                          onPressed: () {
                            setState(() {
                              _addedQuestions.removeAt(index);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                }),
              ],
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

  String _typeBadgeName(QuestionModel q) {
    if (q.type == QuestionType.caseBased) {
      final samePassage = _addedQuestions
          .where((item) =>
              item.casePassage != null &&
              item.casePassage!.trim().isNotEmpty &&
              item.casePassage == q.casePassage)
          .toList();
      final subIndex = samePassage.indexOf(q) + 1;
      final subTotal = samePassage.length;
      final formatStr = q.options.isEmpty
          ? (q.marks > 4 ? "Long" : "Short")
          : (q.correctOptionIndices.length > 1 ? "MCQ Multi" : "MCQ Single");
      if (subTotal > 1) {
        return "Case Study • Sub-Q $subIndex/$subTotal ($formatStr)";
      }
      return "Case Study ($formatStr)";
    }
    switch (q.type) {
      case QuestionType.singleChoice:
        return "Single Choice";
      case QuestionType.multipleChoice:
        return "Multiple Choice";
      case QuestionType.trueFalse:
        return "True / False";
      case QuestionType.shortAnswer:
        return "Short Answer";
      case QuestionType.longAnswer:
        return "Long Answer";
      case QuestionType.caseBased:
        return "Case Study";
      case QuestionType.descriptive:
        return "Descriptive";
    }
  }
}
