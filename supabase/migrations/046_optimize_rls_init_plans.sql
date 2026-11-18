-- ==============================================================================
-- Migration 046: Database Performance & Security Advisor Remediation
-- Database: PostgreSQL / Supabase
-- Target: Modern Classes Patna
--
-- Description:
--   Complete, idempotent resolution for all 43 issues shown in the Supabase Advisor:
--   1. Fixes "Function Search Path Mutable" across all 8 functions by locking search_path.
--   2. Fixes "Public Can Execute SECURITY DEFINER Function" across all 7 functions by
--      revoking EXECUTE from PUBLIC and anon, granting to authenticated & service_role.
--   3. Fixes "Public Bucket Allows Listing" for course-thumbnails and doubt-attachments.
--   4. Drops ALL legacy duplicate policies across 21 tables dynamically.
--   5. Recreates non-overlapping policies (one for SELECT, INSERT, UPDATE, DELETE)
--      using scalar subqueries (SELECT ...) to fix "Auth RLS Initialization Plan"
--      and "Multiple Permissive Policies".
-- ==============================================================================

BEGIN;

-- ==============================================================================
-- PART 1: FIX FUNCTION SEARCH PATH MUTABLE (Security Advisor)
-- ==============================================================================
ALTER FUNCTION public.update_updated_at_column() SET search_path = public, pg_temp;

DO $$
BEGIN
    ALTER FUNCTION public.check_lesson_course_match() SET search_path = public, pg_temp;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$
BEGIN
    ALTER FUNCTION public.update_purchase_acknowledgement(TEXT, TEXT) SET search_path = public, pg_temp;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$
BEGIN
    ALTER FUNCTION public.current_user_role() SET search_path = public, pg_temp;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$
BEGIN
    ALTER FUNCTION public.is_admin() SET search_path = public, pg_temp;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$
BEGIN
    ALTER FUNCTION public.is_teacher_or_admin() SET search_path = public, pg_temp;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$
BEGIN
    ALTER FUNCTION public.process_upcoming_class_reminders() SET search_path = public, pg_temp;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

DO $$
BEGIN
    ALTER FUNCTION public.register_device_token(TEXT, TEXT, TEXT) SET search_path = public, pg_temp;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

-- ==============================================================================
-- PART 2: RESTRICT PUBLIC EXECUTE ON SECURITY DEFINER FUNCTIONS (Security Advisor)
-- ==============================================================================
-- 1. admin_set_user_role
DO $$
BEGIN
    REVOKE EXECUTE ON FUNCTION public.admin_set_user_role(UUID, user_role) FROM PUBLIC, anon;
    GRANT EXECUTE ON FUNCTION public.admin_set_user_role(UUID, user_role) TO authenticated, service_role;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

-- 2. can_take_test
DO $$
BEGIN
    REVOKE EXECUTE ON FUNCTION public.can_take_test(UUID) FROM PUBLIC, anon;
    GRANT EXECUTE ON FUNCTION public.can_take_test(UUID) TO authenticated, service_role;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

-- 3. check_duplicate_batch_timing
DO $$
BEGIN
    REVOKE EXECUTE ON FUNCTION public.check_duplicate_batch_timing() FROM PUBLIC, anon;
    GRANT EXECUTE ON FUNCTION public.check_duplicate_batch_timing() TO authenticated, service_role;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

-- 4. current_user_role
DO $$
BEGIN
    REVOKE EXECUTE ON FUNCTION public.current_user_role() FROM PUBLIC, anon;
    GRANT EXECUTE ON FUNCTION public.current_user_role() TO authenticated, service_role;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

-- 5. delete_cloudflare_live_input
DO $$
BEGIN
    REVOKE EXECUTE ON FUNCTION public.delete_cloudflare_live_input(TEXT, TEXT) FROM PUBLIC, anon;
    GRANT EXECUTE ON FUNCTION public.delete_cloudflare_live_input(TEXT, TEXT) TO authenticated, service_role;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;
DO $$
BEGIN
    REVOKE EXECUTE ON FUNCTION public.delete_cloudflare_live_input(TEXT) FROM PUBLIC, anon;
    GRANT EXECUTE ON FUNCTION public.delete_cloudflare_live_input(TEXT) TO authenticated, service_role;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

