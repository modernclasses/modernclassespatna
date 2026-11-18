-- ============================================================================
-- Migration 022: Secure Batch Roster API
-- Description: Creates a secure RPC for fetching enrolled students in a batch
--              without reopening public.profiles SELECT to everyone.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_batch_students(p_batch_id UUID)
RETURNS TABLE (
    id UUID,
    name TEXT,
    email TEXT,
    phone TEXT,
    role TEXT
) AS $$
BEGIN
    -- Only allow if admin or assigned teacher
    IF NOT (public.is_admin() OR public.is_teacher_for_batch(p_batch_id)) THEN
        RAISE EXCEPTION 'Unauthorized: You are not assigned to this batch.';
    END IF;

    RETURN QUERY
    SELECT 
        p.id,
        p.full_name AS name,
        p.email,
        p.phone,
        p.role::TEXT
    FROM public.enrollments e
    JOIN public.profiles p ON p.id = e.student_id
    WHERE e.batch_id = p_batch_id
      AND e.status = 'active'
      AND p.role = 'student';
END;
$$
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp;

-- Revoke default execution
REVOKE ALL ON FUNCTION public.get_batch_students(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_batch_students(UUID) TO authenticated;
