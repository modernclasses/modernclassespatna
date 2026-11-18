-- ==============================================================================
-- Migration 033: Google Play Price Tiers, Authoritative Coupons & Free Enrollment
-- ==============================================================================

-- Drop legacy overloads from migrations 006 and interim snippets to eliminate obsolete attack surfaces
DROP FUNCTION IF EXISTS public.record_verified_purchase_and_enroll(UUID, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.record_verified_purchase_and_enroll(UUID, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT, TEXT, UUID);
DROP FUNCTION IF EXISTS public.enroll_student_free_or_coupon(UUID, UUID, TEXT);
DROP FUNCTION IF EXISTS public.enroll_student_free_or_coupon(UUID, TEXT, UUID);

-- 1. Upgrade record_verified_purchase_and_enroll to accept optional p_batch_id
-- This allows purchases made against generic Google Play Tiers (e.g. course_tier_999)
-- to be accurately bound to the purchased batch.
-- SECURITY HARDENING:
-- - SET search_path = public, pg_temp
-- - Explicit check preventing execution by authenticated/anon client roles
-- - Serialized row locking FOR UPDATE on purchases
-- - Replay prevention across different batches
-- - Revoked from PUBLIC, anon, authenticated; Granted ONLY to service_role
CREATE OR REPLACE FUNCTION public.record_verified_purchase_and_enroll(
    p_student_id UUID,
    p_store_product_id TEXT,
    p_purchase_token TEXT,
    p_order_id TEXT,
    p_purchase_time TIMESTAMPTZ,
    p_status TEXT,
    p_acknowledgement_state TEXT,
    p_batch_id UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_batch_id UUID;
    v_purchase_id UUID;
    v_existing_student_id UUID;
    v_bound_batch_id UUID;
BEGIN
    -- 1. Security & Role Boundary: Reject direct client-side execution
    -- Only server-side verification using service_role may invoke this function
    IF auth.role() = 'authenticated' OR auth.role() = 'anon' THEN
        RAISE EXCEPTION 'Access denied: record_verified_purchase_and_enroll can only be invoked by service_role.';
    END IF;

    -- 2. Resolve batch: Prioritize explicit p_batch_id, fallback to store_product_id lookup
    IF p_batch_id IS NOT NULL THEN
        SELECT id INTO v_batch_id 
        FROM public.batches 
        WHERE id = p_batch_id AND is_active = true;
    ELSE
        SELECT id INTO v_batch_id 
        FROM public.batches 
        WHERE play_product_id = p_store_product_id AND is_active = true;
    END IF;

    IF v_batch_id IS NULL THEN
        RAISE EXCEPTION 'No active batch found for product: % / batch: %', p_store_product_id, p_batch_id;
    END IF;

    -- 3. Lock purchase row if token already exists to serialize concurrent redemptions
    SELECT id, student_id INTO v_purchase_id, v_existing_student_id
    FROM public.purchases 
    WHERE purchase_token = p_purchase_token
    FOR UPDATE;

    IF v_purchase_id IS NOT NULL THEN
        -- Token already registered: must belong to the exact same student
        IF v_existing_student_id != p_student_id THEN
            RAISE EXCEPTION 'Purchase token is already bound to a different student.';
        END IF;

        -- Invariant: Prevent cross-batch token replay
        -- Check if this purchase token is already tied to an enrollment in a DIFFERENT batch
        SELECT batch_id INTO v_bound_batch_id
        FROM public.enrollments
        WHERE purchase_id = v_purchase_id;

        IF v_bound_batch_id IS NOT NULL AND v_bound_batch_id != v_batch_id THEN
            RAISE EXCEPTION 'This purchase token has already been redeemed for a different batch.';
        END IF;
    ELSE
        -- Insert new purchase record
        INSERT INTO public.purchases (
            student_id, store_product_id, purchase_token, order_id, purchase_time, status, acknowledgement_state
        ) VALUES (
            p_student_id, p_store_product_id, p_purchase_token, p_order_id, p_purchase_time, p_status, p_acknowledgement_state
        ) RETURNING id INTO v_purchase_id;
    END IF;

    -- 4. Atomic Enrollment
    INSERT INTO public.enrollments (
        student_id, batch_id, purchase_id, status
    ) VALUES (
        p_student_id, v_batch_id, v_purchase_id, 'active'
    ) ON CONFLICT (student_id, batch_id) DO UPDATE SET 
        status = 'active',
        purchase_id = EXCLUDED.purchase_id
    WHERE public.enrollments.status != 'active' OR public.enrollments.purchase_id IS NULL;

    RETURN v_purchase_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- Revoke execute from all untrusted roles
REVOKE ALL ON FUNCTION public.record_verified_purchase_and_enroll(UUID, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT, TEXT, UUID) FROM PUBLIC, anon, authenticated;
-- Grant execute strictly to service_role
GRANT EXECUTE ON FUNCTION public.record_verified_purchase_and_enroll(UUID, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT, TEXT, UUID) TO service_role;

-- 2. Partial Unique Index on Enrollments
-- Enforces that a single purchase record (purchase_id) can never be assigned to multiple enrollments
CREATE UNIQUE INDEX IF NOT EXISTS idx_enrollments_unique_purchase_id 
ON public.enrollments(purchase_id) 
WHERE purchase_id IS NOT NULL;

-- 3. Authoritative Coupons Table
CREATE TABLE IF NOT EXISTS public.coupons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,
    discount_amount NUMERIC NOT NULL CHECK (discount_amount >= 0),
    discount_type TEXT NOT NULL DEFAULT 'flat' CHECK (discount_type IN ('flat', 'percentage')),
    min_order_value NUMERIC NOT NULL DEFAULT 0 CHECK (min_order_value >= 0),
    is_active BOOLEAN NOT NULL DEFAULT true,
    max_uses INT NULL CHECK (max_uses IS NULL OR max_uses > 0),
    current_uses INT NOT NULL DEFAULT 0 CHECK (current_uses >= 0),
    expires_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW())
);

