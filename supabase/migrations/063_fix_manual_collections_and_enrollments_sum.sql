-- ==============================================================================
-- Migration 063: Fix Manual Collections & Backfill In-App Purchase Transactions
-- ==============================================================================
-- Description:
-- 1. Updates get_admin_manual_collections_total() to aggregate across both
--    public.transactions and active enrollments in paid batches (preventing double counting).
-- 2. Backfills missing transaction records in public.transactions for existing
--    active enrollments whose batches have a batch_price > 0.
-- 3. Hardens record_verified_purchase_and_enroll to insert a corresponding
--    transaction record into public.transactions upon every genuine or verified purchase.
--
-- CRITICAL DEPLOYMENT DIRECTIVE:
-- DO NOT EXECUTE VIA 'supabase db push'. Must be applied manually via the
-- Supabase Dashboard SQL Editor due to migration history divergence.
-- ==============================================================================

BEGIN;

-- 1. Backfill missing transaction records for existing active enrollments
INSERT INTO public.transactions (
    id,
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
    gen_random_uuid() AS id,
    'INV-' || LPAD(FLOOR(RANDOM() * 900000 + 100000)::TEXT, 6, '0') || '-' || SUBSTRING(e.id::TEXT FROM 1 FOR 4) AS invoice_number,
    e.student_id,
    COALESCE(p.full_name, 'Enrolled Student') AS student_name,
    b.course_id,
    COALESCE(c.title, b.name, 'Enrolled Course') AS course_title,
    COALESCE(b.batch_price, 0.00) AS amount_paid,
    'Google Play Billing' AS payment_method,
    COALESCE(pr.purchase_token, 'ENR-' || SUBSTRING(e.id::TEXT FROM 1 FOR 8)) AS transaction_reference,
    'success'::public.payment_status AS status,
    COALESCE(e.enrolled_at, TIMEZONE('utc', NOW())) AS created_at
FROM public.enrollments e
JOIN public.batches b ON b.id = e.batch_id
LEFT JOIN public.courses c ON c.id = b.course_id
LEFT JOIN public.profiles p ON p.id = e.student_id
LEFT JOIN public.purchases pr ON pr.id = e.purchase_id
WHERE e.status = 'active'
  AND b.batch_price > 0
  AND NOT EXISTS (
      SELECT 1 FROM public.transactions t
      WHERE t.student_id = e.student_id 
        AND t.course_id = b.course_id
  );

-- 2. Upgrade get_admin_manual_collections_total to aggregate transactions and active enrollments
CREATE OR REPLACE FUNCTION public.get_admin_manual_collections_total()
RETURNS NUMERIC AS $$
DECLARE
    v_tx_total NUMERIC;
    v_enrollment_total NUMERIC;
    v_total NUMERIC;
BEGIN
    -- Explicitly fail closed when public.is_admin() evaluates to FALSE or NULL.
    IF public.is_admin() IS NOT TRUE THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required';
    END IF;

    -- Sum from transactions (manual/direct ledger receipts & backfilled purchases)
    SELECT COALESCE(pg_catalog.sum(amount_paid), 0.00) INTO v_tx_total
    FROM public.transactions
    WHERE status = 'success'::public.payment_status;

    -- Fallback sum from active enrollments whose batch_price > 0 without a matching transaction
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
      );

    v_total := v_tx_total + v_enrollment_total;
    RETURN v_total;
END;
$$ LANGUAGE plpgsql 
SECURITY DEFINER SET search_path = public, pg_temp;

-- Revoke default open execution capabilities
REVOKE ALL ON FUNCTION public.get_admin_manual_collections_total() FROM PUBLIC, anon;

-- Explicitly grant execution strictly to authenticated clients and service_role
GRANT EXECUTE ON FUNCTION public.get_admin_manual_collections_total() TO authenticated, service_role;

-- 3. Upgrade record_verified_purchase_and_enroll to insert transaction row atomically
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
    v_course_id UUID;
    v_batch_price NUMERIC;
    v_batch_name TEXT;
    v_course_title TEXT;
    v_student_name TEXT;
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
        SELECT id, course_id, batch_price, name 
        INTO v_batch_id, v_course_id, v_batch_price, v_batch_name
        FROM public.batches 
        WHERE id = p_batch_id AND is_active = true;
    ELSE
        SELECT id, course_id, batch_price, name 
        INTO v_batch_id, v_course_id, v_batch_price, v_batch_name
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

    -- 5. Atomic Transaction Ledger Record
    IF p_status = 'purchased' THEN
        SELECT full_name INTO v_student_name FROM public.profiles WHERE id = p_student_id;
        SELECT title INTO v_course_title FROM public.courses WHERE id = v_course_id;

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
            'INV-' || LPAD(FLOOR(RANDOM() * 900000 + 100000)::TEXT, 6, '0') || '-' || SUBSTRING(gen_random_uuid()::TEXT FROM 1 FOR 4),
            p_student_id,
            COALESCE(v_student_name, 'Enrolled Student'),
            v_course_id,
            COALESCE(v_course_title, v_batch_name, 'Enrolled Course'),
            COALESCE(v_batch_price, 0.00),
            'Google Play Billing',
            p_purchase_token,
            'success'::public.payment_status,
            COALESCE(p_purchase_time, TIMEZONE('utc', NOW()))
        ) ON CONFLICT DO NOTHING;
    END IF;

    RETURN v_purchase_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- Revoke execute from all untrusted roles
REVOKE ALL ON FUNCTION public.record_verified_purchase_and_enroll(UUID, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT, TEXT, UUID) FROM PUBLIC, anon, authenticated;
-- Grant execute strictly to service_role
GRANT EXECUTE ON FUNCTION public.record_verified_purchase_and_enroll(UUID, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT, TEXT, UUID) TO service_role;

COMMIT;
