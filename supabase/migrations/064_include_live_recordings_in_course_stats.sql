-- ==============================================================================
-- Migration 064: Include Live Lecture Recordings in Course Stats & Chat Resilience
-- Description:
--   1. Recreates public.vw_courses_with_stats so live_total_lessons and live_total_hours
--      include both pre-recorded lessons, lecture_recordings, and completed live_classes.
--   2. Updates sync_course_lesson_stats() trigger to maintain courses.total_lessons and
--      courses.total_hours automatically when live classes end or recordings are synced.
--   3. Hardens live_chat_messages permissions for authenticated and anonymous users.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. Ensure live_chat_messages table exists and permits chat exchange
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.live_chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    class_id UUID NOT NULL REFERENCES public.live_classes(id) ON DELETE CASCADE,
    sender_id UUID,
    sender_name TEXT NOT NULL,
    sender_role TEXT NOT NULL DEFAULT 'student',
    message TEXT NOT NULL,
    is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW())
);

CREATE INDEX IF NOT EXISTS idx_live_chat_class_id ON public.live_chat_messages(class_id, created_at ASC);

ALTER TABLE public.live_chat_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "live_chat_select_policy" ON public.live_chat_messages;
CREATE POLICY "live_chat_select_policy" ON public.live_chat_messages
FOR SELECT TO anon, authenticated USING (TRUE);

DROP POLICY IF EXISTS "live_chat_insert_policy" ON public.live_chat_messages;
CREATE POLICY "live_chat_insert_policy" ON public.live_chat_messages
FOR INSERT TO authenticated
WITH CHECK ((SELECT auth.uid()) IS NOT NULL);

-- Enable Supabase Realtime replication on live_chat_messages if not already added
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
-- 2. Drop existing view to allow clean column and query recreation
-- ------------------------------------------------------------------------------
DROP VIEW IF EXISTS public.vw_courses_with_stats CASCADE;

-- ------------------------------------------------------------------------------
-- 3. Recreate vw_courses_with_stats with curriculum lessons, recordings & live classes
-- ------------------------------------------------------------------------------
CREATE VIEW public.vw_courses_with_stats WITH (security_invoker = true) AS
SELECT 
    c.id,
    c.title,
    c.category,
    c.description,
    c.cover_image_url,
    c.price,
    c.original_price,
    c.teacher_id,
    c.total_lessons,
    c.total_hours,
    c.total_tests,
    c.total_notes,
    c.rating,
    c.reviews_count,
    c.highlights,
    c.is_featured,
    c.is_crash_course,
    c.is_active,
    c.play_product_id,
    c.created_at,
    c.updated_at,
    p.full_name AS teacher_name,
    COALESCE(c.subjects, '{}'::TEXT[]) AS subjects,
    COALESCE(
        GREATEST(
            c.total_lessons,
            (
                -- Pre-recorded curriculum lessons
                COALESCE((SELECT COUNT(*) FROM public.lessons l WHERE l.course_id = c.id), 0) +
                -- Authoritative lecture recordings
                COALESCE((SELECT COUNT(*) FROM public.lecture_recordings r WHERE r.course_id = c.id AND r.status IN ('ready', 'processing')), 0) +
                -- Completed live class sessions not duplicated in lecture_recordings
                COALESCE((
                    SELECT COUNT(*) FROM public.live_classes lc
                    WHERE lc.batch_id IN (SELECT b.id FROM public.batches b WHERE b.course_id = c.id)
                      AND lc.status = 'ended'
                      AND NOT EXISTS (SELECT 1 FROM public.lecture_recordings lr WHERE lr.live_class_id = lc.id)
                ), 0)
            )
        ),
        0
    ) AS live_total_lessons,
    COALESCE(
        GREATEST(
            c.total_hours,
            CASE 
                WHEN (
                    COALESCE((SELECT SUM(l.duration_seconds) FROM public.lessons l WHERE l.course_id = c.id), 0) +
                    COALESCE((SELECT SUM(r.duration_seconds) FROM public.lecture_recordings r WHERE r.course_id = c.id), 0) +
                    COALESCE((
                        SELECT SUM(lc.actual_duration_seconds) FROM public.live_classes lc
                        WHERE lc.batch_id IN (SELECT b.id FROM public.batches b WHERE b.course_id = c.id)
                          AND lc.status = 'ended'
                          AND NOT EXISTS (SELECT 1 FROM public.lecture_recordings lr WHERE lr.live_class_id = lc.id)
                    ), 0)
                ) > 0 THEN
                    GREATEST(
                        1,
                        ROUND(
                            (
                                COALESCE((SELECT SUM(l.duration_seconds) FROM public.lessons l WHERE l.course_id = c.id), 0) +
                                COALESCE((SELECT SUM(r.duration_seconds) FROM public.lecture_recordings r WHERE r.course_id = c.id), 0) +
                                COALESCE((
                                    SELECT SUM(lc.actual_duration_seconds) FROM public.live_classes lc
                                    WHERE lc.batch_id IN (SELECT b.id FROM public.batches b WHERE b.course_id = c.id)
                                      AND lc.status = 'ended'
                                      AND NOT EXISTS (SELECT 1 FROM public.lecture_recordings lr WHERE lr.live_class_id = lc.id)
                                ), 0)
                            ) / 3600.0
                        )::INT
                    )
                ELSE 0
            END
        ),
        0
    ) AS live_total_hours,
    COALESCE(
        (SELECT COUNT(*) FROM public.tests t WHERE t.course_id = c.id),
        c.total_tests,
        0
    ) AS live_total_tests
