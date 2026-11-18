import 'package:flutter_test/flutter_test.dart';
import 'package:modern_classes_patna/core/utils/google_play_tier_helper.dart';
import 'package:modern_classes_patna/core/utils/batch_timing_helper.dart';
import 'package:modern_classes_patna/features/attendance/data/models/attendance_model.dart';
import 'package:modern_classes_patna/features/attendance/data/repositories/attendance_repository.dart';
import 'package:modern_classes_patna/features/attendance/logic/attendance_provider.dart';
import 'package:modern_classes_patna/features/tests/data/models/test_model.dart';

class _FakeAttendanceRepo implements AttendanceRepository {
  final List<AttendanceRecordModel> stored = [];

  @override
  Future<List<AttendanceRecordModel>> getAttendanceRecords() async => List.from(stored);

  @override
  Future<void> saveAttendanceRecords(List<AttendanceRecordModel> records) async {
    stored.addAll(records);
  }
}

void main() {
  group('Adversarial Scenario 1: Financial & Coupon Edge Cases', () {
    test('Clamps excessive coupon discounts strictly to 0.0 (No negative payable)', () {
      const double originalPrice = 1500.0;
      const double excessiveCouponDiscount = 3000.0;

      final double payable = (originalPrice - excessiveCouponDiscount).clamp(0.0, double.infinity);
      expect(payable, 0.0);
      expect(GooglePlayTierHelper.isFreeEnrollment(payable), isTrue);
      expect(
        GooglePlayTierHelper.resolveProductTier(originalPrice: originalPrice, finalPayable: payable),
        GooglePlayTierHelper.freeEnrollment,
      );
    });

    test('Float precision & tier boundaries resolve deterministically', () {
      // Exactly at tier boundary ₹499
      expect(
        GooglePlayTierHelper.resolveProductTier(originalPrice: 1000, finalPayable: 499.00),
        GooglePlayTierHelper.tier499,
      );
      // Immediately above tier boundary ₹499.01 -> Clamped down to ₹499 to prevent overcharging
      expect(
        GooglePlayTierHelper.resolveProductTier(originalPrice: 1000, finalPayable: 499.01),
        GooglePlayTierHelper.tier499,
      );
      // Next 10-step boundary ₹509.00 -> course_tier_509
      expect(
        GooglePlayTierHelper.resolveProductTier(originalPrice: 1000, finalPayable: 509.00),
        'course_tier_509',
      );
      // Boundary ₹999.00 -> course_tier_999
      expect(
        GooglePlayTierHelper.resolveProductTier(originalPrice: 2000, finalPayable: 999.00),
        GooglePlayTierHelper.tier999,
      );
      // Boundary ₹1199.00 -> course_tier_1199
      expect(
        GooglePlayTierHelper.resolveProductTier(originalPrice: 2000, finalPayable: 1199.00),
        GooglePlayTierHelper.tier1199,
      );
    });

    test('Negative original price or invalid negative payable fails closed to freeEnrollment', () {
      expect(
        GooglePlayTierHelper.resolveProductTier(originalPrice: 500, finalPayable: -50.0),
        GooglePlayTierHelper.freeEnrollment,
      );
    });
  });

  group('Adversarial Scenario 2: Attendance 75% Threshold & Tamper Resistance', () {
    late AttendanceProvider attendanceProvider;

    setUp(() {
      attendanceProvider = AttendanceProvider(repository: _FakeAttendanceRepo());
    });

    test('Strict 74.9% boundary rejection (Under 75% fails to log)', () async {
      final success = await attendanceProvider.logLectureAttendanceAuto(
        batchId: 'batch_pcm_12',
        batchName: 'Class 12 PCM',
        studentId: 'student_101',
        studentName: 'Rahul Verma',
        lessonTitle: 'Electrostatics Part 1',
        watchPercentage: 0.749, // 74.9%
      );

      expect(success, isFalse);
      expect(attendanceProvider.records.isEmpty, isTrue);
    });

    test('Strict 75.0% boundary acceptance (75% marks attendance as present)', () async {
      final success = await attendanceProvider.logLectureAttendanceAuto(
        batchId: 'batch_pcm_12',
        batchName: 'Class 12 PCM',
        studentId: 'student_101',
        studentName: 'Rahul Verma',
        lessonTitle: 'Electrostatics Part 1',
        watchPercentage: 0.750, // Exactly 75.0%
      );

      expect(success, isTrue);
      expect(attendanceProvider.records.length, 1);
      expect(attendanceProvider.records.first.status, AttendanceStatus.present);
      expect(attendanceProvider.records.first.remarks, contains('Electrostatics Part 1'));
    });

    test('Prevents replay / multiple attendance submissions for same lesson on same day', () async {
      // First attempt at 75%
      final firstAttempt = await attendanceProvider.logLectureAttendanceAuto(
        batchId: 'batch_pcm_12',
        batchName: 'Class 12 PCM',
        studentId: 'student_101',
        studentName: 'Rahul Verma',
        lessonTitle: 'Electrostatics Part 1',
        watchPercentage: 0.80,
      );
      expect(firstAttempt, isTrue);

      // Replay attempt (e.g. user scrubs back or replays video on the same day)
      final secondAttempt = await attendanceProvider.logLectureAttendanceAuto(
        batchId: 'batch_pcm_12',
        batchName: 'Class 12 PCM',
        studentId: 'student_101',
        studentName: 'Rahul Verma',
        lessonTitle: 'Electrostatics Part 1',
        watchPercentage: 0.95,
      );
      expect(secondAttempt, isFalse);
      expect(attendanceProvider.records.length, 1); // No duplicated rows
    });
  });

  group('Adversarial Scenario 3: Batch Timing & Stream Invariant Parsing', () {
    test('Correctly parses morning batch timing into start, end, and days', () {
      final parsed = BatchTimingHelper.parseTiming('08:00 AM - 10:00 AM (Mon-Sat)');
      expect(parsed.start.hour, 8);
      expect(parsed.start.minute, 0);
      expect(parsed.end.hour, 10);
      expect(parsed.end.minute, 0);
      expect(parsed.days.contains('Mon'), isTrue);
      expect(parsed.days.contains('Sat'), isTrue);
      expect(parsed.days.contains('Sun'), isFalse);
    });

    test('Handles malformed or empty timing strings safely with default fallback', () {
      final parsed = BatchTimingHelper.parseTiming('');
      expect(parsed.start.hour, 8);
      expect(parsed.end.hour, 10);
      expect(parsed.days.isNotEmpty, isTrue);
    });
  });

  group('Adversarial Scenario 4: Test Taking & Grading Edge Cases', () {
    test('QuestionModel correctly parses case-based passages and rubrics', () {
      const question = QuestionModel(
        id: 'q_case_01',
        text: 'Based on the passage, calculate the emf of the cell.',
        type: QuestionType.caseBased,
        options: ['1.1 V', '2.2 V', '0.55 V', '3.3 V'],
        correctOptionIndices: [0],
        explanation: 'Standard EMF is calculated as E(cathode) - E(anode) = 0.34 - (-0.76) = 1.10 V.',
        marks: 4.0,
        casePassage: 'A galvanic cell is constructed using Zinc and Copper electrodes...',
        sampleAnswer: '1.10 V with step-by-step substitution.',
      );

      expect(question.type, QuestionType.caseBased);
      expect(question.casePassage, isNotNull);
      expect(question.sampleAnswer, contains('1.10 V'));

      final json = question.toMap();
      final restored = QuestionModel.fromMap(json);

      expect(restored.casePassage, question.casePassage);
      expect(restored.sampleAnswer, question.sampleAnswer);
      expect(restored.type, QuestionType.caseBased);
    });

    test('Subjective long answer preserves formatting and rubric without options', () {
      const question = QuestionModel(
        id: 'q_long_01',
        text: 'Explain the working of a Cyclotron with a neat diagram.',
        type: QuestionType.longAnswer,
        options: [],
        correctOptionIndices: [],
        explanation: 'Rubric: 1 mark for principle, 2 marks for construction, 2 marks for working.',
        marks: 5.0,
        sampleAnswer: 'A cyclotron accelerates charged particles using an alternating electric field...',
      );

      expect(question.options.isEmpty, isTrue);
      expect(question.sampleAnswer, isNotEmpty);
      expect(question.type, QuestionType.longAnswer);
    });
  });
}
