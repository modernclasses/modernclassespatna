-- 013_secure_test_submissions_rls.sql
-- Secures test submissions by splitting the dangerously permissive FOR ALL policy into strict SELECT, INSERT, UPDATE, and DELETE policies.

-- 1. Helper function to check if a student is authorized to submit for a specific test_id.
-- Reuses the validated logic from has_test_access to evaluate the parent test's course/batch against active enrollments.
CREATE OR REPLACE FUNCTION public.can_take_test(p_test_id UUID)
RETURNS BOOLEAN AS $$$
    SELECT EXISTS (
        SELECT 1
        FROM public.tests t
        WHERE t.id = p_test_id
          AND t.status = 'published'
          AND public.has_test_access(t.course_id, t.batch_id)
    );
$$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

-- Harden the helper function against arbitrary execution
REVOKE EXECUTE ON FUNCTION public.can_take_test(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.can_take_test(UUID) TO authenticated, service_role;

-- 2. Drop the overly permissive "FOR ALL" policy
DROP POLICY IF EXISTS "Students manage own test submissions" ON public.test_submissions;

-- 3. SELECT: Students can view their own submissions. Teachers/Admins can view all.
CREATE POLICY "Students view own test submissions"
    ON public.test_submissions FOR SELECT
    TO authenticated
    USING (auth.uid() = student_id OR public.is_teacher_or_admin());

-- 4. INSERT: Students can insert their own submission ONLY IF they are authorized for the test.
CREATE POLICY "Students insert own authorized test submissions"
    ON public.test_submissions FOR INSERT
    TO authenticated
    WITH CHECK (
        (auth.uid() = student_id AND public.can_take_test(test_id))
        OR public.is_teacher_or_admin()
    );

-- 5. UPDATE: Only Teachers/Admins can modify submissions after the fact.
-- (No policy granted for students effectively denies them UPDATE access).
CREATE POLICY "Teachers and admins update test submissions"
    ON public.test_submissions FOR UPDATE
    TO authenticated
    USING (public.is_teacher_or_admin())
    WITH CHECK (public.is_teacher_or_admin());

-- 6. DELETE: Only Teachers/Admins can delete submissions (e.g. to reset an attempt).
CREATE POLICY "Teachers and admins delete test submissions"
    ON public.test_submissions FOR DELETE
    TO authenticated
    USING (public.is_teacher_or_admin());