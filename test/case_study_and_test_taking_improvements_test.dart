import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:modern_classes_patna/features/auth/data/models/user_model.dart';
import 'package:modern_classes_patna/features/auth/data/repositories/auth_repository.dart';
import 'package:modern_classes_patna/features/auth/logic/auth_provider.dart';
import 'package:modern_classes_patna/features/courses/logic/course_provider.dart';
import 'package:modern_classes_patna/features/tests/data/models/test_model.dart';
import 'package:modern_classes_patna/features/tests/data/repositories/test_repository.dart';
import 'package:modern_classes_patna/features/tests/logic/test_provider.dart';
import 'package:modern_classes_patna/providers/theme_provider.dart';
import 'package:modern_classes_patna/screens/student/test_taking_screen.dart';
import 'package:modern_classes_patna/screens/teacher/create_test_screen.dart';
import 'fake_course_repository.dart';

class MockExamRepo implements TestRepository {
  List<TestModel> tests;
  List<TestResultModel> submissions;

  MockExamRepo({
    required this.tests,
    List<TestResultModel>? submissions,
  }) : submissions = submissions != null ? List.from(submissions) : [];

  @override
  Future<List<TestModel>> getTests() async => tests;

  @override
  Future<TestModel> getTestPaper(String testId) async =>
      tests.firstWhere((t) => t.id == testId);

  @override
  Future<void> submitTestResult(TestResultModel result) async {
    submissions.add(result);
  }

  @override
  Future<void> createTest(TestModel test) async {
    tests.add(test);
  }

  @override
  Future<void> deleteTest(String testId) async {
    tests.removeWhere((t) => t.id == testId);
  }

  @override
  Future<List<TestResultModel>> getTestSubmissionsForTest(String testId) async {
    return submissions.where((s) => s.testId == testId).toList();
  }
}

class FakeAuthRepo implements AuthRepository {
  final UserModel? currentUser;
  FakeAuthRepo({this.currentUser});

  @override
  bool get isConnected => true;

  @override
  Future<UserModel?> getInitialSession() async => currentUser;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  final sampleTeacher = UserModel(
    id: "usr_teacher_1",
    email: "teacher@modernclasses.com",
    role: UserRole.teacher,
    name: "Dr. K. Sharma",
    phone: "9876543210",
  );

  final sampleStudent = UserModel(
    id: "usr_student_1",
    email: "student@modernclasses.com",
    role: UserRole.student,
    name: "Aditya Kumar",
    phone: "9876543211",
  );