-- 6. end_authenticated_live_session
DO $$
BEGIN
    REVOKE EXECUTE ON FUNCTION public.end_authenticated_live_session(UUID) FROM PUBLIC, anon;
    GRANT EXECUTE ON FUNCTION public.end_authenticated_live_session(UUID) TO authenticated, service_role;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

-- 7. enforce_batch_slot_capacity
DO $$
BEGIN
    REVOKE EXECUTE ON FUNCTION public.enforce_batch_slot_capacity() FROM PUBLIC, anon;
    GRANT EXECUTE ON FUNCTION public.enforce_batch_slot_capacity() TO authenticated, service_role;
EXCEPTION WHEN undefined_function THEN NULL;
END $$;

-- ==============================================================================
-- PART 3: PUBLIC BUCKET LISTING HARDENING (Storage Security Advisor)
-- ==============================================================================
-- 1. Restrict course-thumbnails metadata listing to authenticated users
DROP POLICY IF EXISTS "Public Read Course Thumbnails" ON storage.objects;
DROP POLICY IF EXISTS "course_thumbnails_select_policy" ON storage.objects;

CREATE POLICY "course_thumbnails_select_policy" ON storage.objects
FOR SELECT TO authenticated
USING (bucket_id = 'course-thumbnails');

-- 2. Make doubt-attachments private and restrict access to authenticated users
UPDATE storage.buckets SET public = FALSE WHERE id = 'doubt-attachments';

DROP POLICY IF EXISTS "Public Read Doubt Attachments" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Read Doubt Attachments" ON storage.objects;
DROP POLICY IF EXISTS "Student Upload Doubt Attachments" ON storage.objects;
DROP POLICY IF EXISTS "doubt_attachments_select_policy" ON storage.objects;
DROP POLICY IF EXISTS "doubt_attachments_insert_policy" ON storage.objects;

CREATE POLICY "doubt_attachments_select_policy" ON storage.objects
FOR SELECT TO authenticated
USING (bucket_id = 'doubt-attachments');

CREATE POLICY "doubt_attachments_insert_policy" ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'doubt-attachments');

-- ==============================================================================
-- PART 4: DYNAMIC DROP OF OLD DUPLICATE RLS POLICIES
-- ==============================================================================
-- Ensures that all overlapping policies from previous migrations (002-045)
-- are completely cleaned up, eliminating "Multiple Permissive Policies".
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT schemaname, tablename, policyname
        FROM pg_policies
        WHERE schemaname = 'public'
          AND tablename IN (
              'announcements',
              'attendance',
              'batch_teachers',
              'batches',
              'cloudflare_live_inputs',
              'coupon_redemptions',
              'coupons',
              'courses',
              'doubts',
              'enrollments',
              'lecture_recordings',
              'lessons',
              'live_classes',
              'platform_settings',
              'profiles',
              'purchases',
              'study_materials',
              'test_submissions',
              'tests',
              'transactions',
              'user_device_tokens'
          )
    ) LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I;', r.policyname, r.schemaname, r.tablename);
    END LOOP;
END $$;

-- ==============================================================================
-- PART 5: RECREATE CLEAN, NON-OVERLAPPING POLICIES WITH SCALAR SUBQUERIES
-- ==============================================================================

-- 1. ANNOUNCEMENTS
CREATE POLICY "announcements_select_policy" ON public.announcements
FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY "announcements_insert_policy" ON public.announcements
FOR INSERT TO authenticated WITH CHECK ((SELECT public.is_admin()));

CREATE POLICY "announcements_update_policy" ON public.announcements
FOR UPDATE TO authenticated
USING ((SELECT public.is_admin()))
WITH CHECK ((SELECT public.is_admin()));

CREATE POLICY "announcements_delete_policy" ON public.announcements
FOR DELETE TO authenticated USING ((SELECT public.is_admin()));

