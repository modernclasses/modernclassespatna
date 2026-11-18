-- 018_scope_teacher_access_to_assigned_batches.sql

-- 1. Helper function for course-level read access
CREATE OR REPLACE FUNCTION public.is_teacher_for_course(p_course_id UUID)
RETURNS BOOLEAN AS $$$
    SELECT EXISTS (
        SELECT 1 
        FROM public.batches b
        JOIN public.batch_teachers bt ON bt.batch_id = b.id
        WHERE b.course_id = p_course_id
          AND bt.teacher_id = auth.uid()
    );
$$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE EXECUTE ON FUNCTION public.is_teacher_for_course(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_teacher_for_course(UUID) TO authenticated, service_role;

-- ============================================================================
-- LIVE CLASSES
-- ============================================================================
DROP POLICY IF EXISTS "View live classes if authenticated" ON public.live_classes;
DROP POLICY IF EXISTS "Teachers and admins manage live classes" ON public.live_classes;

CREATE POLICY "View live classes"
    ON public.live_classes FOR SELECT
    TO authenticated
    USING (
        (public.current_user_role() = 'student' AND EXISTS (
            SELECT 1 FROM public.enrollments e 
            WHERE e.batch_id = live_classes.batch_id 
              AND e.student_id = auth.uid() 
              AND e.status = 'active'
        ))
        OR public.is_teacher_for_batch(batch_id) 
        OR public.is_admin()
    );

CREATE POLICY "Teachers and admins manage live classes"
    ON public.live_classes FOR ALL
    TO authenticated
    USING (public.is_teacher_for_batch(batch_id) OR public.is_admin())
    WITH CHECK (public.is_teacher_for_batch(batch_id) OR public.is_admin());

-- ============================================================================
-- ATTENDANCE
-- ============================================================================
DROP POLICY IF EXISTS "View attendance records" ON public.attendance;
DROP POLICY IF EXISTS "Teachers and admins mark attendance" ON public.attendance;

CREATE POLICY "View attendance records"
    ON public.attendance FOR SELECT
    TO authenticated
    USING (
        (public.current_user_role() = 'student' AND EXISTS (
            SELECT 1 FROM public.enrollments e 
            WHERE e.batch_id = attendance.batch_id 
              AND e.student_id = auth.uid() 
              AND e.status = 'active'
        ))
        OR public.is_teacher_for_batch(batch_id) 
        OR public.is_admin()
    );

CREATE POLICY "Teachers and admins mark attendance"
    ON public.attendance FOR ALL
    TO authenticated
    USING (public.is_teacher_for_batch(batch_id) OR public.is_admin())
    WITH CHECK (public.is_teacher_for_batch(batch_id) OR public.is_admin());

-- ============================================================================
-- STUDY MATERIALS
-- ============================================================================
DROP POLICY IF EXISTS "Enrolled students view study materials" ON public.study_materials;
DROP POLICY IF EXISTS "Teachers and admins manage study materials" ON public.study_materials;

CREATE POLICY "View study materials"
    ON public.study_materials FOR SELECT
    TO authenticated
    USING (
        (public.current_user_role() = 'student' AND public.has_study_material_access(course_id, batch_id))
        OR (batch_id IS NOT NULL AND public.is_teacher_for_batch(batch_id))
        OR (batch_id IS NULL AND public.is_teacher_for_course(course_id))
        OR public.is_admin()
    );

CREATE POLICY "Teachers and admins manage study materials"
    ON public.study_materials FOR ALL
    TO authenticated
    USING ((batch_id IS NOT NULL AND public.is_teacher_for_batch(batch_id)) OR public.is_admin())
    WITH CHECK ((batch_id IS NOT NULL AND public.is_teacher_for_batch(batch_id)) OR public.is_admin());

-- ============================================================================
-- TESTS
-- ============================================================================
DROP POLICY IF EXISTS "Enrolled students view published tests" ON public.tests;
DROP POLICY IF EXISTS "Teachers and admins manage tests" ON public.tests;

CREATE POLICY "View published tests"
    ON public.tests FOR SELECT
    TO authenticated
    USING (
        (public.current_user_role() = 'student' AND status = 'published' AND public.has_test_access(course_id, batch_id))
        OR (batch_id IS NOT NULL AND public.is_teacher_for_batch(batch_id))
        OR (batch_id IS NULL AND public.is_teacher_for_course(course_id))
        OR public.is_admin()
    );

CREATE POLICY "Teachers and admins manage tests"
    ON public.tests FOR ALL
    TO authenticated
    USING ((batch_id IS NOT NULL AND public.is_teacher_for_batch(batch_id)) OR public.is_admin())
    WITH CHECK ((batch_id IS NOT NULL AND public.is_teacher_for_batch(batch_id)) OR public.is_admin());

-- ============================================================================
-- TEST SUBMISSIONS
-- ============================================================================
DROP POLICY IF EXISTS "Students view own test submissions" ON public.test_submissions;
DROP POLICY IF EXISTS "Students manage own test submissions" ON public.test_submissions; -- just in case
DROP POLICY IF EXISTS "Students insert own authorized test submissions" ON public.test_submissions;
DROP POLICY IF EXISTS "Teachers and admins update test submissions" ON public.test_submissions;
DROP POLICY IF EXISTS "Teachers and admins delete test submissions" ON public.test_submissions;

CREATE POLICY "Students view own test submissions"
    ON public.test_submissions FOR SELECT
    TO authenticated
    USING (
        (public.current_user_role() = 'student' AND auth.uid() = student_id)
        OR EXISTS (
            SELECT 1 FROM public.tests t
            WHERE t.id = test_submissions.test_id
              AND (
                  (t.batch_id IS NOT NULL AND public.is_teacher_for_batch(t.batch_id))
                  OR (t.batch_id IS NULL AND public.is_teacher_for_course(t.course_id))
              )
        )
        OR public.is_admin()
    );

CREATE POLICY "Students insert own authorized test submissions"
    ON public.test_submissions FOR INSERT
    TO authenticated
    WITH CHECK (
        (public.current_user_role() = 'student' AND auth.uid() = student_id AND public.can_take_test(test_id))
        OR public.is_admin()
    );

CREATE POLICY "Teachers and admins update test submissions"
    ON public.test_submissions FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.tests t
            WHERE t.id = test_submissions.test_id
              AND t.batch_id IS NOT NULL AND public.is_teacher_for_batch(t.batch_id)
        )
        OR public.is_admin()
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.tests t
            WHERE t.id = test_submissions.test_id
              AND t.batch_id IS NOT NULL AND public.is_teacher_for_batch(t.batch_id)
        )
        OR public.is_admin()
    );

CREATE POLICY "Teachers and admins delete test submissions"
    ON public.test_submissions FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.tests t
            WHERE t.id = test_submissions.test_id
              AND t.batch_id IS NOT NULL AND public.is_teacher_for_batch(t.batch_id)
        )
        OR public.is_admin()
    );
