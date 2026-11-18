-- ==============================================================================
-- Migration 047: Advisor Security Hardening & Performance Optimization
-- Database: PostgreSQL / Supabase
-- Target: Modern Classes Patna
--
-- Description:
--   Comprehensive resolution for remaining Supabase Advisor warnings:
--   1. "Public Bucket Allows Listing":
--      Drops open SELECT policies on storage.objects for public bucket 'course-thumbnails'.
--   2. "Public Can Execute SECURITY DEFINER Function" (Lint 0028):
--      Revokes EXECUTE from PUBLIC and anon across all schema public functions.
--   3. "Signed-In Users Can Execute SECURITY DEFINER Function" (Lint 0029):
--      - Revokes execute from authenticated on all trigger functions (including validate_doubt_update).
--      - Changes read-only RLS helpers to SECURITY INVOKER (clears Lint 0029).
--      - Preserves authenticated EXECUTE strictly for authorized Flutter client RPCs.
--   4. "Unindexed foreign keys":
--      Creates covering indexes for foreign keys across announcements, attendance,
--      cloudflare_live_inputs, coupon_redemptions, courses, doubts, enrollments,
--      lecture_recordings, lessons, live_classes, purchases, study_materials,
--      test_submissions, tests, and batch_teachers.
--   5. "Unused Index":
--      Cleans up redundant indexes on cloudflare_live_inputs.
-- ==============================================================================

BEGIN;

-- ==============================================================================
-- PART 1: STORAGE BUCKET LISTING HARDENING (Storage Security Advisor)
-- ==============================================================================
DROP POLICY IF EXISTS "course_thumbnails_select_policy" ON storage.objects;
DROP POLICY IF EXISTS "Public Read Course Thumbnails" ON storage.objects;

-- Ensure doubt-attachments remains private
UPDATE storage.buckets SET public = FALSE WHERE id = 'doubt-attachments';

-- ==============================================================================
-- PART 2: GLOBAL REVOKE OF EXECUTE FROM PUBLIC & ANON (Fixes Lint 0028)
-- ==============================================================================
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon;

-- ==============================================================================
-- PART 3: REVOKE AUTHENTICATED EXECUTION ON TRIGGER & INTERNAL FUNCTIONS (Fixes Lint 0029)
-- ==============================================================================
-- 1. validate_doubt_update (Trigger function on doubts)
DO $$
BEGIN
    REVOKE EXECUTE ON FUNCTION public.validate_doubt_update() FROM PUBLIC, anon, authenticated;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

-- 2. handle_new_user (Trigger function on auth.users)
DO $$
BEGIN
    REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

-- 3. protect_batch_deletion_with_enrollments (Trigger function on batches)
DO $$
BEGIN
    REVOKE EXECUTE ON FUNCTION public.protect_batch_deletion_with_enrollments() FROM PUBLIC, anon, authenticated;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

-- 4. protect_profile_fields (Trigger function on profiles)
DO $$
BEGIN
    REVOKE EXECUTE ON FUNCTION public.protect_profile_fields() FROM PUBLIC, anon, authenticated;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

-- 5. check_duplicate_batch_timing (Trigger function on batches)
DO $$
BEGIN
    REVOKE EXECUTE ON FUNCTION public.check_duplicate_batch_timing() FROM PUBLIC, anon, authenticated;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

-- 6. enforce_batch_slot_capacity (Trigger function on batches)
DO $$
BEGIN
    REVOKE EXECUTE ON FUNCTION public.enforce_batch_slot_capacity() FROM PUBLIC, anon, authenticated;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

-- 7. update_updated_at_column (Trigger function on all tables)
DO $$
BEGIN
    REVOKE EXECUTE ON FUNCTION public.update_updated_at_column() FROM PUBLIC, anon, authenticated;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

-- 8. process_upcoming_class_reminders (Internal cron worker)
DO $$
BEGIN
    REVOKE EXECUTE ON FUNCTION public.process_upcoming_class_reminders() FROM PUBLIC, anon, authenticated;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

-- 9. check_lesson_course_match (Trigger/internal function)
DO $$
BEGIN
    REVOKE EXECUTE ON FUNCTION public.check_lesson_course_match() FROM PUBLIC, anon, authenticated;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

-- 10. Internal admin tools not called from client RPC
DO $$
BEGIN
    REVOKE EXECUTE ON FUNCTION public.get_batch_students(UUID) FROM PUBLIC, anon, authenticated;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$
BEGIN
    REVOKE EXECUTE ON FUNCTION public.set_primary_live_input(TEXT) FROM PUBLIC, anon, authenticated;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$
BEGIN
    REVOKE EXECUTE ON FUNCTION public.delete_cloudflare_live_input(TEXT, TEXT) FROM PUBLIC, anon, authenticated;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$
