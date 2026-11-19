-- ==============================================================================
-- Migration: 069_fix_free_coupon_revenue_ledger.sql
-- Description: 1. Update enroll_student_free_or_coupon to insert a zero-amount
--                 audit transaction in public.transactions on free enrollment.
--              2. Update get_admin_manual_collections_total to strictly exclude
--                 free/coupon enrollments from gross & net revenue calculation.
--              3. Backfill missing zero-amount transaction rows for past free coupon
--                 redemptions so revenue and ledger are 100% accurate.
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. Upgrade enroll_student_free_or_coupon to record zero-revenue transaction
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enroll_student_free_or_coupon(
    p_batch_id UUID,
    p_coupon_code TEXT DEFAULT NULL,
    p_target_student_id UUID DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_calling_user_id UUID;
    v_target_student_id UUID;
    v_is_admin BOOLEAN;
    v_batch RECORD;
    v_coupon RECORD;
    v_existing_enrollment RECORD;
    v_discount NUMERIC := 0;
    v_final_payable NUMERIC := 0;
    v_is_100_percent_free BOOLEAN := false;
    v_student_name TEXT;
    v_course_title TEXT;
BEGIN
    -- 1. Authentication Check
    v_calling_user_id := auth.uid();
    IF v_calling_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- 2. Authorization & Identity Resolution
    v_is_admin := public.is_admin();

    IF p_target_student_id IS NOT NULL AND p_target_student_id != v_calling_user_id THEN
        -- Only admin can enroll another student
        IF NOT v_is_admin THEN
            RAISE EXCEPTION 'Unauthorized: Students can only enroll themselves.';
        END IF;
        v_target_student_id := p_target_student_id;
    ELSE
        -- Authoritative self-enrollment
        v_target_student_id := v_calling_user_id;
    END IF;

    -- Verify the target student profile exists
    IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_target_student_id) THEN
        RAISE EXCEPTION 'Target student profile does not exist.';
    END IF;

    -- 3. Batch Validation
    SELECT id, course_id, batch_price, name, is_active 
    INTO v_batch 
    FROM public.batches 
    WHERE id = p_batch_id;

    IF v_batch.id IS NULL THEN
        RAISE EXCEPTION 'Batch not found.';
    END IF;

    IF v_batch.is_active IS NOT TRUE THEN
        RAISE EXCEPTION 'Batch is not active for enrollment.';
    END IF;

    -- 4. Idempotency Check: Already active enrollment?
    SELECT id, status INTO v_existing_enrollment
    FROM public.enrollments
    WHERE student_id = v_target_student_id AND batch_id = p_batch_id;

    IF v_existing_enrollment.id IS NOT NULL AND v_existing_enrollment.status = 'active' THEN
        -- Already actively enrolled: idempotent return
        RETURN;
    END IF;

    -- 5. Price & Coupon Verification
    IF v_batch.batch_price <= 0 THEN
        v_final_payable := 0;
    ELSE
        IF p_coupon_code IS NULL OR trim(p_coupon_code) = '' THEN
            RAISE EXCEPTION 'Batch is not free (Price: ₹%). A valid 100%% discount coupon is required for free enrollment.', v_batch.batch_price;
        END IF;

        SELECT * INTO v_coupon
        FROM public.coupons
        WHERE upper(code) = upper(trim(p_coupon_code))
        FOR UPDATE;

        IF v_coupon.id IS NULL THEN
            RAISE EXCEPTION 'Invalid coupon code: %', p_coupon_code;
        END IF;

        IF v_coupon.is_active IS NOT TRUE THEN
            RAISE EXCEPTION 'Coupon is disabled or inactive.';
        END IF;

        IF v_coupon.expires_at IS NOT NULL AND v_coupon.expires_at < TIMEZONE('utc', NOW()) THEN
            RAISE EXCEPTION 'Coupon has expired.';
        END IF;

        IF (v_coupon.discount_type = 'percentage' AND v_coupon.discount_amount >= 100) OR v_coupon.discount_amount >= 99999 THEN
            v_is_100_percent_free := true;
        END IF;

        IF NOT v_is_100_percent_free AND v_coupon.min_order_value > 0 AND v_batch.batch_price < v_coupon.min_order_value THEN
            RAISE EXCEPTION 'Minimum order value of ₹% required to use this coupon.', v_coupon.min_order_value;
        END IF;

        IF v_coupon.applicable_course_ids IS NOT NULL AND cardinality(v_coupon.applicable_course_ids) > 0 THEN
            IF NOT (v_batch.course_id = ANY(v_coupon.applicable_course_ids)) THEN
                RAISE EXCEPTION 'Coupon % is not eligible for this course.', p_coupon_code;
            END IF;
        END IF;

        IF v_coupon.max_uses IS NOT NULL AND v_coupon.current_uses >= v_coupon.max_uses THEN
            RAISE EXCEPTION 'Coupon usage limit has been reached.';
        END IF;

        IF EXISTS (
            SELECT 1 FROM public.coupon_redemptions 
            WHERE coupon_id = v_coupon.id 
              AND student_id = v_target_student_id 
              AND batch_id = p_batch_id
        ) THEN
            RAISE EXCEPTION 'Coupon has already been redeemed by this student for this batch.';
        END IF;

        IF v_is_100_percent_free THEN
            v_discount := v_batch.batch_price;
            v_final_payable := 0;
        ELSIF v_coupon.discount_type = 'percentage' THEN
            v_discount := ROUND((v_batch.batch_price * v_coupon.discount_amount / 100.0), 2);
            v_final_payable := GREATEST(0, v_batch.batch_price - v_discount);
        ELSE
            v_discount := v_coupon.discount_amount;
            v_final_payable := GREATEST(0, v_batch.batch_price - v_discount);
        END IF;

        IF v_final_payable > 0 THEN
            RAISE EXCEPTION 'Coupon provides a partial discount (₹%). Remaining payable balance is ₹%. Partial discounts must be paid via Google Play Billing.', v_discount, v_final_payable;
        END IF;

        -- Record coupon redemption & increment usage
        INSERT INTO public.coupon_redemptions (
            coupon_id, student_id, batch_id, discount_applied
        ) VALUES (
            v_coupon.id, v_target_student_id, p_batch_id, v_discount
        );

        UPDATE public.coupons
        SET current_uses = current_uses + 1,
            updated_at = TIMEZONE('utc', NOW())
        WHERE id = v_coupon.id;
    END IF;

    -- 6. Upsert Enrollment
    INSERT INTO public.enrollments (
        student_id, batch_id, status
    ) VALUES (
        v_target_student_id, p_batch_id, 'active'
    ) ON CONFLICT (student_id, batch_id) DO UPDATE SET 
        status = 'active';

    -- 7. Atomic Zero-Amount Transaction Ledger Entry
    -- Ensures Admin Ledger accurately reflects "₹0.00 (Free Coupon)" and does NOT inflate revenue totals.
    SELECT full_name INTO v_student_name FROM public.profiles WHERE id = v_target_student_id;
    SELECT title INTO v_course_title FROM public.courses WHERE id = v_batch.course_id;

    INSERT INTO public.transactions (
        invoice_number,
        student_id,
        student_name,
        course_id,
        course_title,
        amount_paid,
        payment_method,
        transaction_reference,
        status,
        created_at
    ) VALUES (
        'INV-FREE-' || LPAD(FLOOR(RANDOM() * 900000 + 100000)::TEXT, 6, '0') || '-' || SUBSTRING(gen_random_uuid()::TEXT FROM 1 FOR 4),
        v_target_student_id,
        COALESCE(v_student_name, 'Enrolled Student'),
        v_batch.course_id,
        COALESCE(v_course_title, v_batch.name, 'Enrolled Course'),
        0.00,
        CASE 
            WHEN p_coupon_code IS NOT NULL AND TRIM(p_coupon_code) != '' THEN 'Free Coupon (' || UPPER(TRIM(p_coupon_code)) || ')'
            ELSE 'Free Batch Enrollment'
        END,
        'COUPON-' || UPPER(SUBSTRING(gen_random_uuid()::TEXT FROM 1 FOR 8)),
        'success'::public.payment_status,
        TIMEZONE('utc', NOW())
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.enroll_student_free_or_coupon(UUID, TEXT, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.enroll_student_free_or_coupon(UUID, TEXT, UUID) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 2. Upgrade get_admin_manual_collections_total to exclude free/coupon enrollments
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_admin_manual_collections_total()
RETURNS NUMERIC AS $$
DECLARE
    v_tx_total NUMERIC := 0;
    v_enrollment_total NUMERIC := 0;
    v_total NUMERIC := 0;
BEGIN
    IF public.is_admin() IS NOT TRUE THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required';
    END IF;

    -- 1. Sum actual money paid from transactions (Free coupons have amount_paid = 0.00)
    SELECT COALESCE(pg_catalog.sum(amount_paid), 0.00) INTO v_tx_total
    FROM public.transactions
    WHERE status = 'success'::public.payment_status;

    -- 2. Fallback sum from active enrollments whose batch_price > 0:
    -- EXCLUDE enrollments with existing transactions
    -- EXCLUDE enrollments redeemed with free coupons or full scholarships
    SELECT COALESCE(pg_catalog.sum(b.batch_price), 0.00) INTO v_enrollment_total
    FROM public.enrollments e
    JOIN public.batches b ON b.id = e.batch_id
    WHERE e.status = 'active'
      AND b.batch_price > 0
      AND NOT EXISTS (
          SELECT 1 FROM public.transactions t 
          WHERE t.student_id = e.student_id 
            AND t.status = 'success'::public.payment_status
            AND t.course_id = b.course_id
      )
      AND NOT EXISTS (
          SELECT 1 FROM public.coupon_redemptions cr
          WHERE cr.student_id = e.student_id
            AND cr.batch_id = e.batch_id
            AND cr.discount_applied >= b.batch_price
      );

    v_total := v_tx_total + v_enrollment_total;
    RETURN v_total;
END;
$$ LANGUAGE plpgsql 
SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.get_admin_manual_collections_total() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_admin_manual_collections_total() TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 3. Backfill zero-revenue transactions for past 100% coupon redemptions
-- ------------------------------------------------------------------------------
INSERT INTO public.transactions (
    invoice_number,
    student_id,
    student_name,
    course_id,
    course_title,
    amount_paid,
    payment_method,
    transaction_reference,
    status,
    created_at
)
SELECT 
    'INV-FREE-' || LPAD(FLOOR(RANDOM() * 900000 + 100000)::TEXT, 6, '0') || '-' || SUBSTRING(gen_random_uuid()::TEXT FROM 1 FOR 4),
    cr.student_id,
    COALESCE(p.full_name, 'Enrolled Student'),
    b.course_id,
    COALESCE(c.title, b.name, 'Enrolled Course'),
    0.00,
    'Free Coupon (' || COALESCE(cp.code, 'FREE100') || ')',
    'COUPON-' || UPPER(SUBSTRING(gen_random_uuid()::TEXT FROM 1 FOR 8)),
    'success'::public.payment_status,
    cr.redeemed_at
FROM public.coupon_redemptions cr
JOIN public.batches b ON b.id = cr.batch_id
JOIN public.courses c ON c.id = b.course_id
LEFT JOIN public.profiles p ON p.id = cr.student_id
LEFT JOIN public.coupons cp ON cp.id = cr.coupon_id
WHERE cr.discount_applied >= b.batch_price
  AND NOT EXISTS (
      SELECT 1 FROM public.transactions t
      WHERE t.student_id = cr.student_id
        AND t.course_id = b.course_id
  );

COMMIT;
