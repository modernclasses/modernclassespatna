import 'package:flutter_test/flutter_test.dart';
import 'package:modern_classes_patna/features/courses/logic/course_provider.dart';
import 'package:modern_classes_patna/models/payment_model.dart';
import 'revenue_ledger_test.dart';

void main() {
  group('Custom Coupon System Tests', () {
    late CourseProvider courseProvider;
    late FakeCourseRepository fakeRepository;

    setUp(() {
      fakeRepository = FakeCourseRepository();
      courseProvider = CourseProvider(repository: fakeRepository);
    });

    test('Initial default coupons are loaded on provider initialization', () {
      expect(courseProvider.coupons.isNotEmpty, isTrue);
      expect(courseProvider.coupons.any((c) => c.code == 'PATNA50'), isTrue);
      expect(courseProvider.coupons.any((c) => c.code == 'WELCOME100'), isTrue);
    });

    test('addCustomCoupon adds new coupon and allows validation', () async {
      const customCoupon = CouponModel(
        code: 'SUPER500',
        discountAmount: 500,
        minOrderValue: 1500,
        description: 'Super discount for civil services',
        isActive: true,
      );

      await courseProvider.addCustomCoupon(customCoupon);

      expect(courseProvider.coupons.any((c) => c.code == 'SUPER500'), isTrue);

      // Fails if below minimum order value
      expect(courseProvider.validateCoupon('SUPER500', 1000), isNull);

      // Succeeds if meets minimum order value
      final valid = courseProvider.validateCoupon('SUPER500', 2000);
      expect(valid, isNotNull);
      expect(valid!.discountAmount, 500);
      expect(valid.code, 'SUPER500');
    });

    test('validateCoupon is case-insensitive and trims whitespace', () async {
      const customCoupon = CouponModel(
        code: 'NEETRANK1',
        discountAmount: 350,
        minOrderValue: 800,
        description: 'NEET rank booster',
        isActive: true,
      );

      await courseProvider.addCustomCoupon(customCoupon);

      final validLower = courseProvider.validateCoupon('  neetrank1  ', 1000);
      expect(validLower, isNotNull);
      expect(validLower!.discountAmount, 350);
    });

    test('removeCustomCoupon successfully removes coupon', () async {
      const customCoupon = CouponModel(
        code: 'FLASH24',
        discountAmount: 150,
        minOrderValue: 300,
        description: '24 hour flash discount',
        isActive: true,
      );

      await courseProvider.addCustomCoupon(customCoupon);
      expect(courseProvider.coupons.any((c) => c.code == 'FLASH24'), isTrue);

      await courseProvider.removeCustomCoupon('FLASH24');
      expect(courseProvider.coupons.any((c) => c.code == 'FLASH24'), isFalse);
      expect(courseProvider.validateCoupon('FLASH24', 500), isNull);
    });

    test('Coupon course eligibility - universal coupon is valid for any course', () async {
      const universalCoupon = CouponModel(
        code: 'ALLCOURSES100',
        discountAmount: 100,
        minOrderValue: 400,
        description: 'Valid for all courses',
        isActive: true,
        applicableCourseIds: [], // empty = universal
      );

      await courseProvider.addCustomCoupon(universalCoupon);

      // Should be valid with any course ID
      final result1 = courseProvider.validateCouponDetailed(
        'ALLCOURSES100',
        500,
        courseId: 'course_bpsc_001',
      );
      expect(result1.isValid, isTrue);

      final result2 = courseProvider.validateCouponDetailed(
        'ALLCOURSES100',
        500,
        courseId: 'course_neet_002',
      );
      expect(result2.isValid, isTrue);

      // Should be valid even when courseId is omitted
      final result3 = courseProvider.validateCouponDetailed('ALLCOURSES100', 500);
      expect(result3.isValid, isTrue);
    });

    test('Coupon course eligibility - restricted coupon rejects ineligible course', () async {
      const bpscOnlyCoupon = CouponModel(
        code: 'BPSC_SPECIAL',
        discountAmount: 250,
        minOrderValue: 500,
        description: 'Only valid for BPSC foundation',
        isActive: true,
        applicableCourseIds: ['course_bpsc_001'],
      );

      await courseProvider.addCustomCoupon(bpscOnlyCoupon);

      // Eligible course succeeds
      final validResult = courseProvider.validateCouponDetailed(
        'BPSC_SPECIAL',
        600,
        courseId: 'course_bpsc_001',
      );
      expect(validResult.isValid, isTrue);
      expect(validResult.status, CouponValidationStatus.valid);
      expect(validResult.coupon!.discountAmount, 250);

      // Ineligible course fails with courseNotEligible status
      final invalidResult = courseProvider.validateCouponDetailed(
        'BPSC_SPECIAL',
        600,
        courseId: 'course_neet_002',
      );
      expect(invalidResult.isValid, isFalse);
      expect(invalidResult.status, CouponValidationStatus.courseNotEligible);
      expect(invalidResult.errorMessage, contains("not eligible for this course"));

      // Standard validateCoupon returns null for ineligible course
      expect(
        courseProvider.validateCoupon('BPSC_SPECIAL', 600, courseId: 'course_neet_002'),
        isNull,
      );
    });

    test('updateCouponEligibleCourses dynamically adds and removes courses', () async {
      const dynamicCoupon = CouponModel(
        code: 'FESTIVE50',
        discountAmount: 200,
        minOrderValue: 500,
        description: 'Festive special',
        isActive: true,
        applicableCourseIds: ['course_a'],
      );

      await courseProvider.addCustomCoupon(dynamicCoupon);

      // Initial: only course_a is eligible
      expect(
        courseProvider.validateCoupon('FESTIVE50', 600, courseId: 'course_a'),
        isNotNull,
      );
      expect(
        courseProvider.validateCoupon('FESTIVE50', 600, courseId: 'course_b'),
        isNull,
      );

      // Admin adds course_b to eligible list
      courseProvider.updateCouponEligibleCourses('FESTIVE50', ['course_a', 'course_b']);

      expect(
        courseProvider.validateCoupon('FESTIVE50', 600, courseId: 'course_b'),
        isNotNull,
      );

      // Admin removes course_a, leaving only course_b
      courseProvider.updateCouponEligibleCourses('FESTIVE50', ['course_b']);

      expect(
        courseProvider.validateCoupon('FESTIVE50', 600, courseId: 'course_a'),
        isNull,
      );
      expect(
        courseProvider.validateCoupon('FESTIVE50', 600, courseId: 'course_b'),
        isNotNull,
      );
    });

    test('toggleCouponCourseEligibility toggles single course on and off', () async {
      const toggleCoupon = CouponModel(
        code: 'TOGGLE10',
        discountAmount: 50,
        minOrderValue: 200,
        description: 'Toggle coupon',
        isActive: true,
        applicableCourseIds: ['course_x'],
      );

      await courseProvider.addCustomCoupon(toggleCoupon);

      // Toggle course_y ON
      courseProvider.toggleCouponCourseEligibility('TOGGLE10', 'course_y');
      expect(
        courseProvider.validateCoupon('TOGGLE10', 300, courseId: 'course_y'),
        isNotNull,
      );

      // Toggle course_y OFF
      courseProvider.toggleCouponCourseEligibility('TOGGLE10', 'course_y');
      expect(
        courseProvider.validateCoupon('TOGGLE10', 300, courseId: 'course_y'),
        isNull,
      );
    });

    test('getCouponsForCourse filters active coupons for given course', () async {
      const coupon1 = CouponModel(
        code: 'FOR_MATH',
        discountAmount: 50,
        minOrderValue: 200,
        description: 'Math coupon',
        isActive: true,
        applicableCourseIds: ['math_course'],
      );

      const coupon2 = CouponModel(
        code: 'FOR_PHYSICS',
        discountAmount: 50,
        minOrderValue: 200,
        description: 'Physics coupon',
        isActive: true,
        applicableCourseIds: ['physics_course'],
      );

      await courseProvider.addCustomCoupon(coupon1);
      await courseProvider.addCustomCoupon(coupon2);

      final mathCoupons = courseProvider.getCouponsForCourse('math_course');
      expect(mathCoupons.any((c) => c.code == 'FOR_MATH'), isTrue);
      expect(mathCoupons.any((c) => c.code == 'FOR_PHYSICS'), isFalse);
    });

    test('100% Free / Full Scholarship coupon makes any course price Rs 0 and bypasses min order', () async {
      const freeCoupon = CouponModel(
        code: 'FREE100_TEST',
        discountAmount: 100,
        discountType: 'percentage',
        minOrderValue: 500, // Even if min order was set, 100% free bypasses it
        description: '100% Scholarship',
        isActive: true,
      );

      await courseProvider.addCustomCoupon(freeCoupon);

      expect(freeCoupon.isFreeCourse, isTrue);
      expect(freeCoupon.calculateDiscount(9.0), 9.0);
      expect(freeCoupon.calculateDiscount(3199.0), 3199.0);

      // Rs 9 course passes even though minOrderValue is 500
      final result = courseProvider.validateCouponDetailed('FREE100_TEST', 9.0);
      expect(result.isValid, isTrue);
      expect(result.status, CouponValidationStatus.valid);
    });
  });
}
