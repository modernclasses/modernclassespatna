-- 025_display_name_max_length_15.sql

-- Modifies the interim display name update RPC to reduce the maximum length from 50 to 15 characters
-- while preserving all formatting, spoofing, and role-based validations.

CREATE OR REPLACE FUNCTION public.update_my_display_name(p_new_name TEXT)
RETURNS TABLE (
    id UUID,
    full_name TEXT
)
AS $$
DECLARE
    v_caller_id UUID := auth.uid();
    v_current_role public.user_role;
    v_trimmed_name TEXT;
BEGIN
    -- 1. Explicit NULL check
    IF p_new_name IS NULL THEN
        RAISE EXCEPTION 'Display name cannot be empty';
    END IF;

    -- 2. Must be authenticated
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- 3. Must be a student
    SELECT role INTO v_current_role FROM public.profiles WHERE public.profiles.id = v_caller_id;
    IF v_current_role != 'student' THEN
        RAISE EXCEPTION 'Only students can update their display name through this endpoint';
    END IF;

    -- 4. Pre-process
    v_trimmed_name := trim(p_new_name);

    -- 5. Validation Rules
    IF length(v_trimmed_name) = 0 THEN
        RAISE EXCEPTION 'Display name cannot be empty';
    END IF;

    IF length(v_trimmed_name) > 15 THEN
        RAISE EXCEPTION 'Display name must be 15 characters or fewer';
    END IF;

    -- Reject control characters supported by PostgreSQL regex character classes.
    IF v_trimmed_name ~ '[[:cntrl:]]' THEN
        RAISE EXCEPTION 'Invalid hidden characters in display name';
    END IF;

    -- Zero-width, directional overrides, invisible formatting
    IF v_trimmed_name ~ e'[\u200B-\u200F\u202A-\u202E\u2060-\u206F]' THEN
        RAISE EXCEPTION 'Invalid hidden characters in display name';
    END IF;

    -- Excessive whitespace (3 or more consecutive spaces)
    IF v_trimmed_name ~ e'\s{3,}' THEN
        RAISE EXCEPTION 'Display name contains unusual formatting or repetition';
    END IF;

    -- Repeated character spam (5 or more identical consecutive chars)
    IF v_trimmed_name ~ e'(.)\1{4,}' THEN
        RAISE EXCEPTION 'Display name contains unusual formatting or repetition';
    END IF;

    -- Same-word mixed script spoofing (Latin mixed with Cyrillic or Greek)
    -- Looks for non-whitespace sequence containing both Latin and (Cyrillic or Greek)
    IF v_trimmed_name ~ e'[^\s]*[A-Za-z][^\s]*[\u0400-\u04FF\u0370-\u03FF][^\s]*' OR
       v_trimmed_name ~ e'[^\s]*[\u0400-\u04FF\u0370-\u03FF][^\s]*[A-Za-z][^\s]*' THEN
        RAISE EXCEPTION 'Display name rejected due to suspicious character mixing';
    END IF;

    -- 6. Safe Update returning minimal shape
    RETURN QUERY 
    UPDATE public.profiles
    SET 
        full_name = v_trimmed_name,
        updated_at = NOW()
    WHERE public.profiles.id = v_caller_id
    RETURNING public.profiles.id, public.profiles.full_name;

END;
$$
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp;

REVOKE ALL ON FUNCTION public.update_my_display_name(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_my_display_name(TEXT) TO authenticated;
