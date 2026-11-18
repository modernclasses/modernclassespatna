-- Migration 029: Admin Ledger Aggregates
-- Note: Do NOT execute via 'supabase db push'. Must be applied manually via SQL Editor due to migration state divergence.

CREATE OR REPLACE FUNCTION public.get_admin_manual_collections_total()
RETURNS NUMERIC AS $$
DECLARE
    v_total NUMERIC;
BEGIN
    -- Explicitly fail closed when public.is_admin() evaluates to FALSE or NULL.
    IF public.is_admin() IS NOT TRUE THEN
        RAISE EXCEPTION 'Unauthorized: Admin access required';
    END IF;

    -- Schema-qualified aggregation using pg_catalog primitives
    SELECT COALESCE(pg_catalog.sum(amount_paid), 0.00) INTO v_total
    FROM public.transactions
    WHERE status = 'success'::public.payment_status;

    RETURN v_total;
END;
$$ LANGUAGE plpgsql 
SECURITY DEFINER SET search_path = '';

-- Revoke default open execution capabilities
REVOKE ALL ON FUNCTION public.get_admin_manual_collections_total() FROM PUBLIC, anon, authenticated;

-- Explictly grant execution strictly to authenticated clients
GRANT EXECUTE ON FUNCTION public.get_admin_manual_collections_total() TO authenticated;
