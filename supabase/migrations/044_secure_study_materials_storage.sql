-- ==============================================================================
-- Migration 044: Enforce Course-Level Enrollment Scoping on study-materials Storage
-- Database: PostgreSQL / Supabase Storage
-- Target: Modern Classes Patna
--
-- Description:
--   1. Drops overly permissive and defective SELECT policies on storage.objects
--      for the 'study-materials' bucket.
--   2. Enforces a course-level scoped SELECT policy requiring:
--      - Admin role, OR
--      - Faculty assignment to the course or any batch in the course, OR
--      - Active student enrollment in at least one batch belonging to the course.
--   3. Safe UUID parsing guarded by regex check (^<uuid>/) to prevent transaction-aborting
--      cast exceptions on malformed or non-standard storage object names.
--   4. Hardens the 'doubt-attachments' bucket by applying a 10MB file size limit
--      and restricting allowed MIME types to standard image and document formats.
-- ==============================================================================

BEGIN;

-- 1. Drop existing permissive and defective SELECT policies on study-materials
DROP POLICY IF EXISTS "Authenticated Read Study Materials" ON storage.objects;
DROP POLICY IF EXISTS "Enrolled students view study materials" ON storage.objects;
DROP POLICY IF EXISTS "Enrolled students and staff read study materials" ON storage.objects;

-- 2. Create strictly scoped SELECT policy with safe UUID parsing (Optimized InitPlans)
CREATE POLICY "Enrolled students and staff read study materials" 
ON storage.objects
FOR SELECT TO authenticated
USING (
    bucket_id = 'study-materials'
    AND (
        -- Administrators have global access
        (SELECT public.is_admin())
        -- Faculty access: Teachers assigned to the course or any batch in the course
        OR (
            (SELECT public.current_user_role()) = 'teacher' 
            AND storage.objects.name ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/'
            AND (
                (SELECT public.is_teacher_for_course((split_part(storage.objects.name, '/', 1))::uuid))
                OR EXISTS (
                    SELECT 1 FROM public.batch_teachers bt
                    JOIN public.batches b ON bt.batch_id = b.id
                    WHERE bt.teacher_id = (SELECT auth.uid()) 
                      AND b.course_id = (split_part(storage.objects.name, '/', 1))::uuid
                )
                OR EXISTS (
                    SELECT 1 FROM public.courses c
                    WHERE c.id = (split_part(storage.objects.name, '/', 1))::uuid
                      AND c.teacher_id = (SELECT auth.uid())
                )
            )
        )
        -- Student access: Active enrollment in at least one batch belonging to this course
        OR (
            storage.objects.name ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/'
            AND EXISTS (
                SELECT 1 
                FROM public.enrollments e
                JOIN public.batches b ON e.batch_id = b.id
                WHERE e.student_id = (SELECT auth.uid())
                  AND e.status = 'active'
                  AND b.course_id = (split_part(storage.objects.name, '/', 1))::uuid
            )
        )
    )
);

-- 3. Harden doubt-attachments limits & MIME types
UPDATE storage.buckets
SET file_size_limit = 10485760, -- 10 MB limit
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
WHERE id = 'doubt-attachments';

COMMIT;
