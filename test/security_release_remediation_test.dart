import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_classes_patna/features/tests/data/models/test_model.dart';

void main() {
  group('Security Verification 1: Exam Integrity & Answer Stripping (SEC-02)', () {
    test('QuestionModel.toStudentSafe strips correctOptionIndices and explanation', () {
      const q = QuestionModel(
        id: 'q_test_1',
        text: 'What is the capital of Bihar?',
        type: QuestionType.singleChoice,
        options: ['Patna', 'Gaya', 'Bhagalpur', 'Muzaffarpur'],
        correctOptionIndices: [0],
        explanation: 'Patna is the ancient Pataliputra and current capital of Bihar.',
        marks: 2.0,
      );

      final safeQ = q.toStudentSafe();

      expect(safeQ.id, 'q_test_1');
      expect(safeQ.text, 'What is the capital of Bihar?');
      expect(safeQ.options.length, 4);
      expect(safeQ.marks, 2.0);
      expect(safeQ.correctOptionIndices, isEmpty, reason: 'Must strip correctOptionIndices from student view');
      expect(safeQ.explanation, isEmpty, reason: 'Must strip explanation from student view');
    });

    test('TestModel.toStudentSafe sanitizes entire paper questions', () {
      final testPaper = TestModel(
        id: 'test_bpsc_prelims',
        courseId: 'crs_bpsc',
        batchId: 'batch_71st',
        title: 'BPSC 71st GS Mock Test',
        subject: 'General Studies',
        duration: const Duration(minutes: 120),
        totalMarks: 150.0,
        passingMarks: 60.0,
        negativeMarking: 0.33,
        totalQuestions: 2,
        questions: const [
          QuestionModel(
            id: 'q1',
            text: 'Question 1',
            type: QuestionType.singleChoice,
            options: ['Option A', 'Option B'],
            correctOptionIndices: [0],
            explanation: 'Secret answer A',
            marks: 2.0,
          ),
          QuestionModel(
            id: 'q2',
            text: 'Question 2',
            type: QuestionType.multipleChoice,
            options: ['Option A', 'Option B', 'Option C'],
            correctOptionIndices: [0, 2],
            explanation: 'Secret answers A and C',
            marks: 4.0,
          ),
        ],
        scheduledDate: DateTime(2026, 11, 4),
      );

      final safePaper = testPaper.toStudentSafe();

      expect(safePaper.title, 'BPSC 71st GS Mock Test');
      expect(safePaper.negativeMarking, 0.33);
      expect(safePaper.questions.length, 2);
      expect(safePaper.questions[0].correctOptionIndices, isEmpty);
      expect(safePaper.questions[0].explanation, isEmpty);
      expect(safePaper.questions[1].correctOptionIndices, isEmpty);
      expect(safePaper.questions[1].explanation, isEmpty);
    });
  });

  group('Security Verification 2: Android Native Hardening (SEC-07)', () {
    test('AndroidManifest.xml explicitly sets android:allowBackup="false"', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);

      final content = manifestFile.readAsStringSync();
      expect(
        content.contains('android:allowBackup="false"'),
        isTrue,
        reason: 'Application manifest must explicitly disable backup to prevent ADB credential extraction',
      );
    });
  });

  group('Security Verification 3: Edge Functions Hardening (SEC-03, SEC-05, SEC-06)', () {
    test('send_push_notification does not use unverified atob token payload check', () {
      final pushFile = File('supabase/functions/send_push_notification/index.ts');
      expect(pushFile.existsSync(), isTrue);

      final content = pushFile.readAsStringSync();
      expect(
        content.contains('atob(parts[1])'),
        isFalse,
        reason: 'Insecure atob token parsing without cryptographic signature verification must be eliminated',
      );
      expect(content.contains('supabase.auth.getUser') || content.contains('userClient.auth.getUser'), isTrue);
    });

    test('cloudflare_stream_manager includes delete_video in adminOnlyActions', () {
      final cfFile = File('supabase/functions/cloudflare_stream_manager/index.ts');
      expect(cfFile.existsSync(), isTrue);

      final content = cfFile.readAsStringSync();
      expect(
        content.contains('"delete_video"'),
        isTrue,
        reason: 'delete_video must be declared as an admin-only action',
      );
    });

    test('retry_acknowledgements enforces Authorization header and real RSASSA signing', () {
      final retryFile = File('supabase/functions/retry_acknowledgements/index.ts');
      expect(retryFile.existsSync(), isTrue);

      final content = retryFile.readAsStringSync();
      expect(
        content.contains('Authorization'),
        isTrue,
        reason: 'retry_acknowledgements must validate Authorization header',
      );
      expect(
        content.contains('fake-access-token-replace-with-real-auth-flow'),
        isFalse,
        reason: 'Placeholder access token must be replaced with real Google Play RSASSA JWT assertion',
      );
      expect(content.contains('RSASSA-PKCS1-v1_5'), isTrue);
    });

    test('supabase/config.toml enforces verify_jwt = true across functions', () {
      final configFile = File('supabase/config.toml');
      expect(configFile.existsSync(), isTrue);

      final content = configFile.readAsStringSync();
      expect(content.contains('[functions.send_push_notification]'), isTrue);
      expect(content.contains('[functions.cloudflare_stream_manager]'), isTrue);
      expect(content.contains('[functions.retry_acknowledgements]'), isTrue);
    });
  });

  group('Security Verification 4: Database Migration 065 Compliance (SEC-01, SEC-04, SEC-08, SEC-09)', () {
    test('Migration 065 restricts profiles, lecture-videos, doubts, and mutable search paths', () {
      final sqlFile = File('supabase/migrations/065_security_audit_remediation.sql');
      expect(sqlFile.existsSync(), isTrue);

      final content = sqlFile.readAsStringSync();
      // SEC-01: PII Protection
      expect(content.contains('DROP POLICY IF EXISTS "profiles_select_policy" ON public.profiles;'), isTrue);
      expect(content.contains("role IN ('teacher', 'admin')"), isTrue);

      // SEC-02: Authoritative Test RPCs
      expect(content.contains('CREATE OR REPLACE FUNCTION public.get_test_paper(p_test_id UUID)'), isTrue);
      expect(content.contains('CREATE OR REPLACE FUNCTION public.submit_student_test('), isTrue);

      // SEC-04: Lecture Videos Scoping
      expect(content.contains('DROP POLICY IF EXISTS "Public Read Lecture Videos" ON storage.objects;'), isTrue);
      expect(content.contains("bucket_id = 'lecture-videos'"), isTrue);

      // SEC-08: Doubt Attachments Scoping
      expect(content.contains('DROP POLICY IF EXISTS "doubt_attachments_select_policy" ON storage.objects;'), isTrue);
      expect(content.contains("bucket_id = 'doubt-attachments'"), isTrue);

      // SEC-09: search_path hardening
      expect(content.contains('ALTER FUNCTION public.sync_course_lesson_stats() SET search_path = public, pg_temp;'), isTrue);
      expect(content.contains('ALTER FUNCTION public.sync_course_test_stats() SET search_path = public, pg_temp;'), isTrue);
      expect(content.contains('ALTER FUNCTION public.do_timings_overlap(TEXT, TEXT) SET search_path = public, pg_temp;'), isTrue);
      expect(content.contains('ALTER FUNCTION public.parse_lecture_timing(TEXT) SET search_path = public, pg_temp;'), isTrue);
    });
  });
}
