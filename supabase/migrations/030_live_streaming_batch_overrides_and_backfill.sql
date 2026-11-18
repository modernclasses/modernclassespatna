-- ==============================================================================
-- Migration 030: Cloudflare Live Ingest Settings, Per-Batch Overrides & Batch Backfill
-- ==============================================================================

-- 1. Create platform_settings table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.platform_settings (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW())
);

ALTER TABLE public.platform_settings ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to read platform settings (so teachers can load stream keys)
DROP POLICY IF EXISTS "Allow authenticated to read platform settings" ON public.platform_settings;
CREATE POLICY "Allow authenticated to read platform settings"
    ON public.platform_settings FOR SELECT
    TO authenticated
    USING (true);

-- Only admins can manage platform settings
DROP POLICY IF EXISTS "Allow admins to manage platform settings" ON public.platform_settings;
CREATE POLICY "Allow admins to manage platform settings"
    ON public.platform_settings FOR ALL
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- 2. Add per-batch stream override columns to public.batches
ALTER TABLE public.batches ADD COLUMN IF NOT EXISTS stream_key TEXT;
ALTER TABLE public.batches ADD COLUMN IF NOT EXISTS playback_url TEXT;

-- 3. Auto-backfill batches for any existing courses without batches
-- (This creates Batch 1 for "Class 12 board batch pcm", "djdndn", etc.)
INSERT INTO public.batches (course_id, name, timing, start_date, end_date, max_students, batch_price, medium, is_active)
SELECT 
    c.id,
    c.title || ' - Batch 1',
    '08:00 AM - 10:00 AM (Mon-Sat)',
    NOW(),
    NOW() + INTERVAL '90 days',
    500,
    c.price,
    'Bilingual (Hindi + English)',
    TRUE
FROM public.courses c
WHERE NOT EXISTS (
    SELECT 1 FROM public.batches b WHERE b.course_id = c.id
);
