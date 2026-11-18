-- ==============================================================================
-- Migration: 040_live_classes_thumbnail_url.sql
-- Description: Add thumbnail_url column to public.live_classes table to support
--              live lecture poster/thumbnail image upload and previews.
-- Database: PostgreSQL / Supabase
-- ==============================================================================

BEGIN;

-- 1. Add thumbnail_url column to public.live_classes
ALTER TABLE public.live_classes 
ADD COLUMN IF NOT EXISTS thumbnail_url TEXT;

COMMENT ON COLUMN public.live_classes.thumbnail_url IS 
'Public CDN or Storage URL of the live lecture thumbnail poster image.';

-- 2. Verify / Ensure course-thumbnails bucket exists for live class posters
INSERT INTO storage.buckets (id, name, public)
VALUES ('course-thumbnails', 'course-thumbnails', TRUE)
ON CONFLICT (id) DO UPDATE SET public = TRUE;

-- 3. Post-migration state verification
SELECT 
    column_name, 
    data_type, 
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'live_classes' 
  AND column_name = 'thumbnail_url';

COMMIT;