-- 2. ATTENDANCE
CREATE POLICY "attendance_select_policy" ON public.attendance
FOR SELECT TO authenticated
USING (
    ((SELECT public.current_user_role()) = 'student' AND EXISTS (
        SELECT 1 FROM public.enrollments e 
        WHERE e.batch_id = attendance.batch_id 
          AND e.student_id = (SELECT auth.uid()) 
          AND e.status = 'active'
    ))
    OR (SELECT public.is_teacher_for_batch(batch_id)) 
    OR (SELECT public.is_admin())
);

CREATE POLICY "attendance_insert_policy" ON public.attendance
FOR INSERT TO authenticated
WITH CHECK ((SELECT public.is_teacher_for_batch(batch_id)) OR (SELECT public.is_admin()));

CREATE POLICY "attendance_update_policy" ON public.attendance
FOR UPDATE TO authenticated
USING ((SELECT public.is_teacher_for_batch(batch_id)) OR (SELECT public.is_admin()))
WITH CHECK ((SELECT public.is_teacher_for_batch(batch_id)) OR (SELECT public.is_admin()));

CREATE POLICY "attendance_delete_policy" ON public.attendance
FOR DELETE TO authenticated USING ((SELECT public.is_admin()));

-- 3. BATCH_TEACHERS
CREATE POLICY "batch_teachers_select_policy" ON public.batch_teachers
FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY "batch_teachers_insert_policy" ON public.batch_teachers
FOR INSERT TO authenticated WITH CHECK ((SELECT public.is_admin()));

CREATE POLICY "batch_teachers_update_policy" ON public.batch_teachers
FOR UPDATE TO authenticated
USING ((SELECT public.is_admin()))
WITH CHECK ((SELECT public.is_admin()));

CREATE POLICY "batch_teachers_delete_policy" ON public.batch_teachers
FOR DELETE TO authenticated USING ((SELECT public.is_admin()));

-- 4. BATCHES
CREATE POLICY "batches_select_policy" ON public.batches
FOR SELECT TO authenticated USING (TRUE);

CREATE POLICY "batches_insert_policy" ON public.batches
FOR INSERT TO authenticated WITH CHECK ((SELECT public.is_teacher_or_admin()));

CREATE POLICY "batches_update_policy" ON public.batches
FOR UPDATE TO authenticated
USING ((SELECT public.is_teacher_or_admin()))
WITH CHECK ((SELECT public.is_teacher_or_admin()));

CREATE POLICY "batches_delete_policy" ON public.batches
FOR DELETE TO authenticated USING ((SELECT public.is_admin()));

-- 5. CLOUDFLARE_LIVE_INPUTS
CREATE POLICY "cloudflare_live_inputs_select_policy" ON public.cloudflare_live_inputs
FOR SELECT TO authenticated USING ((SELECT public.is_teacher_or_admin()));

CREATE POLICY "cloudflare_live_inputs_insert_policy" ON public.cloudflare_live_inputs
FOR INSERT TO authenticated WITH CHECK ((SELECT public.is_admin()));

CREATE POLICY "cloudflare_live_inputs_update_policy" ON public.cloudflare_live_inputs
FOR UPDATE TO authenticated
USING ((SELECT public.is_admin()))
WITH CHECK ((SELECT public.is_admin()));

CREATE POLICY "cloudflare_live_inputs_delete_policy" ON public.cloudflare_live_inputs
FOR DELETE TO authenticated USING ((SELECT public.is_admin()));

-- 6. COUPON_REDEMPTIONS
CREATE POLICY "coupon_redemptions_select_policy" ON public.coupon_redemptions
FOR SELECT TO authenticated
USING (student_id = (SELECT auth.uid()) OR (SELECT public.is_admin()));

CREATE POLICY "coupon_redemptions_insert_policy" ON public.coupon_redemptions
FOR INSERT TO authenticated
WITH CHECK (student_id = (SELECT auth.uid()) OR (SELECT public.is_admin()));

CREATE POLICY "coupon_redemptions_update_policy" ON public.coupon_redemptions
FOR UPDATE TO authenticated
USING ((SELECT public.is_admin()))
WITH CHECK ((SELECT public.is_admin()));

CREATE POLICY "coupon_redemptions_delete_policy" ON public.coupon_redemptions
FOR DELETE TO authenticated USING ((SELECT public.is_admin()));

