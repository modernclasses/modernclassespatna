-- ==============================================================================
-- Migration: 014_secure_doubts_rls.sql
-- Description: Secures the public.doubts table by removing global visibility of 
--              resolved doubts and preventing students from spoofing resolution fields.
-- ==============================================================================

-- 1. Drop the insecure policies
DROP POLICY IF EXISTS "View doubts" ON public.doubts;
DROP POLICY IF EXISTS "Students insert doubts" ON public.doubts;

-- 2. Secure SELECT Policy
--    Students only see their own doubts.
--    Teachers/Admins retain global access.
--    (Removed: is_resolved = TRUE bypass)
CREATE POLICY "View doubts"
    ON public.doubts FOR SELECT
    TO authenticated
    USING (
        auth.uid() = student_id
        OR public.is_teacher_or_admin()
    );

-- 3. Secure INSERT Policy
--    Students can only insert their own doubts.
--    Prevents spoofing of resolution/reply fields.
CREATE POLICY "Students insert doubts"
    ON public.doubts FOR INSERT
    TO authenticated
    WITH CHECK (
        auth.uid() = student_id
        AND is_resolved = false
        AND faculty_reply IS NULL
        AND faculty_name IS NULL
        AND resolved_by IS NULL
        AND resolved_at IS NULL
    );
