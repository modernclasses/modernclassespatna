import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_classes_patna/core/errors/exceptions.dart';

/// ==============================================================================
/// CLASSIFICATION NOTICE:
/// The tests in this file fall into two distinct offline categories:
/// 1. STATIC CONTRACT TESTS: Inspect local SQL migration scripts for statements,
///    grants, search paths, and database constraints.
/// 2. UNIT TESTS WITH IN-MEMORY SIMULATOR: Exercise business and security logic
///    against pure Dart data structures replicating PostgreSQL / PL/pgSQL behavior.
///
/// NOTE: None of these tests execute against a live PostgreSQL / Supabase server.
/// Real PostgreSQL integration tests require an active database daemon.
/// ==============================================================================

/// Database schema entities for in-memory backend simulation
class SimProfile {
  final String id;
  final String role; // 'student', 'admin', 'teacher'
  SimProfile({required this.id, required this.role});
}

class SimBatch {
  final String id;
  final String courseId;
  final double batchPrice;
  final bool isActive;
  final String? playProductId;

  SimBatch({
    required this.id,
    required this.courseId,
    required this.batchPrice,
    this.isActive = true,
    this.playProductId,
  });
}

class SimCoupon {
  final String id;
  final String code;
  final double discountAmount;
  final String discountType; // 'flat', 'percentage'
  final double minOrderValue;
  final bool isActive;
  final int? maxUses;
  int currentUses;
  final DateTime? expiresAt;

  SimCoupon({
    required this.id,
    required this.code,
    required this.discountAmount,
    this.discountType = 'flat',
    this.minOrderValue = 0,
    this.isActive = true,
    this.maxUses,
    this.currentUses = 0,
    this.expiresAt,
  });
}

class SimCouponRedemption {
  final String id;
  final String couponId;
  final String studentId;
  final String batchId;
  final double discountApplied;
  final DateTime redeemedAt;

  SimCouponRedemption({
    required this.id,
    required this.couponId,
    required this.studentId,
    required this.batchId,
    required this.discountApplied,
    required this.redeemedAt,
  });
}

class SimEnrollment {
  final String id;
  final String studentId;
  final String batchId;
  String? purchaseId;
  String status;

  SimEnrollment({
    required this.id,
    required this.studentId,
    required this.batchId,
    this.purchaseId,
    this.status = 'active',
  });
}

class SimPurchase {
  final String id;
  final String studentId;
  final String storeProductId;
  final String purchaseToken;
  final String orderId;
  final String status;
  final String acknowledgementState;

  SimPurchase({
    required this.id,
    required this.studentId,
    required this.storeProductId,
    required this.purchaseToken,
    required this.orderId,
    required this.status,
    required this.acknowledgementState,
  });
}

/// In-memory authoritative backend simulator matching migration 033 PL/pgSQL RPC
class MockSupabaseBackend {
  final Map<String, SimProfile> profiles = {};
  final Map<String, SimBatch> batches = {};
  final Map<String, SimCoupon> coupons = {};
  final List<SimCouponRedemption> redemptions = [];
  final List<SimEnrollment> enrollments = [];
  final Map<String, SimPurchase> purchases = {};

  String? currentAuthUid;
  String currentAuthRole = 'authenticated'; // 'authenticated', 'anon', 'service_role'

