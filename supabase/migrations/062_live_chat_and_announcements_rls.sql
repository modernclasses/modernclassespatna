-- ==============================================================================
-- Migration 062: Live Chat Messages Table & Announcements RLS Hardening
-- Description:
--   1. Creates public.live_chat_messages table for persistent live class chat.
--   2. Enables Supabase Realtime publication on live_chat_messages.
--   3. Hardens announcements_insert_policy to allow teachers to notify students.
--   4. Refreshes PostgREST schema cache.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. Persistent Live Chat Messages Table
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.live_chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    class_id UUID NOT NULL REFERENCES public.live_classes(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    sender_name TEXT NOT NULL,
    sender_role TEXT NOT NULL DEFAULT 'student',
    message TEXT NOT NULL,
    is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW())
);

CREATE INDEX IF NOT EXISTS idx_live_chat_class_id ON public.live_chat_messages(class_id, created_at ASC);

ALTER TABLE public.live_chat_messages ENABLE ROW LEVEL SECURITY;

-- Select Policy: Authenticated users can view chat messages for live classes
DROP POLICY IF EXISTS "live_chat_select_policy" ON public.live_chat_messages;
CREATE POLICY "live_chat_select_policy" ON public.live_chat_messages
FOR SELECT TO authenticated USING (TRUE);

-- Insert Policy: Authenticated users can send messages to live classes
DROP POLICY IF EXISTS "live_chat_insert_policy" ON public.live_chat_messages;
CREATE POLICY "live_chat_insert_policy" ON public.live_chat_messages
FOR INSERT TO authenticated WITH CHECK (
    auth.uid() IS NOT NULL
);

-- Update Policy: Teachers and Admins can pin/update chat messages
DROP POLICY IF EXISTS "live_chat_update_policy" ON public.live_chat_messages;
CREATE POLICY "live_chat_update_policy" ON public.live_chat_messages
FOR UPDATE TO authenticated USING (
    (SELECT public.is_admin()) OR (SELECT public.current_user_role()) = 'teacher'
);

-- Delete Policy: Teachers and Admins can delete inappropriate messages
DROP POLICY IF EXISTS "live_chat_delete_policy" ON public.live_chat_messages;
CREATE POLICY "live_chat_delete_policy" ON public.live_chat_messages
FOR DELETE TO authenticated USING (
    (SELECT public.is_admin()) OR (SELECT public.current_user_role()) = 'teacher'
);

-- Enable Supabase Realtime replication on live_chat_messages
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' 
          AND schemaname = 'public' 
          AND tablename = 'live_chat_messages'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.live_chat_messages;
    END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 2. Announcements RLS Policy Hardening
-- Allows teachers (as well as admins) to broadcast announcements and notifications
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "announcements_insert_policy" ON public.announcements;
CREATE POLICY "announcements_insert_policy" ON public.announcements
FOR INSERT TO authenticated WITH CHECK (
    (SELECT public.is_admin()) OR (SELECT public.current_user_role()) = 'teacher'
);

DROP POLICY IF EXISTS "announcements_update_policy" ON public.announcements;
CREATE POLICY "announcements_update_policy" ON public.announcements
FOR UPDATE TO authenticated
USING (
    (SELECT public.is_admin()) OR (SELECT public.current_user_role()) = 'teacher'
)
WITH CHECK (
    (SELECT public.is_admin()) OR (SELECT public.current_user_role()) = 'teacher'
);

-- Refresh PostgREST schema cache
NOTIFY pgrst, 'reload schema';
