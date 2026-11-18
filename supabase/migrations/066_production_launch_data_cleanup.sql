-- ==============================================================================
-- Migration: 066_production_launch_data_cleanup.sql
-- Description: Production launch reset: cleans up all test students, test teachers,
--              recorded/live lectures, student enrollments, and test transactions
--              while strictly preserving the admin account, course structures,
--              batch templates, and platform system configuration.
-- ==============================================================================

BEGIN;

DO $$
DECLARE
    v_admin_id UUID := '943dfd34-c7c5-4739-85d5-238880ed7bd7';
    v_admin_email TEXT := 'madhurendrayadav06@gmail.com';
BEGIN
    RAISE NOTICE '=== STARTING PRODUCTION CLEANUP (PRESERVING ADMIN: %) ===', v_admin_email;

    -- Register trusted service role context for this transaction
    PERFORM set_config('request.jwt.claims', json_build_object('role', 'service_role')::TEXT, true);

    -- 1. Unassign non-admin teachers from batches and courses
    DELETE FROM public.batch_teachers WHERE teacher_id <> v_admin_id;
    UPDATE public.courses SET teacher_id = NULL WHERE teacher_id <> v_admin_id;

    -- 2. Clear all lectures, live classes, recordings, and chat messages
    DELETE FROM public.lecture_recordings;
    DELETE FROM public.live_chat_messages;
    DELETE FROM public.live_classes;
    DELETE FROM public.lessons;

    -- 3. Clear student activity data
    DELETE FROM public.attendance;
    DELETE FROM public.doubts;
    DELETE FROM public.test_submissions;
    DELETE FROM public.tests;
    DELETE FROM public.study_materials;
    DELETE FROM public.enrollments WHERE student_id <> v_admin_id;
    DELETE FROM public.transactions WHERE student_id <> v_admin_id;
    DELETE FROM public.purchases WHERE student_id <> v_admin_id;
    DELETE FROM public.coupon_redemptions WHERE student_id <> v_admin_id;
    DELETE FROM public.announcements WHERE created_by <> v_admin_id;
    DELETE FROM public.user_device_tokens WHERE user_id <> v_admin_id;

    -- 4. Delete non-admin profiles
    DELETE FROM public.profiles WHERE id <> v_admin_id;

    -- 5. Delete non-admin auth.users
    DELETE FROM auth.users WHERE id <> v_admin_id;

    -- 6. Reset course lesson/hours/test counters to exactly 0
    UPDATE public.courses
    SET total_lessons = 0,
        total_hours = 0,
        total_tests = 0,
        total_notes = 0,
        updated_at = TIMEZONE('utc', NOW());

    RAISE NOTICE '=== PRODUCTION CLEANUP COMPLETED SUCCESSFULLY ===';
END $$;

COMMIT;

-- Diagnostic verification query confirming clean production state
SELECT
    (SELECT COUNT(*) FROM auth.users) AS remaining_users,
    (SELECT COUNT(*) FROM public.profiles) AS remaining_profiles,
    (SELECT email FROM public.profiles LIMIT 1) AS remaining_profile_email,
    (SELECT role::text FROM public.profiles LIMIT 1) AS remaining_profile_role,
    (SELECT COUNT(*) FROM public.lecture_recordings) AS remaining_recordings,
    (SELECT COUNT(*) FROM public.live_classes) AS remaining_live_classes,
    (SELECT COUNT(*) FROM public.lessons) AS remaining_lessons,
    (SELECT COUNT(*) FROM public.enrollments) AS remaining_enrollments,
    (SELECT COUNT(*) FROM public.batch_teachers) AS remaining_batch_teachers,
    (SELECT COUNT(*) FROM public.user_device_tokens) AS remaining_device_tokens,
    (SELECT COUNT(*) FROM public.announcements) AS remaining_announcements,
    (SELECT total_lessons FROM public.courses LIMIT 1) AS course_total_lessons,
    (SELECT total_hours FROM public.courses LIMIT 1) AS course_total_hours;