  void seedDefaults() {
    // Profiles
    profiles['student_101'] = SimProfile(id: 'student_101', role: 'student');
    profiles['student_102'] = SimProfile(id: 'student_102', role: 'student');
    profiles['admin_999'] = SimProfile(id: 'admin_999', role: 'admin');

    // Batches
    batches['batch_free_01'] = SimBatch(
      id: 'batch_free_01',
      courseId: 'crs_free',
      batchPrice: 0.0,
      isActive: true,
    );
    batches['batch_paid_999'] = SimBatch(
      id: 'batch_paid_999',
      courseId: 'crs_paid',
      batchPrice: 999.0,
      isActive: true,
      playProductId: 'course_tier_999',
    );
    batches['batch_paid_5000'] = SimBatch(
      id: 'batch_paid_5000',
      courseId: 'crs_bpsc',
      batchPrice: 5000.0,
      isActive: true,
      playProductId: 'course_tier_4999',
    );
    batches['batch_inactive'] = SimBatch(
      id: 'batch_inactive',
      courseId: 'crs_old',
      batchPrice: 500.0,
      isActive: false,
    );

    // Default Seeded Coupons
    coupons['PATNA50'] = SimCoupon(
      id: 'cp_patna50',
      code: 'PATNA50',
      discountAmount: 200,
      minOrderValue: 500,
      isActive: true,
    );
    coupons['WELCOME100'] = SimCoupon(
      id: 'cp_welcome100',
      code: 'WELCOME100',
      discountAmount: 100,
      minOrderValue: 400,
      isActive: true,
    );
    coupons['SCHOLARSHIP100'] = SimCoupon(
      id: 'cp_scholarship100',
      code: 'SCHOLARSHIP100',
      discountAmount: 100,
      discountType: 'percentage',
      minOrderValue: 0,
      isActive: true,
      maxUses: 5,
    );
    coupons['FULLFREE999'] = SimCoupon(
      id: 'cp_fullfree999',
      code: 'FULLFREE999',
      discountAmount: 999,
      discountType: 'flat',
      minOrderValue: 900,
      isActive: true,
      maxUses: 1, // Only 1 use allowed
    );
    coupons['EXPIRED50'] = SimCoupon(
      id: 'cp_expired50',
      code: 'EXPIRED50',
      discountAmount: 1000,
      isActive: true,
      expiresAt: DateTime.now().subtract(const Duration(days: 2)),
    );
    coupons['DISABLED_CODE'] = SimCoupon(
      id: 'cp_disabled',
      code: 'DISABLED_CODE',
      discountAmount: 1000,
      isActive: false,
    );
  }

  bool isAdmin(String? uid) {
    if (uid == null) return false;
    final p = profiles[uid];
    return p != null && p.role == 'admin';
  }

