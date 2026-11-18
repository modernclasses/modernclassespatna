-- ============================================================================
-- Migration 019: Fix Teacher Test Submission Insert
-- Restricts test_submission INSERTs solely to students (own authorized) and admins.
-- ============================================================================

DROP POLICY IF EXISTS "Students insert own authorized test submissions" ON public.test_submissions;

CREATE POLICY "Students insert own authorized test submissions"
    ON public.test_submissions FOR INSERT
    TO authenticated
    WITH CHECK (
        (auth.uid() = student_id AND public.can_take_test(test_id))
        OR public.is_admin()
    );
