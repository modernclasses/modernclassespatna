-- ==============================================================================
-- Migration 032: Push Notification Device Tokens & Realtime Trigger
-- ==============================================================================

-- 1. Create table for FCM device tokens
CREATE TABLE IF NOT EXISTS public.user_device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL,
    device_type TEXT NOT NULL DEFAULT 'android',
    app_version TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    UNIQUE(user_id, fcm_token)
);

-- 2. Performance indexes
CREATE INDEX IF NOT EXISTS idx_user_device_tokens_user_id ON public.user_device_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_user_device_tokens_token ON public.user_device_tokens(fcm_token);

-- 3. Row Level Security (RLS)
ALTER TABLE public.user_device_tokens ENABLE ROW LEVEL SECURITY;

-- Students and teachers can manage their own device tokens
CREATE POLICY "Users can insert their own device tokens"
ON public.user_device_tokens FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own device tokens"
ON public.user_device_tokens FOR UPDATE
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Users can read their own device tokens"
ON public.user_device_tokens FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own device tokens"
ON public.user_device_tokens FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- Admins full access
CREATE POLICY "Admins full access on user_device_tokens"
ON public.user_device_tokens FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'admin'
    )
);

-- 4. RPC for securely upserting token from Flutter app
CREATE OR REPLACE FUNCTION public.register_device_token(
    p_fcm_token TEXT,
    p_device_type TEXT DEFAULT 'android',
    p_app_version TEXT DEFAULT '1.0.0'
)
RETURNS void AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    INSERT INTO public.user_device_tokens (user_id, fcm_token, device_type, app_version, updated_at)
    VALUES (auth.uid(), p_fcm_token, p_device_type, p_app_version, NOW())
    ON CONFLICT (user_id, fcm_token) 
    DO UPDATE SET 
        device_type = EXCLUDED.device_type,
        app_version = EXCLUDED.app_version,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
