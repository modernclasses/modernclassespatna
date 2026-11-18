-- 026_immutable_display_name.sql

-- 1. Drop NOT NULL constraint so students can register without a permanent name
ALTER TABLE public.profiles ALTER COLUMN full_name DROP NOT NULL;

-- 2. Revoke direct execution of the current student name-writing RPC from authenticated
REVOKE EXECUTE ON FUNCTION public.update_my_display_name(TEXT) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.update_my_display_name(TEXT) FROM PUBLIC;
DROP FUNCTION IF EXISTS public.update_my_display_name(TEXT);

-- 3. Create the one-time name-setting RPC
CREATE OR REPLACE FUNCTION public.set_student_display_name_once(target_user_id UUID, new_name TEXT)
RETURNS TABLE (
    id UUID,
    full_name TEXT
)
AS $$
DECLARE
    v_current_role public.user_role;
    v_trimmed_name TEXT;
    v_profile_exists BOOLEAN;
    v_rows_updated INTEGER;
BEGIN
    -- Explicit NULL check for input
    IF new_name IS NULL THEN
        RAISE EXCEPTION 'Display name cannot be empty';
    END IF;

    -- Pre-process
    v_trimmed_name := trim(new_name);
    IF length(v_trimmed_name) = 0 THEN
        RAISE EXCEPTION 'Display name cannot be empty';
    END IF;
    IF length(v_trimmed_name) > 15 THEN
        RAISE EXCEPTION 'Display name is too long';
    END IF;

    -- Check target profile exists and role is student
    SELECT EXISTS (SELECT 1 FROM public.profiles WHERE public.profiles.id = target_user_id) INTO v_profile_exists;
    IF NOT v_profile_exists THEN
        RAISE EXCEPTION 'Target profile does not exist';
    END IF;

    SELECT role INTO v_current_role 
    FROM public.profiles 
    WHERE public.profiles.id = target_user_id;

    IF v_current_role != 'student' THEN
        RAISE EXCEPTION 'Only student names can be set through this endpoint';
    END IF;

    -- Atomic Update: Only update if full_name is currently NULL
    UPDATE public.profiles
    SET 
        full_name = v_trimmed_name,
        updated_at = NOW()
    WHERE public.profiles.id = target_user_id 
      AND public.profiles.role = 'student'
      AND public.profiles.full_name IS NULL;

    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;

    -- Distinguish why 0 rows might have been updated
    IF v_rows_updated = 0 THEN
        -- Since we already verified existence and role, it means full_name was NOT NULL
        RAISE EXCEPTION 'Student name is already set and cannot be changed';
    END IF;

    RETURN QUERY 
    SELECT public.profiles.id, public.profiles.full_name 
    FROM public.profiles 
    WHERE public.profiles.id = target_user_id;

END;
$$
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp;

-- Revoke from public and authenticated to prevent normal students from executing it
REVOKE ALL ON FUNCTION public.set_student_display_name_once(UUID, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.set_student_display_name_once(UUID, TEXT) FROM authenticated;
REVOKE ALL ON FUNCTION public.set_student_display_name_once(UUID, TEXT) FROM anon;

-- Grant to service_role (Edge Function)
GRANT EXECUTE ON FUNCTION public.set_student_display_name_once(UUID, TEXT) TO service_role;