-- 7. COUPONS
CREATE POLICY "coupons_select_policy" ON public.coupons
FOR SELECT USING (
    (is_active = true AND (expires_at IS NULL OR expires_at > TIMEZONE('utc', NOW())))
    OR (SELECT public.is_admin())
);

CREATE POLICY "coupons_insert_policy" ON public.coupons
FOR INSERT TO authenticated WITH CHECK ((SELECT public.is_admin()));

CREATE POLICY "coupons_update_policy" ON public.coupons
FOR UPDATE TO authenticated
USING ((SELECT public.is_admin()))
WITH CHECK ((SELECT public.is_admin()));

CREATE POLICY "coupons_delete_policy" ON public.coupons
FOR DELETE TO authenticated USING ((SELECT public.is_admin()));

-- 8. COURSES (Uses is_active; does NOT use is_published)
CREATE POLICY "courses_select_policy" ON public.courses
FOR SELECT USING (
    is_active = TRUE 
    OR (SELECT public.is_admin())
);

CREATE POLICY "courses_insert_policy" ON public.courses
FOR INSERT TO authenticated WITH CHECK ((SELECT public.is_admin()));

CREATE POLICY "courses_update_policy" ON public.courses
FOR UPDATE TO authenticated
USING ((SELECT public.is_admin()))
WITH CHECK ((SELECT public.is_admin()));

CREATE POLICY "courses_delete_policy" ON public.courses
FOR DELETE TO authenticated USING ((SELECT public.is_admin()));

-- 9. DOUBTS
CREATE POLICY "doubts_select_policy" ON public.doubts
FOR SELECT TO authenticated
USING (
    student_id = (SELECT auth.uid())
    OR (SELECT public.is_teacher_for_batch(batch_id))
    OR (SELECT public.is_admin())
);

CREATE POLICY "doubts_insert_policy" ON public.doubts
FOR INSERT TO authenticated
WITH CHECK (
    student_id = (SELECT auth.uid())
    AND EXISTS (
        SELECT 1 FROM public.enrollments 
        WHERE student_id = (SELECT auth.uid()) 
          AND batch_id = doubts.batch_id 
          AND status = 'active'
    )
    AND is_resolved = false
    AND faculty_reply IS NULL
    AND faculty_name IS NULL
    AND resolved_by IS NULL
    AND resolved_at IS NULL
);

CREATE POLICY "doubts_update_policy" ON public.doubts
FOR UPDATE TO authenticated
USING (
    (SELECT public.is_teacher_for_batch(batch_id))
    OR (SELECT public.is_admin())
)
WITH CHECK (
    (SELECT public.is_teacher_for_batch(batch_id))
    OR (SELECT public.is_admin())
);

CREATE POLICY "doubts_delete_policy" ON public.doubts
FOR DELETE TO authenticated USING ((SELECT public.is_admin()));

-- 10. ENROLLMENTS
CREATE POLICY "enrollments_select_policy" ON public.enrollments
FOR SELECT TO authenticated
USING (
    student_id = (SELECT auth.uid())
    OR EXISTS (
        SELECT 1 FROM public.batch_teachers 
        WHERE teacher_id = (SELECT auth.uid()) 
          AND batch_id = enrollments.batch_id
    )
    OR (SELECT public.is_admin())
);

CREATE POLICY "enrollments_insert_policy" ON public.enrollments
FOR INSERT TO authenticated WITH CHECK ((SELECT public.is_admin()));

CREATE POLICY "enrollments_update_policy" ON public.enrollments
FOR UPDATE TO authenticated
USING ((SELECT public.is_admin()))
WITH CHECK ((SELECT public.is_admin()));

CREATE POLICY "enrollments_delete_policy" ON public.enrollments
FOR DELETE TO authenticated USING ((SELECT public.is_admin()));

-- 11. LECTURE_RECORDINGS
ALTER TABLE public.lecture_recordings ADD COLUMN IF NOT EXISTS is_published BOOLEAN NOT NULL DEFAULT TRUE;

