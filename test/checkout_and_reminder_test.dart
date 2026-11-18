import 'package:flutter_test/flutter_test.dart';
import 'package:modern_classes_patna/features/courses/data/models/batch_model.dart';
import 'package:modern_classes_patna/core/utils/google_play_tier_helper.dart';

void main() {
  group('Checkout Product ID Resolution Tests', () {
    test('Resolves storeProductId to playProductId when configured', () {
      final batch = BatchModel(
        id: 'b1',
        courseId: 'c1',
        name: 'Target Batch 2026',
        teacherName: 'Dr. Anand Kumar',
        teacherId: 'teacher_01',
        totalStudents: 25,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        timing: '10:00 AM',
        batchPrice: 2500,
        playProductId: 'bpsc_crash_course_2026',
      );

      final storeProductId = (batch.playProductId != null && batch.playProductId!.isNotEmpty)
          ? batch.playProductId!
          : 'mock_batch_product_001';

      expect(storeProductId, 'bpsc_crash_course_2026');
      expect('mockpurchase:$storeProductId:123', 'mockpurchase:bpsc_crash_course_2026:123');
    });

    test('Falls back to mock_batch_product_001 when playProductId is null or empty', () {
      final batch = BatchModel(
        id: 'b2',
        courseId: 'c1',
        name: 'Target Batch 2026',
        teacherName: 'Dr. Anand Kumar',
        teacherId: 'teacher_01',
        totalStudents: 25,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        timing: '10:00 AM',
        batchPrice: 2500,
        playProductId: null,
      );

      final storeProductId = (batch.playProductId != null && batch.playProductId!.isNotEmpty)
          ? batch.playProductId!
          : 'mock_batch_product_001';

      expect(storeProductId, 'mock_batch_product_001');
      expect('mockpurchase:$storeProductId:123', 'mockpurchase:mock_batch_product_001:123');
    });
  });

  group('Scenario 2: Google Play Tier Downgrading & Free Coupon Bypass Tests', () {
    test('Identifies free enrollment correctly (0 or negative payable)', () {
      expect(GooglePlayTierHelper.isFreeEnrollment(0.0), isTrue);
      expect(GooglePlayTierHelper.isFreeEnrollment(-10.0), isTrue);
      expect(GooglePlayTierHelper.isFreeEnrollment(1.0), isFalse);
    });

    test('Resolves 0 payable to freeEnrollment constant', () {
      final tier = GooglePlayTierHelper.resolveProductTier(
        originalPrice: 2000.0,
        finalPayable: 0.0,
        batchProductId: 'batch_sku_custom',
      );
      expect(tier, GooglePlayTierHelper.freeEnrollment);
    });

    test('Preserves custom batch product ID when full price is paid', () {
      final tier = GooglePlayTierHelper.resolveProductTier(
        originalPrice: 2000.0,
        finalPayable: 2000.0,
        batchProductId: 'bpsc_mains_special',
      );
      expect(tier, 'bpsc_mains_special');
    });

    test('Downgrades product tier when coupon discount is applied', () {
      // Original price ₹2,000, 50% discount -> ₹1,000 payable
      final tier = GooglePlayTierHelper.resolveProductTier(
        originalPrice: 2000.0,
        finalPayable: 1000.0,
        batchProductId: 'bpsc_mains_special',
      );
      // Payable ₹1,000 maps to 10-step ladder: (1000 - 9)/10 = 99.1 -> 999
      expect(tier, GooglePlayTierHelper.tier999);
    });

    test('Maps exact price boundaries to correct Google Play tier SKUs', () {
      expect(
        GooglePlayTierHelper.resolveProductTier(originalPrice: 400, finalPayable: 9),
        GooglePlayTierHelper.tier9,
      );
      expect(
        GooglePlayTierHelper.resolveProductTier(originalPrice: 400, finalPayable: 19),
        GooglePlayTierHelper.tier19,
      );
      expect(
        GooglePlayTierHelper.resolveProductTier(originalPrice: 400, finalPayable: 299),
        GooglePlayTierHelper.tier299,
      );
      expect(
        GooglePlayTierHelper.resolveProductTier(originalPrice: 1000, finalPayable: 399),
        GooglePlayTierHelper.tier399,
      );
      expect(
        GooglePlayTierHelper.resolveProductTier(originalPrice: 1000, finalPayable: 499),
        GooglePlayTierHelper.tier499,
      );
      expect(
        GooglePlayTierHelper.resolveProductTier(originalPrice: 1200, finalPayable: 599),
        GooglePlayTierHelper.tier599,
      );
      expect(
        GooglePlayTierHelper.resolveProductTier(originalPrice: 2000, finalPayable: 1199),
        GooglePlayTierHelper.tier1199,
      );
      expect(
        GooglePlayTierHelper.resolveProductTier(originalPrice: 3000, finalPayable: 2199),
        GooglePlayTierHelper.tier2199,
      );
      expect(
        GooglePlayTierHelper.resolveProductTier(originalPrice: 4000, finalPayable: 3199),
        GooglePlayTierHelper.tier3199,
      );
    });

    test('Returns friendly user display name for tiers', () {
      expect(
        GooglePlayTierHelper.getTierDisplayName(GooglePlayTierHelper.tier999),
        'Course Tier (₹999)',
      );
      expect(
        GooglePlayTierHelper.getTierDisplayName(GooglePlayTierHelper.tier299),
        'Course Tier (₹299)',
      );
      expect(
        GooglePlayTierHelper.getTierDisplayName(GooglePlayTierHelper.freeEnrollment),
        '100% Scholarship / Free',
      );
    });
  });

  group('Live Class Reminder State Tests', () {
    test('Reminder toggle set adds and removes class ID correctly', () {
      final reminders = <String>{};
      const classId = 'live_class_999';

      // 1. Toggle On
      if (reminders.contains(classId)) {
        reminders.remove(classId);
      } else {
        reminders.add(classId);
      }
      expect(reminders.contains(classId), isTrue);

      // 2. Toggle Off
      if (reminders.contains(classId)) {
        reminders.remove(classId);
      } else {
        reminders.add(classId);
      }
      expect(reminders.contains(classId), isFalse);
    });
  });
}
