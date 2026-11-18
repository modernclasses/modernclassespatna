-- ==============================================================================
-- Migration: 057_unlimited_lecture_videos_storage.sql
-- Description: Provision lecture-videos storage bucket with NO file size limit
--              (file_size_limit = NULL) and grant full upload permissions
--              to both Admin and Teacher roles.
-- Database: PostgreSQL / Supabase Storage
-- ==============================================================================

BEGIN;

-- 1. Ensure lecture-videos bucket exists with unlimited file size
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('lecture-videos', 'lecture-videos', FALSE, NULL)
ON CONFLICT (id) DO UPDATE 
SET file_size_limit = NULL,
    public = FALSE;

-- 2. Remove file size limit on study-materials bucket as well
UPDATE storage.buckets
SET file_size_limit = NULL
WHERE id IN ('study-materials', 'course-thumbnails', 'doubt-attachments');

-- 3. Storage Policies for lecture-videos

-- Staff Upload (Admins and Teachers can upload lecture videos)
DROP POLICY IF EXISTS "Staff Upload Lecture Videos" ON storage.objects;
CREATE POLICY "Staff Upload Lecture Videos"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'lecture-videos'
        AND (
            EXISTS (
                SELECT 1 FROM public.profiles
                WHERE id = auth.uid()
                AND role IN ('admin', 'teacher')
            )
        )
    );

-- Staff Update (Admins and Teachers can update/replace lecture videos)
DROP POLICY IF EXISTS "Staff Update Lecture Videos" ON storage.objects;
CREATE POLICY "Staff Update Lecture Videos"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'lecture-videos'
        AND (
            EXISTS (
                SELECT 1 FROM public.profiles
                WHERE id = auth.uid()
                AND role IN ('admin', 'teacher')
            )
        )
    );

-- Staff Delete (Admins and Teachers can remove lecture videos)
DROP POLICY IF EXISTS "Staff Delete Lecture Videos" ON storage.objects;
CREATE POLICY "Staff Delete Lecture Videos"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'lecture-videos'
        AND (
            EXISTS (
                SELECT 1 FROM public.profiles
                WHERE id = auth.uid()
                AND role IN ('admin', 'teacher')
            )
        )
    );

-- Authenticated Read (Enrolled students and staff can read/stream lecture videos)
DROP POLICY IF EXISTS "Authenticated Read Lecture Videos" ON storage.objects;
CREATE POLICY "Authenticated Read Lecture Videos"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (bucket_id = 'lecture-videos');

COMMIT;