BEGIN
    REVOKE EXECUTE ON FUNCTION public.delete_cloudflare_live_input(TEXT) FROM PUBLIC, anon, authenticated;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

-- ==============================================================================
-- PART 4: CONVERT RLS HELPER FUNCTIONS TO SECURITY INVOKER (Fixes Lint 0029)
-- ==============================================================================
DO $$
BEGIN
    ALTER FUNCTION public.current_user_role() SECURITY INVOKER;
    GRANT EXECUTE ON FUNCTION public.current_user_role() TO authenticated;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$
BEGIN
    ALTER FUNCTION public.is_admin() SECURITY INVOKER;
    GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$
BEGIN
    ALTER FUNCTION public.is_teacher_or_admin() SECURITY INVOKER;
    GRANT EXECUTE ON FUNCTION public.is_teacher_or_admin() TO authenticated;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$
BEGIN
    ALTER FUNCTION public.is_teacher_for_batch(UUID) SECURITY INVOKER;
    GRANT EXECUTE ON FUNCTION public.is_teacher_for_batch(UUID) TO authenticated;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$
BEGIN
    ALTER FUNCTION public.is_teacher_for_course(UUID) SECURITY INVOKER;
    GRANT EXECUTE ON FUNCTION public.is_teacher_for_course(UUID) TO authenticated;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$
BEGIN
    ALTER FUNCTION public.is_enrolled_in_course(UUID) SECURITY INVOKER;
    GRANT EXECUTE ON FUNCTION public.is_enrolled_in_course(UUID) TO authenticated;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$
BEGIN
    ALTER FUNCTION public.has_study_material_access(UUID, UUID) SECURITY INVOKER;
    GRANT EXECUTE ON FUNCTION public.has_study_material_access(UUID, UUID) TO authenticated;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$
BEGIN
    ALTER FUNCTION public.has_test_access(UUID, UUID) SECURITY INVOKER;
    GRANT EXECUTE ON FUNCTION public.has_test_access(UUID, UUID) TO authenticated;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$
BEGIN
    ALTER FUNCTION public.can_take_test(UUID) SECURITY INVOKER;
    GRANT EXECUTE ON FUNCTION public.can_take_test(UUID) TO authenticated;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$
BEGIN
    ALTER FUNCTION public.validate_batch_live_schedule(UUID) SECURITY INVOKER;
    GRANT EXECUTE ON FUNCTION public.validate_batch_live_schedule(UUID) TO authenticated;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$
BEGIN
    ALTER FUNCTION public.register_device_token(TEXT, TEXT, TEXT) SECURITY INVOKER;
    GRANT EXECUTE ON FUNCTION public.register_device_token(TEXT, TEXT, TEXT) TO authenticated;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

-- ==============================================================================
-- PART 5: AUTHORIZED CLIENT RPCS (Preserved for Flutter App)
-- ==============================================================================
DO $$
BEGIN
    GRANT EXECUTE ON FUNCTION public.admin_create_teacher(TEXT, TEXT, TEXT) TO authenticated, service_role;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$
BEGIN
    GRANT EXECUTE ON FUNCTION public.admin_set_primary_batch_teacher(UUID, UUID) TO authenticated, service_role;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$
BEGIN
    GRANT EXECUTE ON FUNCTION public.admin_set_user_role(UUID, user_role) TO authenticated, service_role;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$
BEGIN
    GRANT EXECUTE ON FUNCTION public.enroll_student_free_or_coupon(UUID, TEXT) TO authenticated, service_role;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$
BEGIN
    GRANT EXECUTE ON FUNCTION public.get_admin_manual_collections_total() TO authenticated, service_role;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$
BEGIN
    GRANT EXECUTE ON FUNCTION public.get_test_paper(UUID) TO authenticated, service_role;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$
BEGIN
    GRANT EXECUTE ON FUNCTION public.start_authenticated_live_session(UUID, TEXT) TO authenticated, service_role;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$
BEGIN
    GRANT EXECUTE ON FUNCTION public.end_authenticated_live_session(UUID) TO authenticated, service_role;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$
BEGIN
    GRANT EXECUTE ON FUNCTION public.sync_lecture_recording(UUID, UUID, UUID, TEXT, TEXT, INT, TEXT, TEXT, TEXT, BOOLEAN) TO authenticated, service_role;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$
BEGIN
    GRANT EXECUTE ON FUNCTION public.promote_lecture_recording_status(TEXT, TEXT, INT, TEXT) TO authenticated, service_role;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

-- ==============================================================================
-- PART 6: INDEX COVERING FOR UNINDEXED FOREIGN KEYS (Performance Advisor)
-- ==============================================================================