FROM public.courses c
LEFT JOIN public.profiles p ON c.teacher_id = p.id;

-- ------------------------------------------------------------------------------
-- 4. Permissions on vw_courses_with_stats
-- ------------------------------------------------------------------------------
GRANT SELECT ON public.vw_courses_with_stats TO anon, authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 5. Trigger Function to automatically synchronize courses.total_lessons and total_hours
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sync_course_lesson_stats()
RETURNS TRIGGER AS $$
DECLARE
    v_course_id UUID;
    v_batch_id UUID;
    v_total_lessons INT;
    v_total_seconds BIGINT;
    v_total_hours INT;
BEGIN
    -- Determine target course_id
    IF TG_TABLE_NAME = 'lessons' THEN
        v_course_id := COALESCE(NEW.course_id, OLD.course_id);
    ELSIF TG_TABLE_NAME = 'lecture_recordings' THEN
        v_course_id := COALESCE(NEW.course_id, OLD.course_id);
    ELSIF TG_TABLE_NAME = 'live_classes' THEN
        v_batch_id := COALESCE(NEW.batch_id, OLD.batch_id);
        IF v_batch_id IS NOT NULL THEN
            SELECT course_id INTO v_course_id FROM public.batches WHERE id = v_batch_id;
        END IF;
    END IF;

    IF v_course_id IS NOT NULL THEN
        -- Calculate lessons count
        SELECT 
            COALESCE((SELECT COUNT(*) FROM public.lessons l WHERE l.course_id = v_course_id), 0) +
            COALESCE((SELECT COUNT(*) FROM public.lecture_recordings r WHERE r.course_id = v_course_id AND r.status IN ('ready', 'processing')), 0) +
            COALESCE((
                SELECT COUNT(*) FROM public.live_classes lc
                WHERE lc.batch_id IN (SELECT b.id FROM public.batches b WHERE b.course_id = v_course_id)
                  AND lc.status = 'ended'
                  AND NOT EXISTS (SELECT 1 FROM public.lecture_recordings lr WHERE lr.live_class_id = lc.id)
            ), 0)
        INTO v_total_lessons;

        -- Calculate total duration in seconds
        SELECT 
            COALESCE((SELECT SUM(l.duration_seconds) FROM public.lessons l WHERE l.course_id = v_course_id), 0) +
            COALESCE((SELECT SUM(r.duration_seconds) FROM public.lecture_recordings r WHERE r.course_id = v_course_id), 0) +
            COALESCE((
                SELECT SUM(lc.actual_duration_seconds) FROM public.live_classes lc
                WHERE lc.batch_id IN (SELECT b.id FROM public.batches b WHERE b.course_id = v_course_id)
                  AND lc.status = 'ended'
                  AND NOT EXISTS (SELECT 1 FROM public.lecture_recordings lr WHERE lr.live_class_id = lc.id)
            ), 0)
        INTO v_total_seconds;

        IF v_total_seconds > 0 THEN
            v_total_hours := GREATEST(1, ROUND(v_total_seconds / 3600.0)::INT);
        ELSE
            v_total_hours := 0;
        END IF;

        UPDATE public.courses
        SET total_lessons = v_total_lessons,
            total_hours = v_total_hours,
            updated_at = TIMEZONE('utc', NOW())
        WHERE id = v_course_id;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp;