  /// Authoritative PL/pgSQL Simulation of enroll_student_free_or_coupon
  Future<void> enrollStudentFreeOrCoupon({
    required String batchId,
    String? couponCode,
    String? targetStudentId,
  }) async {
    // 1. Authentication Check
    final callingUserId = currentAuthUid;
    if (callingUserId == null) {
      throw const ServerException('Not authenticated');
    }

    // 2. Authorization & Identity Resolution
    final isCallerAdmin = isAdmin(callingUserId);
    final String resolvedStudentId;
    if (targetStudentId != null && targetStudentId != callingUserId) {
      if (!isCallerAdmin) {
        throw const ServerException('Unauthorized: Students can only enroll themselves.');
      }
      resolvedStudentId = targetStudentId;
    } else {
      resolvedStudentId = callingUserId;
    }

    // Verify profile exists
    if (!profiles.containsKey(resolvedStudentId)) {
      throw const ServerException('Target student profile does not exist.');
    }

    // 3. Batch Validation
    final batch = batches[batchId];
    if (batch == null) {
      throw const ServerException('Batch not found.');
    }
    if (!batch.isActive) {
      throw const ServerException('Batch is not active for enrollment.');
    }

    // 4. Idempotency Check
    final existingIndex = enrollments.indexWhere(
      (e) => e.studentId == resolvedStudentId && e.batchId == batchId,
    );
    if (existingIndex != -1 && enrollments[existingIndex].status == 'active') {
      // Idempotent return without consuming coupon or double-enrolling
      return;
    }

    // 5. Price & Coupon Verification
    if (batch.batchPrice <= 0) {
      // Legitimately free batch
    } else {
      if (couponCode == null || couponCode.trim().isEmpty) {
        throw ServerException(
          'Batch is not free (Price: ₹${batch.batchPrice.toInt()}). A valid 100% discount coupon is required for free enrollment.',
        );
      }

      // Lock row simulation: fetch coupon
      final cleanCode = couponCode.trim().toUpperCase();
      final coupon = coupons[cleanCode];

      if (coupon == null) {
        throw ServerException('Invalid coupon code: $couponCode');
      }

      if (!coupon.isActive) {
        throw const ServerException('Coupon is disabled or inactive.');
      }

      if (coupon.expiresAt != null && coupon.expiresAt!.isBefore(DateTime.now())) {
        throw const ServerException('Coupon has expired.');
      }

      if (coupon.minOrderValue > 0 && batch.batchPrice < coupon.minOrderValue) {
        throw ServerException(
          'Minimum order value of ₹${coupon.minOrderValue.toInt()} required to use this coupon.',
        );
      }

      if (coupon.maxUses != null && coupon.currentUses >= coupon.maxUses!) {
        throw const ServerException('Coupon usage limit has been reached.');
      }

      // Single-use per batch per student check
      final alreadyRedeemed = redemptions.any(
        (r) => r.couponId == coupon.id && r.studentId == resolvedStudentId && r.batchId == batchId,
      );
      if (alreadyRedeemed) {
        throw const ServerException('Coupon has already been redeemed by this student for this batch.');
      }

      // Calculate discount
      final double discount;
      if (coupon.discountType == 'percentage') {
        discount = (batch.batchPrice * coupon.discountAmount / 100.0);
      } else {
        discount = coupon.discountAmount;
      }

      final double finalPayable = (batch.batchPrice - discount).clamp(0.0, double.infinity);

      if (finalPayable > 0) {
        throw ServerException(
          'Coupon provides a partial discount (₹${discount.toInt()}). Remaining payable balance is ₹${finalPayable.toInt()}. Partial discounts must be paid via Google Play Billing.',
        );
      }

      // Record coupon redemption & increment usage
      redemptions.add(
        SimCouponRedemption(
          id: 'redemption_${DateTime.now().microsecondsSinceEpoch}',
          couponId: coupon.id,
          studentId: resolvedStudentId,
          batchId: batchId,
          discountApplied: discount,
          redeemedAt: DateTime.now(),
        ),
      );
      coupon.currentUses += 1;
    }

    // 6. Upsert Enrollment
    if (existingIndex != -1) {
      enrollments[existingIndex].status = 'active';
    } else {
      enrollments.add(
        SimEnrollment(
          id: 'enr_${DateTime.now().microsecondsSinceEpoch}',
          studentId: resolvedStudentId,
          batchId: batchId,
          status: 'active',
        ),
      );
    }
  }

