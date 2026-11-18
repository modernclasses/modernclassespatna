-- ==============================================================================
-- Migration: 017_admin_set_primary_batch_teacher.sql
-- Description: Safely demote current primary teacher and promote target teacher.
-- ==============================================================================

CREATE OR REPLACE FUNCTION public.admin_set_primary_batch_teacher(
    p_batch_id UUID,
    p_teacher_id UUID
) RETURNS JSONB AS $$
DECLARE
    v_role user_role;
    v_is_assigned BOOLEAN;
BEGIN
    -- 1. Check admin privileges
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Access Denied: Only administrators can modify primary batch assignments.';
    END IF;

    -- 2. Verify target is a teacher
    SELECT role INTO v_role FROM public.profiles WHERE id = p_teacher_id;
    IF v_role IS NULL THEN
        RAISE EXCEPTION 'Target user not found.';
    END IF;
    IF v_role != 'teacher' THEN
        RAISE EXCEPTION 'Target user is not a teacher.';
    END IF;

    -- 3. Verify teacher is assigned to the batch
    SELECT EXISTS (
        SELECT 1 FROM public.batch_teachers 
        WHERE batch_id = p_batch_id AND teacher_id = p_teacher_id
    ) INTO v_is_assigned;
    
    IF NOT v_is_assigned THEN
        RAISE EXCEPTION 'Teacher is not assigned to this batch. Assign them first.';
    END IF;

    -- 4. Atomically swap primary status
    -- Step A: Demote any existing primary teacher for this batch
    UPDATE public.batch_teachers
    SET is_primary = false
    WHERE batch_id = p_batch_id;

    -- Step B: Promote the target teacher
    UPDATE public.batch_teachers
    SET is_primary = true
    WHERE batch_id = p_batch_id AND teacher_id = p_teacher_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'batch_id', p_batch_id,
        'primary_teacher_id', p_teacher_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE EXECUTE ON FUNCTION public.admin_set_primary_batch_teacher(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_primary_batch_teacher(UUID, UUID) TO authenticated;
