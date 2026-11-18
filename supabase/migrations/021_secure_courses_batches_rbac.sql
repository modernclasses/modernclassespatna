-- ==============================================================================
-- Migration: 021_secure_courses_batches_rbac.sql
-- Description: Secures courses and batches by removing teacher FOR ALL access.
--              Only Admins can INSERT/UPDATE/DELETE. Authenticated users can SELECT.
-- ==============================================================================

-- Drop the overly permissive policies
DROP POLICY IF EXISTS "Teachers and admins manage courses" ON public.courses;
DROP POLICY IF EXISTS "Teachers and admins manage batches" ON public.batches;

-- Create Admin-only FOR ALL policies with proper WITH CHECK enforcement
CREATE POLICY "Admins manage courses"
    ON public.courses FOR ALL
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

CREATE POLICY "Admins manage batches"
    ON public.batches FOR ALL
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- Note: The existing "View courses for authenticated users" and 
-- "View batches for authenticated users" USING (TRUE) policies are preserved
-- to maintain the student/teacher catalog read access.