  /// Authoritative PL/pgSQL Simulation of record_verified_purchase_and_enroll
  Future<String> recordVerifiedPurchaseAndEnroll({
    required String studentId,
    required String storeProductId,
    required String purchaseToken,
    required String orderId,
    required String status,
    required String acknowledgementState,
    String? batchId,
  }) async {
    // 1. Role Boundary: Must be service_role
    if (currentAuthRole == 'authenticated' || currentAuthRole == 'anon') {
      throw const ServerException(
        'Access denied: record_verified_purchase_and_enroll can only be invoked by service_role.',
      );
    }

    // 2. Resolve batch
    final SimBatch? resolvedBatch;
    if (batchId != null) {
      resolvedBatch = batches[batchId];
    } else {
      resolvedBatch = batches.values.cast<SimBatch?>().firstWhere(
            (b) => b?.playProductId == storeProductId && b?.isActive == true,
            orElse: () => null,
          );
    }

    if (resolvedBatch == null || !resolvedBatch.isActive) {
      throw ServerException('No active batch found for product: $storeProductId / batch: $batchId');
    }

    final targetBatch = resolvedBatch;

    // 3. Purchase record with cross-batch replay check
    var purchase = purchases[purchaseToken];
    if (purchase == null) {
      purchase = SimPurchase(
        id: 'pur_${purchaseToken.hashCode}',
        studentId: studentId,
        storeProductId: storeProductId,
        purchaseToken: purchaseToken,
        orderId: orderId,
        status: status,
        acknowledgementState: acknowledgementState,
      );
      purchases[purchaseToken] = purchase;
    } else {
      // Token belongs to another student?
      if (purchase.studentId != studentId) {
        throw const ServerException('Purchase token is already bound to a different student.');
      }

      // Token already redeemed for a different batch?
      final existingBoundEnrollment = enrollments.where(
        (e) => e.purchaseId == purchase!.id,
      ).firstOrNull;

      if (existingBoundEnrollment != null && existingBoundEnrollment.batchId != targetBatch.id) {
        throw const ServerException(
          'This purchase token has already been redeemed for a different batch.',
        );
      }
    }

    // 4. Enroll
    final existingIdx = enrollments.indexWhere(
      (e) => e.studentId == studentId && e.batchId == targetBatch.id,
    );
    if (existingIdx != -1) {
      enrollments[existingIdx].status = 'active';
      enrollments[existingIdx].purchaseId = purchase.id;
    } else {
      // Invariant: Unique index check simulation on purchase_id
      final duplicatePurchaseEnrollment = enrollments.where(
        (e) => e.purchaseId == purchase!.id && e.batchId != targetBatch.id,
      ).firstOrNull;

      if (duplicatePurchaseEnrollment != null) {
        throw const ServerException(
          'Database constraint violation: duplicate purchase_id on enrollments.',
        );
      }

      enrollments.add(
        SimEnrollment(
          id: 'enr_${DateTime.now().microsecondsSinceEpoch}',
          studentId: studentId,
          batchId: targetBatch.id,
          purchaseId: purchase.id,
          status: 'active',
        ),
      );
    }

    return purchase.id;
  }
}