-- Attach triggers
DROP TRIGGER IF EXISTS trg_sync_course_lesson_stats ON public.lessons;
CREATE TRIGGER trg_sync_course_lesson_stats
AFTER INSERT OR UPDATE OR DELETE ON public.lessons
FOR EACH ROW EXECUTE FUNCTION public.sync_course_lesson_stats();

DROP TRIGGER IF EXISTS trg_sync_recording_course_stats ON public.lecture_recordings;
CREATE TRIGGER trg_sync_recording_course_stats
AFTER INSERT OR UPDATE OR DELETE ON public.lecture_recordings
FOR EACH ROW EXECUTE FUNCTION public.sync_course_lesson_stats();

DROP TRIGGER IF EXISTS trg_sync_live_class_course_stats ON public.live_classes;
CREATE TRIGGER trg_sync_live_class_course_stats
AFTER INSERT OR UPDATE OR DELETE ON public.live_classes
FOR EACH ROW EXECUTE FUNCTION public.sync_course_lesson_stats();

-- ------------------------------------------------------------------------------
-- 6. Initial backfill of courses stats with combined counts
-- ------------------------------------------------------------------------------
UPDATE public.courses c
SET 
    total_lessons = (
        COALESCE((SELECT COUNT(*) FROM public.lessons l WHERE l.course_id = c.id), 0) +
        COALESCE((SELECT COUNT(*) FROM public.lecture_recordings r WHERE r.course_id = c.id AND r.status IN ('ready', 'processing')), 0) +
        COALESCE((
            SELECT COUNT(*) FROM public.live_classes lc
            WHERE lc.batch_id IN (SELECT b.id FROM public.batches b WHERE b.course_id = c.id)
              AND lc.status = 'ended'
              AND NOT EXISTS (SELECT 1 FROM public.lecture_recordings lr WHERE lr.live_class_id = lc.id)
        ), 0)
    ),
    total_hours = CASE 
        WHEN (
            COALESCE((SELECT SUM(l.duration_seconds) FROM public.lessons l WHERE l.course_id = c.id), 0) +
            COALESCE((SELECT SUM(r.duration_seconds) FROM public.lecture_recordings r WHERE r.course_id = c.id), 0) +
            COALESCE((
                SELECT SUM(lc.actual_duration_seconds) FROM public.live_classes lc
                WHERE lc.batch_id IN (SELECT b.id FROM public.batches b WHERE b.course_id = c.id)
                  AND lc.status = 'ended'
                  AND NOT EXISTS (SELECT 1 FROM public.lecture_recordings lr WHERE lr.live_class_id = lc.id)
            ), 0)
        ) > 0 THEN
            GREATEST(
                1,
                ROUND(
                    (
                        COALESCE((SELECT SUM(l.duration_seconds) FROM public.lessons l WHERE l.course_id = c.id), 0) +
                        COALESCE((SELECT SUM(r.duration_seconds) FROM public.lecture_recordings r WHERE r.course_id = c.id), 0) +
                        COALESCE((
                            SELECT SUM(lc.actual_duration_seconds) FROM public.live_classes lc
                            WHERE lc.batch_id IN (SELECT b.id FROM public.batches b WHERE b.course_id = c.id)
                              AND lc.status = 'ended'
                              AND NOT EXISTS (SELECT 1 FROM public.lecture_recordings lr WHERE lr.live_class_id = lc.id)
                        ), 0)
                    ) / 3600.0
                )::INT
            )
        ELSE 0
    END;

-- Refresh PostgREST schema cache
NOTIFY pgrst, 'reload schema';