  group("Case Study & Test Taking Functionality Tests", () {
    test("TestProvider: clicking options on QuestionType.caseBased records selection properly", () {
      final caseStudySingleChoice = QuestionModel(
        id: "q_cs_1",
        text: "What was the main economic output discussed?",
        type: QuestionType.caseBased,
        casePassage: "In 1917, Mahatma Gandhi arrived in Champaran to investigate indigo farming...",
        options: ["Indigo", "Opium", "Cotton", "Tea"],
        correctOptionIndices: [0],
        explanation: "Indigo was the primary cash crop.",
        marks: 4.0,
      );

      final caseStudyMultiChoice = QuestionModel(
        id: "q_cs_2",
        text: "Which of the following leaders joined the movement?",
        type: QuestionType.caseBased,
        casePassage: "In 1917, Mahatma Gandhi arrived in Champaran to investigate indigo farming...",
        options: ["Rajkumar Shukla", "Dr. Rajendra Prasad", "Lord Curzon", "J.B. Kripalani"],
        correctOptionIndices: [0, 1, 3],
        explanation: "Rajkumar Shukla, Dr. Rajendra Prasad, and J.B. Kripalani supported Gandhi.",
        marks: 4.0,
      );

      final testPaper = TestModel(
        id: "test_history_01",
        courseId: "course_001",
        batchId: "batch_001",
        title: "Modern Indian History Mock",
        subject: "History",
        duration: const Duration(minutes: 30),
        totalMarks: 8.0,
        passingMarks: 3.2,
        totalQuestions: 2,
        questions: [caseStudySingleChoice, caseStudyMultiChoice],
        scheduledDate: DateTime.now(),
      );

      final testProvider = TestProvider(repository: MockExamRepo(tests: [testPaper]));
      testProvider.startTest(testPaper);

      // Question 1: Single choice case-based
      testProvider.selectOptionForCurrentQuestion(2); // Option C
      expect(testProvider.currentResponses["q_cs_1"]?.selectedOptionIndices, equals([2]));

      testProvider.selectOptionForCurrentQuestion(0); // Option A (replaces C)
      expect(testProvider.currentResponses["q_cs_1"]?.selectedOptionIndices, equals([0]));

      // Jump to Question 2: Multi choice case-based
      testProvider.jumpToQuestion(1);
      testProvider.selectOptionForCurrentQuestion(0); // Rajkumar Shukla
      testProvider.selectOptionForCurrentQuestion(1); // Rajendra Prasad
      expect(testProvider.currentResponses["q_cs_2"]?.selectedOptionIndices, containsAll([0, 1]));

      testProvider.selectOptionForCurrentQuestion(3); // J.B. Kripalani
      expect(testProvider.currentResponses["q_cs_2"]?.selectedOptionIndices, containsAll([0, 1, 3]));

      // Deselect option 1
      testProvider.selectOptionForCurrentQuestion(1);
      expect(testProvider.currentResponses["q_cs_2"]?.selectedOptionIndices, equals([0, 3]));
    });

    test("TestProvider: short answer, long answer, and case study written text are saved and marked as attempted", () async {
      final shortAnsQ = QuestionModel(
        id: "q_short_1",
        text: "Explain the Tinkathia system in 2-3 sentences.",
        type: QuestionType.shortAnswer,
        options: const [],
        correctOptionIndices: const [],
        explanation: "Tinkathia system explanation.",
        marks: 3.0,
      );

      final caseStudyTextQ = QuestionModel(
        id: "q_cs_text_1",
        text: "Critically examine the legal arguments presented by Gandhi.",
        type: QuestionType.caseBased,
        casePassage: "Gandhi refused to obey the order to leave Champaran...",
        options: const [],
        correctOptionIndices: const [],
        explanation: "Legal arguments critique.",
        marks: 5.0,
      );

      final testPaper = TestModel(
        id: "test_descriptive_01",
        courseId: "course_001",
        batchId: "batch_001",
        title: "BPSC Mains Sectional",
        subject: "History",
        duration: const Duration(minutes: 60),
        totalMarks: 8.0,
        passingMarks: 3.0,
        totalQuestions: 2,
        questions: [shortAnsQ, caseStudyTextQ],
        scheduledDate: DateTime.now(),
      );

      final mockRepo = MockExamRepo(tests: [testPaper]);
      final testProvider = TestProvider(repository: mockRepo);
      testProvider.startTest(testPaper);

      testProvider.setDescriptiveAnswerForQuestion(
        "q_short_1",
        "Tinkathia was a system where peasants were compelled to cultivate indigo on 3/20th of their land.",
      );

      testProvider.jumpToQuestion(1);
      testProvider.setDescriptiveAnswerForQuestion(
        "q_cs_text_1",
        "Gandhi argued that he acted in obedience to the higher law of our being, the voice of conscience.",
      );

      expect(
        testProvider.currentResponses["q_short_1"]?.writtenAnswer,
        contains("Tinkathia was a system"),
      );
      expect(
        testProvider.currentResponses["q_cs_text_1"]?.writtenAnswer,
        contains("voice of conscience"),
      );

      final result = await testProvider.submitTest(
        studentId: "usr_student_1",
        studentName: "Aditya Kumar",
      );

      expect(result.unattemptedCount, equals(0));
      expect(result.responses["q_short_1"]?.writtenAnswer, isNotEmpty);
      expect(result.responses["q_cs_text_1"]?.writtenAnswer, isNotEmpty);
    });

    testWidgets("TestTakingScreen: displays 'Sub-Question 1 of 2' and blocks copy-paste answers", (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sharedPassage = "Under the Permanent Settlement of 1793 in Bengal and Bihar, zamindars were recognized as owners of land.";

      final subQ1 = QuestionModel(
        id: "q_sub_1",
        text: "Who introduced the Permanent Settlement in 1793?",
        type: QuestionType.caseBased,
        casePassage: sharedPassage,
        options: ["Lord Cornwallis", "Warren Hastings", "Lord Dalhousie", "William Bentinck"],
        correctOptionIndices: [0],
        explanation: "Lord Cornwallis introduced it in 1793.",
        marks: 2.0,
      );

      final subQ2 = QuestionModel(
        id: "q_sub_2",
        text: "Analyze how this affected the tenant farmers in Bihar.",
        type: QuestionType.caseBased,
        casePassage: sharedPassage,
        options: const [],
        correctOptionIndices: const [],
        explanation: "Impact on tenants.",
        marks: 4.0,
      );

      final testPaper = TestModel(
        id: "test_shared_case",
        courseId: "course_001",
        batchId: "batch_001",
        title: "Land Revenue Systems",
        subject: "Economics",
        duration: const Duration(minutes: 30),
        totalMarks: 6.0,
        passingMarks: 2.0,
        totalQuestions: 2,
        questions: [subQ1, subQ2],
        scheduledDate: DateTime.now(),
      );

      final testProvider = TestProvider(repository: MockExamRepo(tests: [testPaper]));
      testProvider.startTest(testPaper);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: testProvider),
            ChangeNotifierProvider(
              create: (_) => AuthProvider(
                repository: FakeAuthRepo(currentUser: sampleStudent),
              ),
            ),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ],
          child: MaterialApp(
            home: TestTakingScreen(test: testPaper),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check anti-cheating banner
      expect(find.textContaining("Anti-Cheat Active: Copy/Paste is blocked"), findsOneWidget);

      // Check Question 1: displays Sub-Question 1 of 2
      expect(find.textContaining("Sub-Question 1 of 2"), findsWidgets);
      expect(find.text("Lord Cornwallis"), findsOneWidget);

      // Tap Option A: Lord Cornwallis
      await tester.tap(find.text("Lord Cornwallis"));
      await tester.pumpAndSettle();
      expect(testProvider.currentResponses["q_sub_1"]?.selectedOptionIndices, equals([0]));

      // Navigate to Next (Sub-Question 2)
      await tester.tap(find.text("Next"));
      await tester.pumpAndSettle();

      // Check Question 2: displays Sub-Question 2 of 2 and written text field
      expect(find.textContaining("Sub-Question 2 of 2"), findsWidgets);
      expect(find.byType(TextField), findsOneWidget);

      // 1. Attempt to bulk copy-paste an answer:
      await tester.enterText(
        find.byType(TextField),
        "Pasting complete answer stolen from external website.",
      );
      await tester.pump();

      // Anti-cheat paste prevention should reject the bulk paste and show warning
      expect(find.textContaining("Copy/Pasting answers is disabled during examinations"), findsOneWidget);
      expect(testProvider.currentResponses["q_sub_2"]?.writtenAnswer, isNull);

      // 2. Normal typing character-by-character succeeds:
      String manualTyped = "";
      for (final char in "Tenants suffered.".split('')) {
        manualTyped += char;
        await tester.enterText(find.byType(TextField), manualTyped);
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(
        testProvider.currentResponses["q_sub_2"]?.writtenAnswer,
        equals("Tenants suffered."),
      );
    });

    testWidgets("TestTakingScreen: switching or minimizing the app resets test session and forces restart", (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final q1 = QuestionModel(
        id: "q_cheat_1",
        text: "What is 2+2?",
        type: QuestionType.singleChoice,
        options: ["2", "3", "4", "5"],
        correctOptionIndices: [2],
        explanation: "2+2=4",
        marks: 2.0,
      );

      final testPaper = TestModel(
        id: "test_anti_cheat",
        courseId: "course_001",
        batchId: "batch_001",
        title: "Integrity Test",
        subject: "General",
        duration: const Duration(minutes: 10),
        totalMarks: 2.0,
        passingMarks: 1.0,
        totalQuestions: 1,
        questions: [q1],
        scheduledDate: DateTime.now(),
      );

      final testProvider = TestProvider(repository: MockExamRepo(tests: [testPaper]));
      testProvider.startTest(testPaper);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: testProvider),
            ChangeNotifierProvider(
              create: (_) => AuthProvider(
                repository: FakeAuthRepo(currentUser: sampleStudent),
              ),
            ),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ],
          child: MaterialApp(
            home: TestTakingScreen(test: testPaper),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Student selects Option C ("4")
      await tester.tap(find.text("4"));
      await tester.pumpAndSettle();
      expect(testProvider.currentResponses["q_cheat_1"]?.selectedOptionIndices, equals([2]));

      // Student switches away or minimizes the app (paused/hidden)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // Student switches back to the app (resumed)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // Anti-cheat violation dialog MUST appear
      expect(find.text("Exam Integrity Alert"), findsOneWidget);
      expect(find.textContaining("You switched away from or minimized the exam screen"), findsOneWidget);
      expect(find.text("Start Test Over"), findsOneWidget);

      // In-memory test responses must have been reset
      expect(testProvider.currentResponses["q_cheat_1"]?.selectedOptionIndices, isNull);

      // Student clicks "Start Test Over"
      await tester.tap(find.text("Start Test Over"));
      await tester.pumpAndSettle();

      // Dialog is gone, test restarted from Question 1 with a fresh state
      expect(find.text("Exam Integrity Alert"), findsNothing);
      expect(find.textContaining("Question 1 of 1"), findsOneWidget);
      expect(find.textContaining("Test restarted from Question 1 with a fresh timer"), findsOneWidget);
      // Option is unselected in the restarted test
      expect(testProvider.currentResponses["q_cheat_1"]?.selectedOptionIndices, isEmpty);
    });

    testWidgets("CreateTestScreen: teacher can add multiple sub-questions keeping passage", (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockTestRepo = MockExamRepo(tests: []);
      final fakeCourseRepo = FakeCourseRepository();
      final courseProvider = CourseProvider(repository: fakeCourseRepo);
      await courseProvider.fetchCatalog();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => TestProvider(repository: mockTestRepo),
            ),
            ChangeNotifierProvider.value(
              value: courseProvider,
            ),
            ChangeNotifierProvider(
              create: (_) => AuthProvider(
                repository: FakeAuthRepo(currentUser: sampleTeacher),
              ),
            ),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ],
          child: const MaterialApp(
            home: CreateTestScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to Case Study question type
      final qTypeDropdown = find.byType(DropdownButtonFormField<QuestionType>);
      expect(qTypeDropdown, findsOneWidget);
      await tester.tap(qTypeDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text("Case Study").last);
      await tester.pumpAndSettle();

      // Should show the Case Study Passage field and Sub-Question format chips
      expect(find.text("Case Study Passage / Context Narrative *"), findsOneWidget);
      expect(find.text("Sub-Question Format:"), findsOneWidget);
      expect(find.text("MCQ (Single Choice)"), findsOneWidget);
      expect(find.text("Short Answer"), findsOneWidget);
      expect(find.text("Long Answer"), findsOneWidget);
      expect(find.text("Add Sub-Question & Keep Passage"), findsOneWidget);
    });
  });
}
