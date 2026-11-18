-- Migration: 039_cloudflare_live_inputs_persistence.sql
-- Description: Cloudflare Stream Live Ingest Persistence Engine, Table & RLS Hardening
-- Prevents live inputs from disappearing across reinstallation, restarts, or lecture closures.

BEGIN;

-- 1. Create public.cloudflare_live_inputs table
CREATE TABLE IF NOT EXISTS public.cloudflare_live_inputs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    uid TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    rtmps_url TEXT NOT NULL DEFAULT 'rtmps://live.cloudflare.com:443/live/',
    stream_key TEXT NOT NULL,
    playback_url TEXT NOT NULL,
    account_id TEXT,
    batch_id UUID REFERENCES public.batches(id) ON DELETE SET NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW())
);

-- 2. Indexes for fast lookup by UID and primary status
CREATE INDEX IF NOT EXISTS idx_cloudflare_live_inputs_uid 
    ON public.cloudflare_live_inputs(uid);

CREATE INDEX IF NOT EXISTS idx_cloudflare_live_inputs_active 
    ON public.cloudflare_live_inputs(is_active);

CREATE INDEX IF NOT EXISTS idx_cloudflare_live_inputs_primary 
    ON public.cloudflare_live_inputs(is_primary);

-- 3. Row Level Security
ALTER TABLE public.cloudflare_live_inputs ENABLE ROW LEVEL SECURITY;

-- Authenticated users (teachers/admins) can read live inputs for broadcasting
DROP POLICY IF EXISTS "Allow authenticated users to read live inputs" ON public.cloudflare_live_inputs;
CREATE POLICY "Allow authenticated users to read live inputs"
    ON public.cloudflare_live_inputs FOR SELECT
    TO authenticated
    USING (true);

-- Only admins can insert, update, or delete live inputs
DROP POLICY IF EXISTS "Allow admins to manage live inputs" ON public.cloudflare_live_inputs;
CREATE POLICY "Allow admins to manage live inputs"
    ON public.cloudflare_live_inputs FOR ALL
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- 4. Helper Function: Set Primary Live Input
CREATE OR REPLACE FUNCTION public.set_primary_live_input(p_uid TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    -- Verify admin role
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Only administrators can configure primary live stream inputs.';
    END IF;

    -- Unset previous primary
    UPDATE public.cloudflare_live_inputs
    SET is_primary = FALSE, updated_at = TIMEZONE('utc', NOW())
    WHERE is_primary = TRUE;

    -- Set new primary
    UPDATE public.cloudflare_live_inputs
    SET is_primary = TRUE, is_active = TRUE, updated_at = TIMEZONE('utc', NOW())
    WHERE uid = p_uid;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Live input with UID % not found.', p_uid;
    END IF;
END;
$$;

-- 5. Helper Function: Safe Deletion of Live Input (requires admin)
CREATE OR REPLACE FUNCTION public.delete_cloudflare_live_input(p_uid TEXT, p_confirm TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    -- Verify admin role
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Only administrators can delete live stream inputs.';
    END IF;

    -- Enforce explicit confirmation keyword
    IF p_confirm != 'CONFIRM' THEN
        RAISE EXCEPTION 'Deletion aborted: Confirmation string must be CONFIRM.';
    END IF;

    DELETE FROM public.cloudflare_live_inputs
    WHERE uid = p_uid;

    RETURN FOUND;
END;
$$;

-- 6. Ensure rtmps_url exists in public.batches (idempotent guard)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
          AND table_name = 'batches' 
          AND column_name = 'rtmps_url'
    ) THEN
        ALTER TABLE public.batches ADD COLUMN rtmps_url TEXT;
    END IF;
END $$;

-- 7. Ensure platform_settings table exists and is readable
CREATE TABLE IF NOT EXISTS public.platform_settings (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW())
);

ALTER TABLE public.platform_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow authenticated to read platform settings" ON public.platform_settings;
CREATE POLICY "Allow authenticated to read platform settings"
    ON public.platform_settings FOR SELECT
    TO authenticated
    USING (true);

DROP POLICY IF EXISTS "Allow admins to manage platform settings" ON public.platform_settings;
CREATE POLICY "Allow admins to manage platform settings"
    ON public.platform_settings FOR ALL
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

COMMIT;
