-- ==============================================================================
-- Migration 003: Storage Buckets & Policies
-- Database: PostgreSQL / Supabase Storage
-- ==============================================================================

-- 1. Create Public & Protected Storage Buckets
INSERT INTO storage.buckets (id, name, public)
VALUES 
    ('course-thumbnails', 'course-thumbnails', TRUE),
    ('study-materials', 'study-materials', FALSE),
    ('doubt-attachments', 'doubt-attachments', TRUE)
ON CONFLICT (id) DO NOTHING;

-- 2. Storage Policies for Course Thumbnails (Public Read, Admin Write)
CREATE POLICY "Public Read Course Thumbnails"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'course-thumbnails');

CREATE POLICY "Admin Upload Course Thumbnails"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'course-thumbnails' 
        AND (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'admin'
    );

-- 3. Storage Policies for Study Materials (Authenticated Read, Staff Write)
CREATE POLICY "Authenticated Read Study Materials"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (bucket_id = 'study-materials');

CREATE POLICY "Staff Upload Study Materials"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'study-materials'
        AND (SELECT role FROM public.profiles WHERE id = auth.uid()) IN ('teacher', 'admin')
    );

-- 4. Storage Policies for Doubt Attachments (Authenticated Read/Write)
CREATE POLICY "Authenticated Read Doubt Attachments"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (bucket_id = 'doubt-attachments');

CREATE POLICY "Student Upload Doubt Attachments"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'doubt-attachments');
