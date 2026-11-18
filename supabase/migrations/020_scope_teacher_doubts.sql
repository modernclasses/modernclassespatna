-- ==============================================================================
-- Migration: 020_scope_teacher_doubts.sql
-- Description: Aggressively drops any lingering global policies on doubts and 
--              re-establishes strict batch-scoped RLS for teachers.
-- ==============================================================================

DO $drop_doubt_policies$
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = 'doubts'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.doubts', pol.policyname);
    END LOOP;
END;
$drop_doubt_policies$;

-- 1. SELECT: Students see own, Teachers see own batches, Admins see all.
CREATE POLICY "View doubts scoped"
    ON public.doubts FOR SELECT
    TO authenticated
    USING (
        auth.uid() = student_id
        OR public.is_teacher_for_batch(batch_id)
        OR public.is_admin()
    );

-- 2. INSERT: Only actively enrolled students can submit doubts for their batch.
CREATE POLICY "Students insert scoped doubts"
    ON public.doubts FOR INSERT
    TO authenticated
    WITH CHECK (
        auth.uid() = student_id
        AND EXISTS (
            SELECT 1 FROM public.enrollments 
            WHERE student_id = auth.uid() 
              AND batch_id = doubts.batch_id 
              AND status = 'active'
        )
        AND is_resolved = false
        AND faculty_reply IS NULL
        AND faculty_name IS NULL
        AND resolved_by IS NULL
        AND resolved_at IS NULL
    );

-- 3. UPDATE: Only assigned teachers or global admins can resolve doubts.
CREATE POLICY "Teachers and admins update scoped doubts"
    ON public.doubts FOR UPDATE
    TO authenticated
    USING (
        public.is_teacher_for_batch(batch_id)
        OR public.is_admin()
    )
    WITH CHECK (
        public.is_teacher_for_batch(batch_id)
        OR public.is_admin()
    );