void main() {
  group('[STATIC CONTRACT TEST] Migration 033 SQL Static File, Security & Grants', () {
    test('Migration 033 drops legacy 7-parameter overload', () {
      final file = File('supabase/migrations/033_course_tiers_and_coupon_enrollment.sql');
      expect(file.existsSync(), isTrue, reason: 'Migration 033 file must exist locally.');
      final sql = file.readAsStringSync();

      expect(
        sql.contains('DROP FUNCTION IF EXISTS public.record_verified_purchase_and_enroll(UUID, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT, TEXT);'),
        isTrue,
        reason: 'Must drop legacy 7-param overload to prevent attack surface.',
      );
    });

    test('Migration 033 restricts record_verified_purchase_and_enroll strictly to service_role', () {
      final file = File('supabase/migrations/033_course_tiers_and_coupon_enrollment.sql');
      final sql = file.readAsStringSync();

      // Revoke from PUBLIC, anon, and authenticated
      expect(
        sql.contains('REVOKE ALL ON FUNCTION public.record_verified_purchase_and_enroll(UUID, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT, TEXT, UUID) FROM PUBLIC, anon, authenticated;'),
        isTrue,
        reason: 'Must revoke execute from PUBLIC, anon, and authenticated.',
      );

      // Grant strictly to service_role
      expect(
        sql.contains('GRANT EXECUTE ON FUNCTION public.record_verified_purchase_and_enroll(UUID, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT, TEXT, UUID) TO service_role;'),
        isTrue,
        reason: 'Only service_role may be granted execute on purchase enrollment.',
      );

      // Does NOT grant record_verified_purchase_and_enroll to authenticated
      expect(
        sql.contains('record_verified_purchase_and_enroll(UUID, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT, TEXT, UUID) TO authenticated'),
        isFalse,
        reason: 'Must NOT grant record_verified_purchase_and_enroll to authenticated role.',
      );

      // Defense-in-depth role check in function body
      expect(
        sql.contains("IF auth.role() = 'authenticated' OR auth.role() = 'anon' THEN"),
        isTrue,
        reason: 'Must contain internal role check rejecting authenticated/anon callers.',
      );
    });

    test('Migration 033 enforces partial unique index on enrollments purchase_id', () {
      final file = File('supabase/migrations/033_course_tiers_and_coupon_enrollment.sql');
      final sql = file.readAsStringSync();

      expect(
        sql.contains('CREATE UNIQUE INDEX IF NOT EXISTS idx_enrollments_unique_purchase_id'),
        isTrue,
      );
      expect(
        sql.contains('ON public.enrollments(purchase_id)'),
        isTrue,
      );
      expect(
        sql.contains('WHERE purchase_id IS NOT NULL;'),
        isTrue,
        reason: 'Must be partial index allowing multiple nulls for free enrollments.',
      );
    });

    test('Migration 033 hardens search_path on all SECURITY DEFINER functions', () {
      final file = File('supabase/migrations/033_course_tiers_and_coupon_enrollment.sql');
      final sql = file.readAsStringSync();

      // Both functions must set search_path
      final count = 'SET search_path = public, pg_temp;'.allMatches(sql).length;
      expect(count, greaterThanOrEqualTo(2), reason: 'Both SECURITY DEFINER functions must set fixed search_path');
    });

    test('Migration 033 prevents cross-batch token replay in purchase verification', () {
      final file = File('supabase/migrations/033_course_tiers_and_coupon_enrollment.sql');
      final sql = file.readAsStringSync();

      expect(
        sql.contains('v_bound_batch_id != v_batch_id'),
        isTrue,
        reason: 'Must check if purchase record is already linked to a different batch.',
      );
      expect(
        sql.contains('FOR UPDATE'),
        isTrue,
        reason: 'Must acquire row lock on purchases table against race conditions.',
      );
    });
  });

  group('[IN-MEMORY DART SIMULATOR] Free and Coupon-Based Enrollment Verification', () {
    late MockSupabaseBackend backend;

    setUp(() {
      backend = MockSupabaseBackend();
      backend.seedDefaults();
      backend.currentAuthUid = 'student_101';
      backend.currentAuthRole = 'authenticated';
    });

    test('1. Paid batch with no coupon is rejected', () async {
      expect(
        () => backend.enrollStudentFreeOrCoupon(batchId: 'batch_paid_999', couponCode: null),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains('Batch is not free (Price: ₹999). A valid 100% discount coupon is required'),
          ),
        ),
      );
      expect(backend.enrollments.isEmpty, isTrue);
    });

    test('2. Paid batch with an invalid coupon is rejected', () async {
      expect(
        () => backend.enrollStudentFreeOrCoupon(
          batchId: 'batch_paid_999',
          couponCode: 'FAKE_COUPON_123',
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains('Invalid coupon code: FAKE_COUPON_123'),
          ),
        ),
      );
      expect(backend.enrollments.isEmpty, isTrue);
    });

    test('3. Legitimately free batch succeeds without any coupon', () async {
      await backend.enrollStudentFreeOrCoupon(batchId: 'batch_free_01');

      expect(backend.enrollments.length, 1);
      final enr = backend.enrollments.first;
      expect(enr.studentId, 'student_101');
      expect(enr.batchId, 'batch_free_01');
      expect(enr.status, 'active');
      expect(backend.redemptions.isEmpty, isTrue, reason: 'Free batch does not consume coupons');
    });

    test('4. Valid 100% coupon reducing payable amount to zero succeeds', () async {
      await backend.enrollStudentFreeOrCoupon(
        batchId: 'batch_paid_999',
        couponCode: 'SCHOLARSHIP100',
      );

      expect(backend.enrollments.length, 1);
      final enr = backend.enrollments.first;
      expect(enr.studentId, 'student_101');
      expect(enr.batchId, 'batch_paid_999');
      expect(enr.status, 'active');

      // Verify redemption audit log and counter
      expect(backend.redemptions.length, 1);
      final red = backend.redemptions.first;
      expect(red.studentId, 'student_101');
      expect(red.batchId, 'batch_paid_999');
      expect(red.discountApplied, 999.0);

      final coupon = backend.coupons['SCHOLARSHIP100']!;
      expect(coupon.currentUses, 1);
    });

    test('5. Expired coupon is rejected', () async {
      expect(
        () => backend.enrollStudentFreeOrCoupon(
          batchId: 'batch_paid_999',
          couponCode: 'EXPIRED50',
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains('Coupon has expired'),
          ),
        ),
      );
      expect(backend.enrollments.isEmpty, isTrue);
    });

    test('6. Disabled coupon is rejected', () async {
      expect(
        () => backend.enrollStudentFreeOrCoupon(
          batchId: 'batch_paid_999',
          couponCode: 'DISABLED_CODE',
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains('Coupon is disabled or inactive'),
          ),
        ),
      );
      expect(backend.enrollments.isEmpty, isTrue);
    });

    test('7. Coupon below minimum order value is rejected', () async {
      backend.coupons['MIN1000'] = SimCoupon(
        id: 'cp_min1000',
        code: 'MIN1000',
        discountAmount: 999,
        minOrderValue: 1000,
        isActive: true,
      );

      expect(
        () => backend.enrollStudentFreeOrCoupon(
          batchId: 'batch_paid_999',
          couponCode: 'MIN1000',
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains('Minimum order value of ₹1000 required to use this coupon'),
          ),
        ),
      );
    });

    test('8. Coupon usage limit reached is rejected', () async {
      final coupon = backend.coupons['FULLFREE999']!;
      coupon.currentUses = 1; // maxUses is 1

      expect(
        () => backend.enrollStudentFreeOrCoupon(
          batchId: 'batch_paid_999',
          couponCode: 'FULLFREE999',
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains('Coupon usage limit has been reached'),
          ),
        ),
      );
      expect(backend.enrollments.isEmpty, isTrue);
    });

    test('9. Two simultaneous redemptions competing for the final allowed use', () async {
      final coupon = backend.coupons['FULLFREE999']!;
      expect(coupon.maxUses, 1);
      expect(coupon.currentUses, 0);

      // Student 101 enrolls first
      backend.currentAuthUid = 'student_101';
      await backend.enrollStudentFreeOrCoupon(
        batchId: 'batch_paid_999',
        couponCode: 'FULLFREE999',
      );
      expect(coupon.currentUses, 1);
      expect(backend.enrollments.length, 1);

      // Student 102 attempts to use the same coupon competing for final use
      backend.currentAuthUid = 'student_102';
      expect(
        () => backend.enrollStudentFreeOrCoupon(
          batchId: 'batch_paid_999',
          couponCode: 'FULLFREE999',
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains('Coupon usage limit has been reached'),
          ),
        ),
      );

      // Exactly 1 redemption recorded
      expect(coupon.currentUses, 1);
      expect(backend.redemptions.length, 1);
      expect(backend.enrollments.length, 1);
    });

    test('10. Duplicate RPC calls are idempotent and do not consume coupon twice', () async {
      final coupon = backend.coupons['SCHOLARSHIP100']!;
      expect(coupon.currentUses, 0);

      // First call
      await backend.enrollStudentFreeOrCoupon(
        batchId: 'batch_paid_999',
        couponCode: 'SCHOLARSHIP100',
      );
      expect(backend.enrollments.length, 1);
      expect(coupon.currentUses, 1);
      expect(backend.redemptions.length, 1);

      // Duplicate second call
      await backend.enrollStudentFreeOrCoupon(
        batchId: 'batch_paid_999',
        couponCode: 'SCHOLARSHIP100',
      );

      // Remains exactly 1 enrollment and 1 redemption
      expect(backend.enrollments.length, 1);
      expect(coupon.currentUses, 1, reason: 'Duplicate RPC must not increment coupon usage count');
      expect(backend.redemptions.length, 1, reason: 'Duplicate RPC must not create duplicate redemption record');
    });

    test('11. Attempts to supply another student ID by non-admin is rejected', () async {
      backend.currentAuthUid = 'student_101';

      expect(
        () => backend.enrollStudentFreeOrCoupon(
          batchId: 'batch_free_01',
          targetStudentId: 'student_102',
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains('Unauthorized: Students can only enroll themselves.'),
          ),
        ),
      );
      expect(backend.enrollments.isEmpty, isTrue);

      // But Admin can enroll student_102
      backend.currentAuthUid = 'admin_999';
      await backend.enrollStudentFreeOrCoupon(
        batchId: 'batch_free_01',
        targetStudentId: 'student_102',
      );
      expect(backend.enrollments.length, 1);
      expect(backend.enrollments.first.studentId, 'student_102');
    });

    test('12. Direct calls by unauthenticated users are rejected', () async {
      backend.currentAuthUid = null;

      expect(
        () => backend.enrollStudentFreeOrCoupon(batchId: 'batch_free_01'),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains('Not authenticated'),
          ),
        ),
      );
      expect(backend.enrollments.isEmpty, isTrue);
    });

    test('13. Partial discount coupon passed to free RPC is rejected', () async {
      expect(
        () => backend.enrollStudentFreeOrCoupon(
          batchId: 'batch_paid_999',
          couponCode: 'PATNA50',
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains('Coupon provides a partial discount (₹200). Remaining payable balance is ₹799. Partial discounts must be paid via Google Play Billing.'),
          ),
        ),
      );
      expect(backend.enrollments.isEmpty, isTrue);
      expect(backend.redemptions.isEmpty, isTrue);
    });

    test('14. Inactive batch enrollment is rejected', () async {
      expect(
        () => backend.enrollStudentFreeOrCoupon(
          batchId: 'batch_inactive',
          couponCode: 'SCHOLARSHIP100',
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains('Batch is not active for enrollment'),
          ),
        ),
      );
      expect(backend.enrollments.isEmpty, isTrue);
    });
  });

  group('[IN-MEMORY DART SIMULATOR] Paid Google Play Purchase Verification & Replay Protection', () {
    late MockSupabaseBackend backend;

    setUp(() {
      backend = MockSupabaseBackend();
      backend.seedDefaults();
      backend.currentAuthUid = 'student_101';
      backend.currentAuthRole = 'service_role'; // Trusted Edge Function caller
    });

    test('15. Direct call to record_verified_purchase_and_enroll by authenticated student is blocked', () async {
      backend.currentAuthRole = 'authenticated'; // Untrusted client

      expect(
        () => backend.recordVerifiedPurchaseAndEnroll(
          studentId: 'student_101',
          storeProductId: 'course_tier_999',
          purchaseToken: 'play_token_fake_123',
          orderId: 'GPA.0000-0000',
          status: 'purchased',
          acknowledgementState: 'acknowledged',
          batchId: 'batch_paid_999',
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains('Access denied: record_verified_purchase_and_enroll can only be invoked by service_role.'),
          ),
        ),
      );
      expect(backend.enrollments.isEmpty, isTrue);
    });

    test('16. Valid purchase via service_role successfully enrolls student', () async {
      backend.currentAuthRole = 'service_role';

      final purchaseId = await backend.recordVerifiedPurchaseAndEnroll(
        studentId: 'student_101',
        storeProductId: 'course_tier_999',
        purchaseToken: 'play_token_valid_999',
        orderId: 'GPA.1234-5678-9012',
        status: 'purchased',
        acknowledgementState: 'acknowledged',
        batchId: 'batch_paid_999',
      );

      expect(purchaseId, isNotEmpty);
      expect(backend.enrollments.length, 1);
      final enr = backend.enrollments.first;
      expect(enr.studentId, 'student_101');
      expect(enr.batchId, 'batch_paid_999');
      expect(enr.status, 'active');
      expect(enr.purchaseId, purchaseId);
    });

    test('17. Same purchase token CANNOT be replayed across a different batch by same student', () async {
      backend.currentAuthRole = 'service_role';

      // Legitimate purchase for Batch 1
      await backend.recordVerifiedPurchaseAndEnroll(
        studentId: 'student_101',
        storeProductId: 'course_tier_999',
        purchaseToken: 'play_token_cross_batch',
        orderId: 'GPA.1111-2222',
        status: 'purchased',
        acknowledgementState: 'acknowledged',
        batchId: 'batch_paid_999',
      );
      expect(backend.enrollments.length, 1);

      // Attacker attempts to reuse the same purchase token for Batch 2
      expect(
        () => backend.recordVerifiedPurchaseAndEnroll(
          studentId: 'student_101',
          storeProductId: 'course_tier_4999',
          purchaseToken: 'play_token_cross_batch', // Replayed token
          orderId: 'GPA.1111-2222',
          status: 'purchased',
          acknowledgementState: 'acknowledged',
          batchId: 'batch_paid_5000',
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains('This purchase token has already been redeemed for a different batch.'),
          ),
        ),
      );

      // Remains only 1 enrollment for Batch 1
      expect(backend.enrollments.length, 1);
      expect(backend.enrollments.first.batchId, 'batch_paid_999');
    });

    test('18. Same purchase token cannot be claimed by a different student', () async {
      backend.currentAuthRole = 'service_role';

      // Student 101 purchases
      await backend.recordVerifiedPurchaseAndEnroll(
        studentId: 'student_101',
        storeProductId: 'course_tier_999',
        purchaseToken: 'play_token_unique_101',
        orderId: 'GPA.3333-4444',
        status: 'purchased',
        acknowledgementState: 'acknowledged',
        batchId: 'batch_paid_999',
      );

      // Student 102 attempts to claim Student 101's token
      expect(
        () => backend.recordVerifiedPurchaseAndEnroll(
          studentId: 'student_102',
          storeProductId: 'course_tier_999',
          purchaseToken: 'play_token_unique_101',
          orderId: 'GPA.3333-4444',
          status: 'purchased',
          acknowledgementState: 'acknowledged',
          batchId: 'batch_paid_999',
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains('Purchase token is already bound to a different student.'),
          ),
        ),
      );
    });

    test('19. Duplicate call for SAME batch and SAME student is idempotent safe retry', () async {
      backend.currentAuthRole = 'service_role';

      final id1 = await backend.recordVerifiedPurchaseAndEnroll(
        studentId: 'student_101',
        storeProductId: 'course_tier_999',
        purchaseToken: 'play_token_retry',
        orderId: 'GPA.5555-6666',
        status: 'purchased',
        acknowledgementState: 'acknowledged',
        batchId: 'batch_paid_999',
      );

      // Safe retry for same batch
      final id2 = await backend.recordVerifiedPurchaseAndEnroll(
        studentId: 'student_101',
        storeProductId: 'course_tier_999',
        purchaseToken: 'play_token_retry',
        orderId: 'GPA.5555-6666',
        status: 'purchased',
        acknowledgementState: 'acknowledged',
        batchId: 'batch_paid_999',
      );

      expect(id1, id2);
      expect(backend.enrollments.length, 1);
      expect(backend.purchases.length, 1);
    });

    test('20. Multiple free enrollments with null purchase_id coexist safely', () async {
      // Student 101 free enroll
      backend.currentAuthUid = 'student_101';
      await backend.enrollStudentFreeOrCoupon(batchId: 'batch_free_01');

      // Student 102 free enroll in same batch
      backend.currentAuthUid = 'student_102';
      await backend.enrollStudentFreeOrCoupon(batchId: 'batch_free_01');

      expect(backend.enrollments.length, 2);
      expect(backend.enrollments[0].purchaseId, isNull);
      expect(backend.enrollments[1].purchaseId, isNull);
    });
  });
}
