-- ==============================================================================
-- Migration: 067_fix_stack_depth_limit_recursion.sql
-- Description: Fix PostgreSQL Error 54001 ("stack depth limit exceeded") by marking
--              all RLS security helper functions as SECURITY DEFINER with explicit
--              search_path. This ensures that internal privilege checks on
--              public.profiles, public.enrollments, and public.batch_teachers
--              execute as the trusted owner and bypass Row Level Security evaluation,
--              preventing infinite recursive policy evaluation.
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. User Role & Administrator Verification Helpers
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS user_role
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT (public.current_user_role() = 'admin');
$$;

CREATE OR REPLACE FUNCTION public.is_teacher_or_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT (public.current_user_role() IN ('teacher', 'admin'));
$$;

-- ------------------------------------------------------------------------------
-- 2. Faculty & Batch Assignment Helpers
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_teacher_for_batch(p_batch_id uuid)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.batch_teachers 
        WHERE batch_id = p_batch_id 
          AND teacher_id = auth.uid()
    );
$$;

CREATE OR REPLACE FUNCTION public.is_teacher_for_course(p_course_id uuid)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.batch_teachers bt
        JOIN public.batches b ON bt.batch_id = b.id
        WHERE b.course_id = p_course_id
          AND bt.teacher_id = auth.uid()
    );
$$;

-- ------------------------------------------------------------------------------
-- 3. Student Enrollment & Academic Content Access Helpers
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_enrolled_in_course(p_course_id uuid)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.enrollments e
        JOIN public.batches b ON e.batch_id = b.id
        WHERE e.student_id = auth.uid()
          AND e.status = 'active'
          AND b.course_id = p_course_id
    );
$$;

CREATE OR REPLACE FUNCTION public.has_study_material_access(p_course_id uuid, p_batch_id uuid)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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
$$;

CREATE OR REPLACE FUNCTION public.has_test_access(p_course_id uuid, p_batch_id uuid)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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
$$;

CREATE OR REPLACE FUNCTION public.can_take_test(p_test_id uuid)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.tests t
        WHERE t.id = p_test_id
          AND t.status = 'published'
          AND public.has_test_access(t.course_id, t.batch_id)
    );
$$;

-- ------------------------------------------------------------------------------
-- 4. Permissions Grants
-- ------------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.is_admin() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_role() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_teacher_or_admin() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_teacher_for_batch(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_teacher_for_course(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_enrolled_in_course(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_study_material_access(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_test_access(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_take_test(uuid) TO authenticated;

COMMIT;
