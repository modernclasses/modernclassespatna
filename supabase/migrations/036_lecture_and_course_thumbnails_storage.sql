-- ==============================================================================
-- Migration: 036_lecture_and_course_thumbnails_storage.sql
-- Description: Ensure course-thumbnails bucket exists, enable teachers & admins
--              to upload/update course & lecture thumbnails, and ensure
--              public.lessons has thumbnail_url column.
-- Database: PostgreSQL / Supabase Storage
-- ==============================================================================

BEGIN;

-- 1. Ensure public.lessons has thumbnail_url column
ALTER TABLE public.lessons 
ADD COLUMN IF NOT EXISTS thumbnail_url TEXT;

-- 2. Ensure course-thumbnails bucket is provisioned and public
INSERT INTO storage.buckets (id, name, public)
VALUES ('course-thumbnails', 'course-thumbnails', TRUE)
ON CONFLICT (id) DO UPDATE SET public = TRUE;

-- 3. Storage Policies for Course & Lecture Thumbnails in course-thumbnails
-- Public Read (anyone can view course & lecture thumbnails)
DROP POLICY IF EXISTS "Public Read Course Thumbnails" ON storage.objects;
CREATE POLICY "Public Read Course Thumbnails"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'course-thumbnails');

-- Staff Upload (Admins and Teachers can upload thumbnails)
DROP POLICY IF EXISTS "Admin Upload Course Thumbnails" ON storage.objects;
DROP POLICY IF EXISTS "Staff Upload Course Thumbnails" ON storage.objects;
CREATE POLICY "Staff Upload Course Thumbnails"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'course-thumbnails' 
        AND (
            EXISTS (
                SELECT 1 FROM public.profiles 
                WHERE id = auth.uid() 
                AND role IN ('admin', 'teacher')
            )
        )
    );

-- Staff Update (Admins and Teachers can update/replace thumbnails)
DROP POLICY IF EXISTS "Staff Update Course Thumbnails" ON storage.objects;
CREATE POLICY "Staff Update Course Thumbnails"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'course-thumbnails' 
        AND (
            EXISTS (
                SELECT 1 FROM public.profiles 
                WHERE id = auth.uid() 
                AND role IN ('admin', 'teacher')
            )
        )
    );

-- Staff Delete (Admins and Teachers can delete thumbnails if removed)
DROP POLICY IF EXISTS "Staff Delete Course Thumbnails" ON storage.objects;
CREATE POLICY "Staff Delete Course Thumbnails"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'course-thumbnails' 
        AND (
            EXISTS (
                SELECT 1 FROM public.profiles 
                WHERE id = auth.uid() 
                AND role IN ('admin', 'teacher')
            )
        )
    );

COMMIT;
