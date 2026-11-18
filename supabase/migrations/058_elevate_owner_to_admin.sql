-- ==============================================================================
-- Migration: 058_elevate_owner_to_admin.sql
-- Purpose:   Restore Administrator privileges for the institute owner/founder
--            account after the stricter server-side role checks replaced the
--            old mock/admin-PIN login path.
--
-- WHY THIS FIX IS NEEDED
--   * App login (`AuthProvider.loginStaff` → expectedRole admin) and the
--     `admin_create_teacher` edge function both require
--     `public.profiles.role = 'admin'`.
--   * The old "master PIN" login bypassed the database role entirely, so an
--     owner account used via the PIN can have a profile `role` that is NOT
--     'admin' (e.g. 'student'/'teacher'), which is why "the owner cannot
--     create teachers" while another admin account can.
--
-- HOW TO RUN
--   1. Edit the OWNER_EMAIL constant below to the owner's actual login email.
--   2. Run ONLY this block in the Supabase SQL Editor (runs as postgres).
--   3. Have the owner sign out and sign back in on the app.
-- ==============================================================================

DO $$
DECLARE
    v_owner_email TEXT := 'owner@example.com'; -- <-- CHANGE THIS to the owner's email
    v_target_id   UUID;
    v_current     user_role;
BEGIN
    SELECT id, role INTO v_target_id, v_current
    FROM public.profiles
    WHERE lower(email) = lower(v_owner_email)
    LIMIT 1;

    IF v_target_id IS NULL THEN
        RAISE EXCEPTION 'No profile found for email "%"', v_owner_email;
    END IF;

    IF v_current = 'admin' THEN
        RAISE NOTICE 'Account % is already an admin (id %). Nothing to do.', v_owner_email, v_target_id;
        RETURN;
    END IF;

    RAISE NOTICE 'Promoting % from % to admin...', v_owner_email, COALESCE(v_current::TEXT, 'NULL');

    -- Register the session as the trusted service role so the
    -- `protect_profile_fields` trigger permits the role change.
    PERFORM set_config(
        'request.jwt.claims',
        json_build_object('role', 'service_role')::TEXT,
        true -- transaction-scoped
    );

    UPDATE public.profiles
    SET role       = 'admin',
        updated_at = TIMEZONE('utc', NOW())
    WHERE id = v_target_id;

    RAISE NOTICE 'Done. % now has role = admin.', v_owner_email;
END $$;

-- Verification (optional): re-check after running the block above.
-- SELECT id, email, role, is_active FROM public.profiles
-- WHERE lower(email) = lower('owner@example.com');