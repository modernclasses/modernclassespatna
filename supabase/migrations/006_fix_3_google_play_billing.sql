-- 006_fix_3_google_play_billing.sql
-- Fix 3: Google Play Billing & Secure Server-Side Enrollments

-- 1. Create purchases table
CREATE TABLE public.purchases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    store_product_id TEXT NOT NULL,
    purchase_token TEXT UNIQUE NOT NULL,
    order_id TEXT,
    purchase_time TIMESTAMPTZ,
    status TEXT NOT NULL CHECK (status IN ('purchased', 'pending', 'canceled')),
    acknowledgement_state TEXT NOT NULL DEFAULT 'not_acknowledged' CHECK (acknowledgement_state IN ('not_acknowledged', 'acknowledged', 'acknowledgement_pending')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW())
);

CREATE TRIGGER update_purchases_updated_at BEFORE UPDATE ON public.purchases FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

ALTER TABLE public.purchases ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Students view own purchases" ON public.purchases FOR SELECT USING (student_id = auth.uid());
CREATE POLICY "Service Role full access" ON public.purchases FOR ALL USING (auth.role() = 'service_role');

-- 2. Update Enrollments
ALTER TABLE public.enrollments ADD COLUMN IF NOT EXISTS purchase_id UUID REFERENCES public.purchases(id) ON DELETE RESTRICT;

-- 3. Update Batches
ALTER TABLE public.batches ADD COLUMN IF NOT EXISTS play_product_id TEXT;
CREATE UNIQUE INDEX idx_batches_play_product_id ON public.batches(play_product_id) WHERE play_product_id IS NOT NULL;

-- 4. Create the Secure RPC
CREATE OR REPLACE FUNCTION public.record_verified_purchase_and_enroll(
    p_student_id UUID,
    p_store_product_id TEXT,
    p_purchase_token TEXT,
    p_order_id TEXT,
    p_purchase_time TIMESTAMPTZ,
    p_status TEXT,
    p_acknowledgement_state TEXT
) RETURNS UUID AS $$
DECLARE
    v_batch_id UUID;
    v_purchase_id UUID;
    v_existing_student_id UUID;
BEGIN
    -- 1. Resolve batch authoritatively inside RPC
    SELECT id INTO v_batch_id FROM public.batches WHERE play_product_id = p_store_product_id AND is_active = true;
    
    IF v_batch_id IS NULL THEN
        RAISE EXCEPTION 'No active batch found for store_product_id: %', p_store_product_id;
    END IF;

    -- 2. Idempotent Purchase Insertion
    INSERT INTO public.purchases (
        student_id, store_product_id, purchase_token, order_id, purchase_time, status, acknowledgement_state
    ) VALUES (
        p_student_id, p_store_product_id, p_purchase_token, p_order_id, p_purchase_time, p_status, p_acknowledgement_state
    ) ON CONFLICT (purchase_token) DO NOTHING RETURNING id INTO v_purchase_id;

    IF v_purchase_id IS NULL THEN
        -- A conflict occurred. Fetch the existing purchase.
        SELECT id, student_id INTO v_purchase_id, v_existing_student_id
        FROM public.purchases 
        WHERE purchase_token = p_purchase_token;

        -- Verify it belongs to the exact same student to prevent token hijacking
        IF v_existing_student_id != p_student_id THEN
            RAISE EXCEPTION 'Purchase token is already bound to a different student.';
        END IF;
    END IF;

    -- 3. Atomic Enrollment Repair/Upsert
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Secure the RPC boundary
REVOKE ALL ON FUNCTION public.record_verified_purchase_and_enroll(UUID, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_verified_purchase_and_enroll(UUID, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT, TEXT) TO service_role;

-- 6. Helper RPC to update acknowledgement state
CREATE OR REPLACE FUNCTION public.update_purchase_acknowledgement(
    p_purchase_token TEXT,
    p_new_state TEXT
) RETURNS VOID AS $$
BEGIN
    UPDATE public.purchases 
    SET acknowledgement_state = p_new_state 
    WHERE purchase_token = p_purchase_token;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

REVOKE ALL ON FUNCTION public.update_purchase_acknowledgement(TEXT, TEXT) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.update_purchase_acknowledgement(TEXT, TEXT) TO service_role;