-- Trigger to automatically update updated_at on coupons
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger WHERE tgname = 'update_coupons_updated_at'
    ) THEN
        CREATE TRIGGER update_coupons_updated_at 
        BEFORE UPDATE ON public.coupons 
        FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
    END IF;
END $$;

-- 4. Coupon Redemptions Table (Tracks student-batch coupon redemptions, enforcing single-use per batch & audit log)
CREATE TABLE IF NOT EXISTS public.coupon_redemptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    coupon_id UUID NOT NULL REFERENCES public.coupons(id) ON DELETE RESTRICT,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    batch_id UUID NOT NULL REFERENCES public.batches(id) ON DELETE RESTRICT,
    discount_applied NUMERIC NOT NULL CHECK (discount_applied >= 0),
    redeemed_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    UNIQUE(coupon_id, student_id, batch_id)
);

-- 5. Enable Row Level Security (RLS)
ALTER TABLE public.coupons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coupon_redemptions ENABLE ROW LEVEL SECURITY;

-- Coupons RLS Policies:
-- Students can view active, unexpired coupons
DROP POLICY IF EXISTS "Public can view active coupons" ON public.coupons;
CREATE POLICY "Public can view active coupons" ON public.coupons
FOR SELECT USING (
    is_active = true 
    AND (expires_at IS NULL OR expires_at > TIMEZONE('utc', NOW()))
);

-- Admins have full management access over coupons
DROP POLICY IF EXISTS "Admins can manage coupons" ON public.coupons;
CREATE POLICY "Admins can manage coupons" ON public.coupons
FOR ALL USING (public.is_admin());

-- Coupon Redemptions RLS Policies:
-- Students can view their own redemptions; admins view all
DROP POLICY IF EXISTS "Students view own redemptions" ON public.coupon_redemptions;
CREATE POLICY "Students view own redemptions" ON public.coupon_redemptions
FOR SELECT USING (student_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS "Admins manage redemptions" ON public.coupon_redemptions;
CREATE POLICY "Admins manage redemptions" ON public.coupon_redemptions
FOR ALL USING (public.is_admin());

-- 6. Seed default promotional and scholarship coupons
INSERT INTO public.coupons (code, discount_amount, discount_type, min_order_value, is_active, max_uses)
VALUES 
    ('PATNA50', 200, 'flat', 500, true, NULL),
    ('WELCOME100', 100, 'flat', 400, true, NULL),
    ('BPSC300', 300, 'flat', 1000, true, NULL),
    ('SCHOLARSHIP100', 100, 'percentage', 0, true, 500)
ON CONFLICT (code) DO NOTHING;

-- 7. Hardened RPC for Free & 100% Coupon-Based Enrollment
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
