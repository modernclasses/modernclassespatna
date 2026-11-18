-- ==============================================================================
-- Migration 043: Isolate Live Streaming Broadcast Credentials from Students
-- Database: PostgreSQL / Supabase
-- Target: Modern Classes Patna
--
-- Description:
--   1. Recreates public.vw_batches_with_stats with (security_invoker = false)
--      so that stream_key and rtmps_url are role-masked at the database level.
--      Students and anonymous callers receive NULL for stream_key and rtmps_url.
--      Assigned batch teachers and administrators receive the actual values.
--   2. Explicitly grants SELECT on public.vw_batches_with_stats to authenticated,
--      anon, and service_role.
--   3. Revokes direct column-level SELECT on (stream_key, rtmps_url) on table
--      public.batches from anon, authenticated, and public.
--   4. Hardens Row Level Security on public.cloudflare_live_inputs so that only
--      admins, creators, and teachers assigned to the batch can read inputs.
--   5. Hardens Row Level Security on public.platform_settings so that sensitive
--      keys ('live_stream_key', 'live_rtmps_url') cannot be read by non-admins.
-- ==============================================================================

BEGIN;

-- 1. Recreate vw_batches_with_stats with role-masked credentials
CREATE OR REPLACE VIEW public.vw_batches_with_stats
WITH (security_invoker = false)
AS
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
    (
        SELECT count(*) 
        FROM public.enrollments e 
        WHERE e.batch_id = b.id AND e.status = 'active'
    ) AS total_students,
    b.play_product_id,
    -- Role-masked broadcast credentials
    CASE 
        WHEN (SELECT public.is_admin()) OR (SELECT public.is_teacher_for_batch(b.id)) THEN b.stream_key 
        ELSE NULL 
    END AS stream_key,
    b.playback_url,
    CASE 
        WHEN (SELECT public.is_admin()) OR (SELECT public.is_teacher_for_batch(b.id)) THEN b.rtmps_url 
        ELSE NULL 
    END AS rtmps_url
FROM public.batches b
LEFT JOIN public.batch_teachers bt ON b.id = bt.batch_id AND bt.is_primary = true
LEFT JOIN public.profiles p ON bt.teacher_id = p.id;

-- Ensure view read grants
GRANT SELECT ON public.vw_batches_with_stats TO anon, authenticated, service_role;

-- 2. Revoke Direct Column Access on batches from Students and Public
REVOKE SELECT (stream_key, rtmps_url) ON TABLE public.batches FROM anon, authenticated, public;

-- 3. Harden public.cloudflare_live_inputs RLS (Optimized InitPlans)
DROP POLICY IF EXISTS "Allow authenticated users to read live inputs" ON public.cloudflare_live_inputs;
DROP POLICY IF EXISTS "Faculty and Admins view live inputs" ON public.cloudflare_live_inputs;

CREATE POLICY "Faculty and Admins view live inputs" 
ON public.cloudflare_live_inputs
FOR SELECT TO authenticated
USING (
    (SELECT public.is_admin()) 
    OR (batch_id IS NOT NULL AND (SELECT public.is_teacher_for_batch(batch_id)))
    OR created_by = (SELECT auth.uid())
);

-- 4. Harden public.platform_settings RLS (Optimized InitPlans)
DROP POLICY IF EXISTS "Allow authenticated to read platform settings" ON public.platform_settings;
DROP POLICY IF EXISTS "Public platform settings read" ON public.platform_settings;

CREATE POLICY "Public platform settings read" 
ON public.platform_settings
FOR SELECT TO authenticated
USING (
    (SELECT public.is_admin()) 
    OR key NOT IN ('live_stream_key', 'live_rtmps_url')
);

COMMIT;
