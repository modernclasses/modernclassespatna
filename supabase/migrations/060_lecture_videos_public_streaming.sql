-- ==============================================================================
-- Migration: 060_lecture_videos_public_streaming.sql
-- Description: Configure lecture-videos bucket for resilient streaming and
--              reliable playback across mobile devices and ExoPlayer.
--              - Sets bucket public = TRUE and file_size_limit = NULL
--              - Grants public SELECT on storage.objects for lecture-videos so
--                ExoPlayer can stream with HTTP Range requests without token expiry
--              - Preserves authenticated teacher/admin restrictions for INSERT,
--                UPDATE, and DELETE.
-- Database: PostgreSQL / Supabase Storage
-- ==============================================================================

BEGIN;

-- 1. Ensure lecture-videos bucket exists and is public with unlimited file size
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('lecture-videos', 'lecture-videos', TRUE, NULL)
ON CONFLICT (id) DO UPDATE 
SET file_size_limit = NULL,
    public = TRUE;

-- 2. Allow public SELECT (read/stream) on lecture-videos storage objects
DROP POLICY IF EXISTS "Public Read Lecture Videos" ON storage.objects;
CREATE POLICY "Public Read Lecture Videos"
    ON storage.objects FOR SELECT
    TO public
    USING (bucket_id = 'lecture-videos');

-- 3. Staff Upload (Admins and Teachers can upload lecture videos)
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

-- 4. Staff Update (Admins and Teachers can update/replace lecture videos)
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

-- 5. Staff Delete (Admins and Teachers can remove lecture videos)
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

COMMIT;
