-- ==============================================================================
-- Migration 004: Secure Server-Side Roles, Profile Protection & Role RPC
-- Database: PostgreSQL / Supabase
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. Fix handle_new_user Trigger to Force Default 'student' Role
-- Never trust raw_user_meta_data from client for role assignment!
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (
        id,
        full_name,
        email,
        phone,
        role,
        target_exam,
        medium,
        is_active,
        created_at,
        updated_at
    )
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'Student Aspirant'),
        NEW.email,
        NEW.raw_user_meta_data->>'phone',
        'student', -- FORCED DEFAULT: Never trust user_metadata for role elevation
        COALESCE(NEW.raw_user_meta_data->>'target_exam', 'BPSC 71st Civil Services'),
        COALESCE(NEW.raw_user_meta_data->>'medium', 'Bilingual (Hindi + English)'),
        TRUE,
        TIMEZONE('utc', NOW()),
        TIMEZONE('utc', NOW())
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- ------------------------------------------------------------------------------
-- 2. Sensitive Profile Field Protection Trigger
-- Blocks direct table updates to 'role', 'id', 'email', and 'is_active' by normal clients
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.protect_profile_fields()
RETURNS TRIGGER AS $$
DECLARE
    caller_role user_role;
BEGIN
    -- Prevent modifying primary key
    IF (NEW.id IS DISTINCT FROM OLD.id) THEN
        RAISE EXCEPTION 'Access Denied: The user ID cannot be modified.';
    END IF;

    -- Prevent modifying email directly on profiles (must use Supabase Auth for email changes)
    IF (NEW.email IS DISTINCT FROM OLD.email) THEN
        RAISE EXCEPTION 'Access Denied: Email cannot be updated via profiles table.';
    END IF;

    -- Evaluate who is making the change
    IF auth.uid() = NEW.id THEN
        -- Self-update: Block sensitive fields
        IF (NEW.role IS DISTINCT FROM OLD.role) THEN
            RAISE EXCEPTION 'Access Denied: You cannot modify your own role.';
        END IF;
        IF (NEW.is_active IS DISTINCT FROM OLD.is_active) THEN
            RAISE EXCEPTION 'Access Denied: You cannot modify your own active status.';
        END IF;
    ELSE
        -- Admin-update: Verify admin status
        SELECT role INTO caller_role FROM public.profiles WHERE id = auth.uid();
        IF caller_role IS DISTINCT FROM 'admin' THEN
            RAISE EXCEPTION 'Access Denied: Only administrators can modify other profiles.';
        END IF;
    END IF;

    NEW.updated_at = TIMEZONE('utc', NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS trg_protect_profile_fields ON public.profiles;
CREATE TRIGGER trg_protect_profile_fields
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.protect_profile_fields();

-- ------------------------------------------------------------------------------
-- 3. Controlled Server-Side Role Management RPC
-- Callable ONLY by verified authenticated administrators for other users
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_set_user_role(
    target_user_id UUID,
    new_role user_role
)
RETURNS JSONB AS $$
DECLARE
    caller_role user_role;
    target_exists BOOLEAN;
BEGIN
    -- 1. Check authentication
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    -- 2. Prevent self-promotion / self-demotion
    IF auth.uid() = target_user_id THEN
        RAISE EXCEPTION 'Administrators cannot modify their own role.';
    END IF;

    -- 3. Verify caller is a verified admin from profiles
    SELECT role INTO caller_role FROM public.profiles WHERE id = auth.uid();
    IF caller_role IS NULL OR caller_role != 'admin' THEN
        RAISE EXCEPTION 'Access Denied: Administrator privileges required.';
    END IF;

    -- 4. Check target user exists
    SELECT EXISTS (SELECT 1 FROM public.profiles WHERE id = target_user_id) INTO target_exists;
    IF NOT target_exists THEN
        RAISE EXCEPTION 'Target user not found.';
    END IF;

    -- 5. Perform the update directly. The trigger will see auth.uid() is an admin and allow it.
    UPDATE public.profiles
    SET role = new_role,
        updated_at = TIMEZONE('utc', NOW())
    WHERE id = target_user_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'target_user_id', target_user_id,
        'new_role', new_role::TEXT,
        'updated_at', TIMEZONE('utc', NOW())
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

-- Grant execution to authenticated users (internal checks enforce admin-only logic)
GRANT EXECUTE ON FUNCTION public.admin_set_user_role(UUID, user_role) TO authenticated;

-- Explicitly revoke execution from public to prevent unauthenticated access
REVOKE ALL ON FUNCTION public.admin_set_user_role(UUID, user_role) FROM PUBLIC;