CREATE POLICY "lecture_recordings_select_policy" ON public.lecture_recordings
FOR SELECT TO authenticated
USING (
    (SELECT public.is_admin())
    OR teacher_id = (SELECT auth.uid())
    OR (SELECT public.is_teacher_for_batch(batch_id))
    OR (
        status = 'ready'
        AND is_published = TRUE
        AND EXISTS (
            SELECT 1 
            FROM public.enrollments e
            WHERE e.student_id = (SELECT auth.uid())
              AND e.status = 'active'
              AND e.batch_id = lecture_recordings.batch_id
        )
    )
);

CREATE POLICY "lecture_recordings_insert_policy" ON public.lecture_recordings
FOR INSERT TO authenticated
WITH CHECK (
    (SELECT public.is_admin())
    OR (SELECT public.is_teacher_for_batch(batch_id))
);

CREATE POLICY "lecture_recordings_update_policy" ON public.lecture_recordings
FOR UPDATE TO authenticated
USING (
    (SELECT public.is_admin())
    OR (SELECT public.is_teacher_for_batch(batch_id))
)
WITH CHECK (
    (SELECT public.is_admin())
    OR (SELECT public.is_teacher_for_batch(batch_id))
);

CREATE POLICY "lecture_recordings_delete_policy" ON public.lecture_recordings
FOR DELETE TO authenticated USING ((SELECT public.is_admin()));

-- 12. LESSONS
CREATE POLICY "lessons_select_policy" ON public.lessons
FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.enrollments 
        WHERE student_id = (SELECT auth.uid()) 
          AND batch_id = lessons.batch_id 
          AND status = 'active'
    )
    OR EXISTS (
        SELECT 1 FROM public.batch_teachers 
        WHERE teacher_id = (SELECT auth.uid()) 
          AND batch_id = lessons.batch_id
    )
    OR (SELECT public.is_admin())
);

CREATE POLICY "lessons_insert_policy" ON public.lessons
FOR INSERT TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.batch_teachers 
        WHERE teacher_id = (SELECT auth.uid()) 
          AND batch_id = lessons.batch_id
    )
    OR (SELECT public.is_admin())
);

CREATE POLICY "lessons_update_policy" ON public.lessons
FOR UPDATE TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.batch_teachers 
        WHERE teacher_id = (SELECT auth.uid()) 
          AND batch_id = lessons.batch_id
    )
    OR (SELECT public.is_admin())
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.batch_teachers 
        WHERE teacher_id = (SELECT auth.uid()) 
          AND batch_id = lessons.batch_id
    )
    OR (SELECT public.is_admin())
);

CREATE POLICY "lessons_delete_policy" ON public.lessons
FOR DELETE TO authenticated USING ((SELECT public.is_admin()));

-- 13. LIVE_CLASSES
CREATE POLICY "live_classes_select_policy" ON public.live_classes
FOR SELECT TO authenticated
USING (
    ((SELECT public.current_user_role()) = 'student' AND EXISTS (
        SELECT 1 FROM public.enrollments e 
        WHERE e.batch_id = live_classes.batch_id 
          AND e.student_id = (SELECT auth.uid()) 
          AND e.status = 'active'
    ))
    OR (SELECT public.is_teacher_for_batch(batch_id)) 
    OR (SELECT public.is_admin())
);

CREATE POLICY "live_classes_insert_policy" ON public.live_classes
FOR INSERT TO authenticated
WITH CHECK (
    (SELECT public.is_teacher_for_batch(batch_id)) 
    OR (SELECT public.is_admin())
);

CREATE POLICY "live_classes_update_policy" ON public.live_classes
FOR UPDATE TO authenticated
USING (
    (SELECT public.is_teacher_for_batch(batch_id)) 
    OR (SELECT public.is_admin())
)
WITH CHECK (
    (SELECT public.is_teacher_for_batch(batch_id)) 
    OR (SELECT public.is_admin())
);

CREATE POLICY "live_classes_delete_policy" ON public.live_classes
FOR DELETE TO authenticated USING ((SELECT public.is_admin()));

-- 14. PLATFORM_SETTINGS
CREATE POLICY "platform_settings_select_policy" ON public.platform_settings
FOR SELECT TO authenticated USING (true);

CREATE POLICY "platform_settings_insert_policy" ON public.platform_settings
FOR INSERT TO authenticated WITH CHECK ((SELECT public.is_admin()));

