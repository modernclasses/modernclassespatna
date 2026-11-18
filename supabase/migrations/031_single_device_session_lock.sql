-- ==============================================================================
-- Migration 031: Single Device Student Session Lock
-- ==============================================================================

-- Add current_device_id to profiles to track active physical device binding
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS current_device_id TEXT;

-- Create an index to quickly lookup and validate active sessions
CREATE INDEX IF NOT EXISTS idx_profiles_current_device_id ON public.profiles(current_device_id);