-- 1. announcements
CREATE INDEX IF NOT EXISTS idx_announcements_course_id ON public.announcements(course_id);
CREATE INDEX IF NOT EXISTS idx_announcements_batch_id ON public.announcements(batch_id);

-- 2. attendance
CREATE INDEX IF NOT EXISTS idx_attendance_student_id ON public.attendance(student_id);
CREATE INDEX IF NOT EXISTS idx_attendance_batch_id ON public.attendance(batch_id);
CREATE INDEX IF NOT EXISTS idx_attendance_marked_by_teacher ON public.attendance(marked_by_teacher_id);

-- 3. cloudflare_live_inputs
CREATE INDEX IF NOT EXISTS idx_cloudflare_live_inputs_batch_id ON public.cloudflare_live_inputs(batch_id);
CREATE INDEX IF NOT EXISTS idx_cloudflare_live_inputs_created_by ON public.cloudflare_live_inputs(created_by);

-- 4. coupon_redemptions
CREATE INDEX IF NOT EXISTS idx_coupon_redemptions_coupon_id ON public.coupon_redemptions(coupon_id);
CREATE INDEX IF NOT EXISTS idx_coupon_redemptions_student_id ON public.coupon_redemptions(student_id);
CREATE INDEX IF NOT EXISTS idx_coupon_redemptions_batch_id ON public.coupon_redemptions(batch_id);

-- 5. courses
CREATE INDEX IF NOT EXISTS idx_courses_teacher_id ON public.courses(teacher_id);

-- 6. doubts
CREATE INDEX IF NOT EXISTS idx_doubts_student_id ON public.doubts(student_id);
CREATE INDEX IF NOT EXISTS idx_doubts_batch_id ON public.doubts(batch_id);
CREATE INDEX IF NOT EXISTS idx_doubts_resolved_by ON public.doubts(resolved_by);

-- 7. enrollments
CREATE INDEX IF NOT EXISTS idx_enrollments_student_id ON public.enrollments(student_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_batch_id ON public.enrollments(batch_id);

-- 8. lecture_recordings
CREATE INDEX IF NOT EXISTS idx_lecture_recordings_course_id ON public.lecture_recordings(course_id);
CREATE INDEX IF NOT EXISTS idx_lecture_recordings_batch_id ON public.lecture_recordings(batch_id);
CREATE INDEX IF NOT EXISTS idx_lecture_recordings_live_class_id ON public.lecture_recordings(live_class_id);
CREATE INDEX IF NOT EXISTS idx_lecture_recordings_teacher_id ON public.lecture_recordings(teacher_id);

-- 9. lessons
CREATE INDEX IF NOT EXISTS idx_lessons_batch_id ON public.lessons(batch_id);

-- 10. live_classes
CREATE INDEX IF NOT EXISTS idx_live_classes_batch_id ON public.live_classes(batch_id);
CREATE INDEX IF NOT EXISTS idx_live_classes_teacher_id ON public.live_classes(teacher_id);

-- 11. purchases
CREATE INDEX IF NOT EXISTS idx_purchases_student_id ON public.purchases(student_id);
CREATE INDEX IF NOT EXISTS idx_purchases_batch_id ON public.purchases(batch_id);

-- 12. study_materials
CREATE INDEX IF NOT EXISTS idx_study_materials_course_id ON public.study_materials(course_id);
CREATE INDEX IF NOT EXISTS idx_study_materials_batch_id ON public.study_materials(batch_id);
CREATE INDEX IF NOT EXISTS idx_study_materials_uploaded_by ON public.study_materials(uploaded_by);

-- 13. test_submissions
CREATE INDEX IF NOT EXISTS idx_test_submissions_test_id ON public.test_submissions(test_id);
CREATE INDEX IF NOT EXISTS idx_test_submissions_student_id ON public.test_submissions(student_id);

-- 14. tests
CREATE INDEX IF NOT EXISTS idx_tests_course_id ON public.tests(course_id);
CREATE INDEX IF NOT EXISTS idx_tests_batch_id ON public.tests(batch_id);

-- 15. batch_teachers
CREATE INDEX IF NOT EXISTS idx_batch_teachers_batch_id ON public.batch_teachers(batch_id);
CREATE INDEX IF NOT EXISTS idx_batch_teachers_teacher_id ON public.batch_teachers(teacher_id);

-- ==============================================================================
-- PART 7: CLEANUP OF REDUNDANT UNUSED INDEXES (Performance Advisor)
-- ==============================================================================
-- Drop redundant index on cloudflare_live_inputs (uid already has unique constraint)
DROP INDEX IF EXISTS public.idx_cloudflare_live_inputs_uid;
DROP INDEX IF EXISTS public.idx_cloudflare_live_inputs_active;
DROP INDEX IF EXISTS public.idx_cloudflare_live_inputs_primary;

COMMIT;