CREATE POLICY "platform_settings_update_policy" ON public.platform_settings
FOR UPDATE TO authenticated
USING ((SELECT public.is_admin()))
WITH CHECK ((SELECT public.is_admin()));

CREATE POLICY "platform_settings_delete_policy" ON public.platform_settings
FOR DELETE TO authenticated USING ((SELECT public.is_admin()));

-- 15. PROFILES
CREATE POLICY "profiles_select_policy" ON public.profiles
FOR SELECT TO authenticated USING (true);

CREATE POLICY "profiles_insert_policy" ON public.profiles
FOR INSERT TO authenticated
WITH CHECK (id = (SELECT auth.uid()) OR (SELECT public.is_admin()));

CREATE POLICY "profiles_update_policy" ON public.profiles
FOR UPDATE TO authenticated
USING (id = (SELECT auth.uid()) OR (SELECT public.is_admin()))
WITH CHECK (id = (SELECT auth.uid()) OR (SELECT public.is_admin()));

CREATE POLICY "profiles_delete_policy" ON public.profiles
FOR DELETE TO authenticated USING ((SELECT public.is_admin()));

-- 16. PURCHASES
CREATE POLICY "purchases_select_policy" ON public.purchases 
FOR SELECT TO authenticated
USING (student_id = (SELECT auth.uid()) OR (SELECT public.is_admin()));

CREATE POLICY "purchases_insert_policy" ON public.purchases
FOR INSERT TO authenticated WITH CHECK ((SELECT public.is_admin()));

CREATE POLICY "purchases_update_policy" ON public.purchases
FOR UPDATE TO authenticated
USING ((SELECT public.is_admin()))
WITH CHECK ((SELECT public.is_admin()));

CREATE POLICY "purchases_delete_policy" ON public.purchases
FOR DELETE TO authenticated USING ((SELECT public.is_admin()));

-- 17. STUDY_MATERIALS
CREATE POLICY "study_materials_select_policy" ON public.study_materials
FOR SELECT TO authenticated
USING (
    ((SELECT public.current_user_role()) = 'student' AND public.has_study_material_access(course_id, batch_id))
    OR (batch_id IS NOT NULL AND (SELECT public.is_teacher_for_batch(batch_id)))
    OR (batch_id IS NULL AND (SELECT public.is_teacher_for_course(course_id)))
    OR (SELECT public.is_admin())
);

CREATE POLICY "study_materials_insert_policy" ON public.study_materials
FOR INSERT TO authenticated
WITH CHECK (
    (batch_id IS NOT NULL AND (SELECT public.is_teacher_for_batch(batch_id)))
    OR (SELECT public.is_admin())
);

CREATE POLICY "study_materials_update_policy" ON public.study_materials
FOR UPDATE TO authenticated
USING (
    (batch_id IS NOT NULL AND (SELECT public.is_teacher_for_batch(batch_id)))
    OR (SELECT public.is_admin())
)
WITH CHECK (
    (batch_id IS NOT NULL AND (SELECT public.is_teacher_for_batch(batch_id)))
    OR (SELECT public.is_admin())
);

CREATE POLICY "study_materials_delete_policy" ON public.study_materials
FOR DELETE TO authenticated
USING (
    (batch_id IS NOT NULL AND (SELECT public.is_teacher_for_batch(batch_id)))
    OR (SELECT public.is_admin())
);

-- 18. TEST_SUBMISSIONS
CREATE POLICY "test_submissions_select_policy" ON public.test_submissions
FOR SELECT TO authenticated
USING (
    ((SELECT public.current_user_role()) = 'student' AND student_id = (SELECT auth.uid()))
    OR EXISTS (
        SELECT 1 FROM public.tests t
        WHERE t.id = test_submissions.test_id
          AND (
              (t.batch_id IS NOT NULL AND (SELECT public.is_teacher_for_batch(t.batch_id)))
              OR (t.batch_id IS NULL AND (SELECT public.is_teacher_for_course(t.course_id)))
          )
    )
    OR (SELECT public.is_admin())
);

