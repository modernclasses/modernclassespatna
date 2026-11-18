-- ==============================================================================
-- Migration 055: Coupon Course Eligibility
-- Enables coupons to be restricted to specific courses or applicable to all courses.
-- ==============================================================================

-- 1. Add applicable_course_ids column to public.coupons
-- NULL or empty array means the coupon is eligible for ALL courses.
-- Non-empty array contains the list of course UUIDs this coupon can be redeemed for.
ALTER TABLE public.coupons 
ADD COLUMN IF NOT EXISTS applicable_course_ids UUID[] DEFAULT NULL;

-- 2. GIN Index for rapid array containment lookups
CREATE INDEX IF NOT EXISTS idx_coupons_applicable_course_ids 
ON public.coupons USING GIN(applicable_course_ids) 
WHERE applicable_course_ids IS NOT NULL;

-- 3. Update enroll_student_free_or_coupon RPC to check course eligibility
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
        -- Authoritative self-enrollment (client-supplied ID is never blindly trusted)
        v_target_student_id := v_calling_user_id;
    END IF;

    -- Verify the target student profile exists
    IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = v_target_student_id) THEN
        RAISE EXCEPTION 'Target student profile does not exist.';
    END IF;

    -- 3. Batch Validation
    SELECT id, course_id, batch_price, is_active 
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
        -- Already actively enrolled: idempotent return, do NOT re-consume coupon
        RETURN;
    END IF;

    -- 5. Price & Coupon Verification
    IF v_batch.batch_price <= 0 THEN
        -- Batch is legitimately free (Price: ₹0)
        v_final_payable := 0;
    ELSE
        -- Batch is paid (batch_price > 0). Requires valid 100% coupon to enroll via this free RPC.
        IF p_coupon_code IS NULL OR trim(p_coupon_code) = '' THEN
            RAISE EXCEPTION 'Batch is not free (Price: ₹%). A valid 100%% discount coupon is required for free enrollment.', v_batch.batch_price;
        END IF;

        -- Fetch and lock coupon row FOR UPDATE to prevent concurrent race conditions exceeding max_uses
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

        IF v_coupon.min_order_value > 0 AND v_batch.batch_price < v_coupon.min_order_value THEN
            RAISE EXCEPTION 'Minimum order value of ₹% required to use this coupon.', v_coupon.min_order_value;
        END IF;

        -- 5a. Enforce Course Eligibility
        IF v_coupon.applicable_course_ids IS NOT NULL AND cardinality(v_coupon.applicable_course_ids) > 0 THEN
            IF NOT (v_batch.course_id = ANY(v_coupon.applicable_course_ids)) THEN
                RAISE EXCEPTION 'Coupon % is not eligible for this course.', p_coupon_code;
            END IF;
        END IF;

        IF v_coupon.max_uses IS NOT NULL AND v_coupon.current_uses >= v_coupon.max_uses THEN
            RAISE EXCEPTION 'Coupon usage limit has been reached.';
        END IF;

        -- Check if student already redeemed this coupon for this batch
        IF EXISTS (
            SELECT 1 FROM public.coupon_redemptions 
            WHERE coupon_id = v_coupon.id 
              AND student_id = v_target_student_id 
              AND batch_id = p_batch_id
        ) THEN
            RAISE EXCEPTION 'Coupon has already been redeemed by this student for this batch.';
        END IF;

        -- Calculate discount
        IF v_coupon.discount_type = 'percentage' THEN
            v_discount := ROUND((v_batch.batch_price * v_coupon.discount_amount / 100.0), 2);
        ELSE
            v_discount := v_coupon.discount_amount;
        END IF;

        v_final_payable := GREATEST(0, v_batch.batch_price - v_discount);

        -- CRITICAL: Free RPC only grants enrollment if payable balance is zero.
        -- Partial discounts must be routed through Google Play In-App Product Tiers.
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
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.enroll_student_free_or_coupon(UUID, TEXT, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.enroll_student_free_or_coupon(UUID, TEXT, UUID) TO authenticated, service_role;
