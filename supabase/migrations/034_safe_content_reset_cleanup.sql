-- ==============================================================================
-- Migration: 034_safe_content_reset_cleanup.sql
-- Description: Production-safe, idempotent, schema-resilient cleanup procedure
--              for clearing user-generated content (courses, batches, lessons,
--              study materials, tests, doubts, live broadcasts, enrollments,
--              announcements, and submissions).
--
-- DESIGNED FOR ZERO-FAILURE EXECUTION:
--   - Uses dynamic catalog reflection (`to_regclass`) so that non-existent or
--     differently-named legacy tables are safely skipped without aborting.
--   - Honors all foreign-key cascade orders strictly.
--   - Does NOT attempt direct SQL deletion on `storage.objects` (which is blocked
--     by Supabase's `storage.protect_delete()` trigger). Storage assets can be
--     cleared directly in the Supabase Dashboard > Storage > Empty Bucket.
--
-- TARGET CONTENT TABLES TO CLEAR (IF PRESENT):
--   1. public.test_submissions (Student test attempts and scorecards)
--   2. public.tests (Exam papers, questions, answer keys)
--   3. public.doubts (Student questions and faculty replies)
--   4. public.attendance (Daily batch attendance registers)
--   5. public.live_classes (Scheduled and recorded live broadcasts)
--   6. public.study_materials (Uploaded course PDFs, document notes)
--   7. public.lessons (Prerecorded video lectures)
--   8. public.batch_teachers (Teacher-to-batch assignments)
--   9. public.enrollments (Student batch enrollments)
--  10. public.transactions (Mock & Google Play payment ledger records)
--  11. public.batches (Course batch offerings)
--  12. public.courses (Curriculum and course catalog)
--  13. public.announcements (Institute announcements)
--  14. public.user_device_tokens (FCM push notification device tokens)
--
-- PRESERVED SYSTEM INFRASTRUCTURE & ACCOUNTS (STRICTLY NOT DELETED):
--   - auth.users (All student, teacher, and administrator login accounts remain intact)
--   - public.profiles (Display names, phone numbers, roles, timestamps remain intact)
--   - public.platform_settings (Admin RTMP credentials, single session locks, system config preserved)
--   - public.app_settings (Institute branding & app configuration preserved)
--   - public.coupons (Promo and discount codes preserved)
-- ==============================================================================

DO $$
DECLARE
    tbl TEXT;
    -- Sequence ordered strictly by foreign key dependencies (child tables first)
    target_tables TEXT[] := ARRAY[
        'test_submissions',
        'tests',
        'doubts',
        'attendance',
        'live_classes',
        'study_materials',
        'lessons',
        'batch_teachers',
        'enrollments',
        'transactions',
        'batches',
        'courses',
        'announcements',
        'notifications',
        'user_device_tokens'
    ];
BEGIN
    RAISE NOTICE '=== STARTING MODERN CLASSES PATNA CONTENT RESET ===';

    FOREACH tbl IN ARRAY target_tables LOOP
        IF to_regclass('public.' || tbl) IS NOT NULL THEN
            EXECUTE 'DELETE FROM public.' || quote_ident(tbl);
            RAISE NOTICE 'Successfully purged: public.%', tbl;
        ELSE
            RAISE NOTICE 'Table public.% does not exist; safely skipped.', tbl;
        END IF;
    END LOOP;

    RAISE NOTICE '=== CONTENT RESET COMPLETED SUCCESSFULLY ===';
END $$;

-- Diagnostic verification query to verify clean state & preserved accounts
SELECT
    (SELECT COUNT(*) FROM public.profiles) AS preserved_profiles,
    (SELECT COUNT(*) FROM auth.users) AS preserved_users,
    (SELECT CASE WHEN to_regclass('public.courses') IS NOT NULL THEN (SELECT COUNT(*) FROM public.courses) ELSE 0 END) AS remaining_courses,
    (SELECT CASE WHEN to_regclass('public.batches') IS NOT NULL THEN (SELECT COUNT(*) FROM public.batches) ELSE 0 END) AS remaining_batches,
    (SELECT CASE WHEN to_regclass('public.lessons') IS NOT NULL THEN (SELECT COUNT(*) FROM public.lessons) ELSE 0 END) AS remaining_lessons,
    (SELECT CASE WHEN to_regclass('public.study_materials') IS NOT NULL THEN (SELECT COUNT(*) FROM public.study_materials) ELSE 0 END) AS remaining_materials,
    (SELECT CASE WHEN to_regclass('public.tests') IS NOT NULL THEN (SELECT COUNT(*) FROM public.tests) ELSE 0 END) AS remaining_tests,
    (SELECT CASE WHEN to_regclass('public.test_submissions') IS NOT NULL THEN (SELECT COUNT(*) FROM public.test_submissions) ELSE 0 END) AS remaining_submissions,
    (SELECT CASE WHEN to_regclass('public.doubts') IS NOT NULL THEN (SELECT COUNT(*) FROM public.doubts) ELSE 0 END) AS remaining_doubts,
    (SELECT CASE WHEN to_regclass('public.live_classes') IS NOT NULL THEN (SELECT COUNT(*) FROM public.live_classes) ELSE 0 END) AS remaining_live_classes,
    (SELECT CASE WHEN to_regclass('public.announcements') IS NOT NULL THEN (SELECT COUNT(*) FROM public.announcements) ELSE 0 END) AS remaining_announcements;
