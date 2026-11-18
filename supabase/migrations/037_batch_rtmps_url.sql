-- ==============================================================================
-- Migration 037: Add RTMPS URL to Batches and Update View
-- ==============================================================================

BEGIN;

-- 1. Add nullable rtmps_url column to public.batches
ALTER TABLE public.batches ADD COLUMN IF NOT EXISTS rtmps_url TEXT;

-- 2. Safely recreate vw_batches_with_stats to expose stream_key, playback_url, and rtmps_url
-- Appending columns to the end preserves PostgreSQL view column ordinals and ensures backward compatibility
CREATE OR REPLACE VIEW public.vw_batches_with_stats WITH (security_invoker = true) AS
SELECT 
    b.id,
    b.course_id,
    b.name,
    b.timing,
    b.start_date,
    b.end_date,
    b.max_students,
    b.batch_price,
    b.medium,
    b.is_active,
    b.created_at,
    b.updated_at,
    p.full_name AS teacher_name, 
    bt.teacher_id,
    (SELECT COUNT(*) FROM public.enrollments e WHERE e.batch_id = b.id AND e.status = 'active') AS total_students,
    b.play_product_id,
    b.stream_key,
    b.playback_url,
    b.rtmps_url
FROM public.batches b
LEFT JOIN public.batch_teachers bt ON b.id = bt.batch_id AND bt.is_primary = true
LEFT JOIN public.profiles p ON bt.teacher_id = p.id;

-- 3. Post-migration state verification
SELECT
    (SELECT COUNT(*) FROM public.profiles) AS preserved_profiles,
    (SELECT COUNT(*) FROM auth.users) AS preserved_users;

COMMIT;
