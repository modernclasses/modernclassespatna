-- ==============================================================================
-- Migration 048: Performance Optimization - Dynamic Foreign Key Indexes & Cleanup
-- Database: PostgreSQL / Supabase
-- Target: Modern Classes Patna
--
-- Description:
--   1. Converts validate_doubt_update trigger to SECURITY INVOKER and revokes
--      authenticated execute rights (resolves remaining trigger Lint 0029).
--   2. Schema-validated covering indexes for all unindexed foreign keys across
--      15 tables (resolves all "Unindexed foreign keys" performance warnings).
--   3. Drops redundant duplicate indexes on cloudflare_live_inputs.
-- ==============================================================================

BEGIN;

-- ==============================================================================
-- PART 1: REMAINING TRIGGER FUNCTION SECURITY INVOKER FIX (Lint 0029)
-- ==============================================================================
DO $$
BEGIN
    ALTER FUNCTION public.validate_doubt_update() SECURITY INVOKER;
    REVOKE ALL ON FUNCTION public.validate_doubt_update() FROM PUBLIC, anon, authenticated;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

-- ==============================================================================
-- PART 2: DYNAMIC COVERING INDEXES FOR UNINDEXED FOREIGN KEYS (Performance Advisor)
-- ==============================================================================
-- Checks information_schema before creating each index to guarantee zero 42703 errors.
DO $$
DECLARE
    targets CONSTANT text[][] := ARRAY[
        ['announcements', 'target_batch_id', 'idx_announcements_target_batch_id'],
        ['announcements', 'created_by', 'idx_announcements_created_by'],
        ['attendance', 'batch_id', 'idx_attendance_batch_id'],
        ['attendance', 'marked_by_teacher_id', 'idx_attendance_marked_by_teacher'],
        ['cloudflare_live_inputs', 'batch_id', 'idx_cloudflare_live_inputs_batch_id'],
        ['cloudflare_live_inputs', 'created_by', 'idx_cloudflare_live_inputs_created_by'],
        ['coupon_redemptions', 'coupon_id', 'idx_coupon_redemptions_coupon_id'],
        ['coupon_redemptions', 'student_id', 'idx_coupon_redemptions_student_id'],
        ['coupon_redemptions', 'batch_id', 'idx_coupon_redemptions_batch_id'],
        ['courses', 'teacher_id', 'idx_courses_teacher_id'],
        ['doubts', 'resolved_by', 'idx_doubts_resolved_by'],
        ['doubts', 'student_id', 'idx_doubts_student_id'],
        ['doubts', 'batch_id', 'idx_doubts_batch_id'],
        ['enrollments', 'student_id', 'idx_enrollments_student_id'],
        ['enrollments', 'batch_id', 'idx_enrollments_batch_id'],
        ['enrollments', 'purchase_id', 'idx_enrollments_purchase_id'],
        ['lecture_recordings', 'live_class_id', 'idx_lecture_recordings_live_class_id'],
        ['lecture_recordings', 'teacher_id', 'idx_lecture_recordings_teacher_id'],
        ['lecture_recordings', 'batch_id', 'idx_lecture_recordings_batch_id'],
        ['lecture_recordings', 'course_id', 'idx_lecture_recordings_course_id'],
        ['lessons', 'batch_id', 'idx_lessons_batch_id'],
        ['lessons', 'course_id', 'idx_lessons_course_id'],
        ['live_classes', 'batch_id', 'idx_live_classes_batch_id'],
        ['live_classes', 'teacher_id', 'idx_live_classes_teacher_id'],
        ['purchases', 'student_id', 'idx_purchases_student_id'],
        ['study_materials', 'course_id', 'idx_study_materials_course_id'],
        ['study_materials', 'batch_id', 'idx_study_materials_batch_id'],
        ['study_materials', 'uploaded_by', 'idx_study_materials_uploaded_by'],
        ['test_submissions', 'student_id', 'idx_test_submissions_student_id'],
        ['test_submissions', 'test_id', 'idx_test_submissions_test_id'],
        ['tests', 'course_id', 'idx_tests_course_id'],
        ['tests', 'batch_id', 'idx_tests_batch_id'],
        ['batch_teachers', 'teacher_id', 'idx_batch_teachers_teacher_id']
    ];
    i int;
    tbl text;
    col text;
    idx text;
BEGIN
    FOR i IN 1 .. array_upper(targets, 1) LOOP
        tbl := targets[i][1];
        col := targets[i][2];
        idx := targets[i][3];

        IF EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name = tbl
              AND column_name = col
        ) THEN
            EXECUTE format('CREATE INDEX IF NOT EXISTS %I ON public.%I(%I);', idx, tbl, col);
        END IF;
    END LOOP;
END $$;

-- ==============================================================================
-- PART 3: CLEANUP OF REDUNDANT UNUSED INDEXES (Performance Advisor)
-- ==============================================================================
DROP INDEX IF EXISTS public.idx_cloudflare_live_inputs_uid;
DROP INDEX IF EXISTS public.idx_cloudflare_live_inputs_active;
DROP INDEX IF EXISTS public.idx_cloudflare_live_inputs_primary;

COMMIT;