CREATE POLICY "test_submissions_insert_policy" ON public.test_submissions
FOR INSERT TO authenticated
WITH CHECK (
    ((SELECT public.current_user_role()) = 'student' AND student_id = (SELECT auth.uid()) AND public.can_take_test(test_id))
    OR (SELECT public.is_admin())
);

CREATE POLICY "test_submissions_update_policy" ON public.test_submissions
FOR UPDATE TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.tests t
        WHERE t.id = test_submissions.test_id
          AND t.batch_id IS NOT NULL AND (SELECT public.is_teacher_for_batch(t.batch_id))
    )
    OR (SELECT public.is_admin())
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.tests t
        WHERE t.id = test_submissions.test_id
          AND t.batch_id IS NOT NULL AND (SELECT public.is_teacher_for_batch(t.batch_id))
    )
    OR (SELECT public.is_admin())
);

CREATE POLICY "test_submissions_delete_policy" ON public.test_submissions
FOR DELETE TO authenticated USING ((SELECT public.is_admin()));

-- 19. TESTS
CREATE POLICY "tests_select_policy" ON public.tests
FOR SELECT TO authenticated
USING (
    ((SELECT public.current_user_role()) = 'student' AND status = 'published' AND public.has_test_access(course_id, batch_id))
    OR (batch_id IS NOT NULL AND (SELECT public.is_teacher_for_batch(batch_id)))
    OR (batch_id IS NULL AND (SELECT public.is_teacher_for_course(course_id)))
    OR (SELECT public.is_admin())
);

CREATE POLICY "tests_insert_policy" ON public.tests
FOR INSERT TO authenticated
WITH CHECK (
    (batch_id IS NOT NULL AND (SELECT public.is_teacher_for_batch(batch_id)))
    OR (SELECT public.is_admin())
);

CREATE POLICY "tests_update_policy" ON public.tests
FOR UPDATE TO authenticated
USING (
    (batch_id IS NOT NULL AND (SELECT public.is_teacher_for_batch(batch_id)))
    OR (SELECT public.is_admin())
)
WITH CHECK (
    (batch_id IS NOT NULL AND (SELECT public.is_teacher_for_batch(batch_id)))
    OR (SELECT public.is_admin())
);

CREATE POLICY "tests_delete_policy" ON public.tests
FOR DELETE TO authenticated
USING (
    (batch_id IS NOT NULL AND (SELECT public.is_teacher_for_batch(batch_id)))
    OR (SELECT public.is_admin())
);

-- 20. TRANSACTIONS
CREATE POLICY "transactions_select_policy" ON public.transactions
FOR SELECT TO authenticated
USING (student_id = (SELECT auth.uid()) OR (SELECT public.is_admin()));

CREATE POLICY "transactions_insert_policy" ON public.transactions
FOR INSERT TO authenticated WITH CHECK ((SELECT public.is_admin()));

CREATE POLICY "transactions_update_policy" ON public.transactions
FOR UPDATE TO authenticated
USING ((SELECT public.is_admin()))
WITH CHECK ((SELECT public.is_admin()));

CREATE POLICY "transactions_delete_policy" ON public.transactions
FOR DELETE TO authenticated USING ((SELECT public.is_admin()));

-- 21. USER_DEVICE_TOKENS
CREATE POLICY "user_device_tokens_select_policy" ON public.user_device_tokens
FOR SELECT TO authenticated
USING (user_id = (SELECT auth.uid()) OR (SELECT public.is_admin()));

CREATE POLICY "user_device_tokens_insert_policy" ON public.user_device_tokens
FOR INSERT TO authenticated
WITH CHECK (user_id = (SELECT auth.uid()) OR (SELECT public.is_admin()));

CREATE POLICY "user_device_tokens_update_policy" ON public.user_device_tokens
FOR UPDATE TO authenticated
USING (user_id = (SELECT auth.uid()) OR (SELECT public.is_admin()))
WITH CHECK (user_id = (SELECT auth.uid()) OR (SELECT public.is_admin()));

CREATE POLICY "user_device_tokens_delete_policy" ON public.user_device_tokens
FOR DELETE TO authenticated
USING (user_id = (SELECT auth.uid()) OR (SELECT public.is_admin()));

COMMIT;
