-- 012_secure_tests_rls.sql
-- Fixes the severe security gap where tests were visible to ANY authenticated user without checking enrollments.
-- Hardens the helper function by preventing arbitrary PUBLIC execution.

-- 1. Create a helper function specifically for resolving test access (batch-specific or course-level)
CREATE OR REPLACE FUNCTION public.has_test_access(p_course_id UUID, p_batch_id UUID)
RETURNS BOOLEAN AS $$$
    SELECT EXISTS (
        SELECT 1 
        FROM public.enrollments e
        JOIN public.batches b ON e.batch_id = b.id
        WHERE e.student_id = auth.uid()
          AND e.status = 'active'
          AND (
              (p_batch_id IS NOT NULL AND e.batch_id = p_batch_id)
              OR 
              (p_batch_id IS NULL AND b.course_id = p_course_id)
          )
    );
$$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

-- Revoke default execute permission from PUBLIC to prevent arbitrary evaluation
REVOKE EXECUTE ON FUNCTION public.has_test_access(UUID, UUID) FROM PUBLIC;

-- Grant execute only to authenticated users (who need it for the RLS policy) and service_role (for admin bypass)
GRANT EXECUTE ON FUNCTION public.has_test_access(UUID, UUID) TO authenticated, service_role;

-- 2. Drop the overly permissive existing policy
DROP POLICY IF EXISTS "Enrolled students view published tests" ON public.tests;

-- 3. Create the secure policy enforcing enrollment checks and status requirements
CREATE POLICY "Enrolled students view published tests"
    ON public.tests FOR SELECT
    TO authenticated
    USING (
        (status = 'published' AND public.has_test_access(course_id, batch_id))
        OR public.is_teacher_or_admin()
    );