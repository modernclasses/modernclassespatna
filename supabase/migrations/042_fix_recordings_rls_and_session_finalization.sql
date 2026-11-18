-- ==============================================================================
-- Migration: 042_fix_recordings_rls_and_session_finalization.sql
-- Description: Fix RLS permissions on lecture_recordings for teachers,
--              atomically persist recordings on session end in PostgreSQL,
--              add sync_lecture_recording RPC, and reconcile past ended classes.
-- Database: PostgreSQL / Supabase
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. Ensure Table and Constraints
-- ------------------------------------------------------------------------------
ALTER TABLE public.live_classes
    ADD COLUMN IF NOT EXISTS thumbnail_url TEXT;

CREATE TABLE IF NOT EXISTS public.lecture_recordings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    live_class_id UUID REFERENCES public.live_classes(id) ON DELETE SET NULL,
    course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
    batch_id UUID NOT NULL REFERENCES public.batches(id) ON DELETE CASCADE,
    teacher_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    live_input_uid TEXT,
    video_uid TEXT UNIQUE,
    playback_url TEXT NOT NULL,
    thumbnail_url TEXT,
    start_time TIMESTAMPTZ,
    end_time TIMESTAMPTZ,
    duration_seconds INT DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'processing' CHECK (status IN ('processing', 'ready', 'unavailable', 'failed')),
    is_published BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW())
);

CREATE INDEX IF NOT EXISTS idx_lecture_recordings_course ON public.lecture_recordings(course_id);
CREATE INDEX IF NOT EXISTS idx_lecture_recordings_batch ON public.lecture_recordings(batch_id);
CREATE INDEX IF NOT EXISTS idx_lecture_recordings_teacher ON public.lecture_recordings(teacher_id);
CREATE INDEX IF NOT EXISTS idx_lecture_recordings_status ON public.lecture_recordings(status);
CREATE INDEX IF NOT EXISTS idx_lecture_recordings_video_uid ON public.lecture_recordings(video_uid);

-- ------------------------------------------------------------------------------
-- 2. Row Level Security: Grant Complete Permissions to Admins and Teachers
-- ------------------------------------------------------------------------------
ALTER TABLE public.lecture_recordings ENABLE ROW LEVEL SECURITY;

-- Admins: Full management
DROP POLICY IF EXISTS "Admins manage all lecture recordings" ON public.lecture_recordings;
CREATE POLICY "Admins manage all lecture recordings"
    ON public.lecture_recordings FOR ALL
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- Teachers: SELECT recordings for batches they teach or authored
DROP POLICY IF EXISTS "Teachers view assigned batch recordings" ON public.lecture_recordings;
CREATE POLICY "Teachers view assigned batch recordings"
    ON public.lecture_recordings FOR SELECT
    TO authenticated
    USING (
        public.is_admin()
        OR teacher_id = auth.uid()
        OR public.is_teacher_for_batch(batch_id)
    );

-- Teachers: INSERT recordings for batches they teach or authored
DROP POLICY IF EXISTS "Teachers insert recordings for their batches" ON public.lecture_recordings;
CREATE POLICY "Teachers insert recordings for their batches"
    ON public.lecture_recordings FOR INSERT
    TO authenticated
    WITH CHECK (
        public.is_admin()
        OR teacher_id = auth.uid()
        OR public.is_teacher_for_batch(batch_id)
    );

-- Teachers: UPDATE recordings for batches they teach or authored
DROP POLICY IF EXISTS "Teachers update recordings for their batches" ON public.lecture_recordings;
CREATE POLICY "Teachers update recordings for their batches"
    ON public.lecture_recordings FOR UPDATE
    TO authenticated
    USING (
        public.is_admin()
        OR teacher_id = auth.uid()
        OR public.is_teacher_for_batch(batch_id)
    )
    WITH CHECK (
        public.is_admin()
        OR teacher_id = auth.uid()
        OR public.is_teacher_for_batch(batch_id)
    );

-- Students: View ready, published recordings for enrolled batches/courses
DROP POLICY IF EXISTS "Students view enrolled ready recordings" ON public.lecture_recordings;
CREATE POLICY "Students view enrolled ready recordings"
    ON public.lecture_recordings FOR SELECT
    TO authenticated
    USING (
        status = 'ready'
        AND is_published = TRUE
        AND (
            public.is_admin()
            OR public.is_teacher_for_batch(batch_id)
            OR EXISTS (
                SELECT 1 FROM public.enrollments e
                WHERE e.student_id = auth.uid()
                  AND e.batch_id = lecture_recordings.batch_id
                  AND e.status = 'active'
            )
            OR public.is_enrolled_in_course(course_id)
        )
    );

-- ------------------------------------------------------------------------------
-- 3. Atomic Session Termination & Recording Creation (SECURITY DEFINER)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.end_authenticated_live_session(p_live_class_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_user_role TEXT;
    v_session RECORD;
    v_course_id UUID;
    v_batch_stream_key TEXT;
    v_batch_playback_url TEXT;
    v_start_time TIMESTAMPTZ;
    v_end_time TIMESTAMPTZ := TIMEZONE('utc', NOW());
    v_duration_seconds INT := 0;
    v_video_uid TEXT;
    v_playback_url TEXT;
    v_live_input_uid TEXT;
    v_recording RECORD;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT role INTO v_user_role FROM public.profiles WHERE id = v_user_id;

    SELECT * INTO v_session FROM public.live_classes WHERE id = p_live_class_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Session not found.');
    END IF;

    IF v_user_role <> 'admin' AND v_session.teacher_id <> v_user_id THEN
        RAISE EXCEPTION 'Forbidden: You cannot end another teacher''s session.';
    END IF;

    -- Lookup batch and course metadata
    SELECT course_id, stream_key, playback_url
    INTO v_course_id, v_batch_stream_key, v_batch_playback_url
    FROM public.batches
    WHERE id = v_session.batch_id;

    -- Calculate session timing
    v_start_time := COALESCE(v_session.actual_start_time, v_session.scheduled_at, v_session.created_at);
    v_duration_seconds := GREATEST(0, EXTRACT(EPOCH FROM (v_end_time - v_start_time))::INT);

    -- Extract or synthesize clean live input UID
    v_live_input_uid := COALESCE(
        v_session.live_input_uid,
        v_batch_stream_key
    );
    -- If stream_key contains 'k' (e.g. keykUID), extract UID portion
    IF v_live_input_uid LIKE '%k%' AND LENGTH(v_live_input_uid) > 32 THEN
        v_live_input_uid := SUBSTRING(v_live_input_uid FROM POSITION('k' IN v_live_input_uid) + 1);
    END IF;

    -- Clean video UID and playback URL
    v_video_uid := COALESCE(
        v_session.cloudflare_video_uid,
        'rec_' || replace(v_session.id::text, '-', '')
    );

    v_playback_url := COALESCE(
        v_session.recording_url,
        v_session.stream_url,
        v_batch_playback_url,
        'https://videodelivery.net/' || v_video_uid || '/manifest/video.m3u8'
    );

    -- 1. Update public.live_classes
    UPDATE public.live_classes
    SET status = 'ended',
        actual_end_time = v_end_time,
        actual_duration_seconds = v_duration_seconds,
        recording_status = 'processing',
        recording_url = v_playback_url,
        cloudflare_video_uid = v_video_uid,
        live_input_uid = v_live_input_uid
    WHERE id = p_live_class_id;

    -- 2. Atomically UPSERT into public.lecture_recordings
    IF v_course_id IS NOT NULL AND v_session.batch_id IS NOT NULL THEN
        INSERT INTO public.lecture_recordings (
            live_class_id,
            course_id,
            batch_id,
            teacher_id,
            title,
            live_input_uid,
            video_uid,
            playback_url,
            thumbnail_url,
            duration_seconds,
            status,
            start_time,
            end_time,
            is_published,
            created_at,
            updated_at
        ) VALUES (
            v_session.id,
            v_course_id,
            v_session.batch_id,
            v_session.teacher_id,
            v_session.title,
            v_live_input_uid,
            v_video_uid,
            v_playback_url,
            v_session.thumbnail_url,
            v_duration_seconds,
            'processing',
            v_start_time,
            v_end_time,
            TRUE,
            v_end_time,
            v_end_time
        )
        ON CONFLICT (video_uid) DO UPDATE
        SET duration_seconds = EXCLUDED.duration_seconds,
            end_time = EXCLUDED.end_time,
            playback_url = EXCLUDED.playback_url,
            thumbnail_url = COALESCE(EXCLUDED.thumbnail_url, lecture_recordings.thumbnail_url),
            updated_at = TIMEZONE('utc', NOW())
        RETURNING * INTO v_recording;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'live_class_id', p_live_class_id,
        'duration_seconds', v_duration_seconds,
        'actual_end_time', v_end_time,
        'recording', row_to_json(v_recording)
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 4. Authoritative RPC: Synchronize or Upsert Lecture Recording (SECURITY DEFINER)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sync_lecture_recording(
    p_batch_id UUID,
    p_course_id UUID,
    p_title TEXT,
    p_video_uid TEXT,
    p_playback_url TEXT,
    p_live_class_id UUID DEFAULT NULL,
    p_live_input_uid TEXT DEFAULT NULL,
    p_teacher_id UUID DEFAULT NULL,
    p_thumbnail_url TEXT DEFAULT NULL,
    p_duration_seconds INT DEFAULT 0,
    p_status TEXT DEFAULT 'processing',
    p_start_time TIMESTAMPTZ DEFAULT NULL,
    p_end_time TIMESTAMPTZ DEFAULT NULL,
    p_is_published BOOLEAN DEFAULT TRUE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_user_role TEXT;
    v_effective_teacher_id UUID;
    v_recording RECORD;
    v_clean_status TEXT := LOWER(TRIM(p_status));
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT role INTO v_user_role FROM public.profiles WHERE id = v_user_id;
    IF v_user_role NOT IN ('admin', 'teacher') THEN
        RAISE EXCEPTION 'Forbidden: Faculty or Administrator privileges required.';
    END IF;

    v_effective_teacher_id := COALESCE(p_teacher_id, v_user_id);

    IF v_clean_status NOT IN ('processing', 'ready', 'unavailable', 'failed') THEN
        v_clean_status := 'processing';
    END IF;

    -- Upsert recording
    INSERT INTO public.lecture_recordings (
        live_class_id,
        course_id,
        batch_id,
        teacher_id,
        title,
        live_input_uid,
        video_uid,
        playback_url,
        thumbnail_url,
        duration_seconds,
        status,
        start_time,
        end_time,
        is_published,
        created_at,
        updated_at
    ) VALUES (
        p_live_class_id,
        p_course_id,
        p_batch_id,
        v_effective_teacher_id,
        COALESCE(NULLIF(TRIM(p_title), ''), 'Live Lecture Recording'),
        p_live_input_uid,
        p_video_uid,
        p_playback_url,
        p_thumbnail_url,
        GREATEST(0, p_duration_seconds),
        v_clean_status,
        COALESCE(p_start_time, TIMEZONE('utc', NOW())),
        COALESCE(p_end_time, TIMEZONE('utc', NOW())),
        p_is_published,
        TIMEZONE('utc', NOW()),
        TIMEZONE('utc', NOW())
    )
    ON CONFLICT (video_uid) DO UPDATE
    SET title = EXCLUDED.title,
        playback_url = EXCLUDED.playback_url,
        thumbnail_url = COALESCE(EXCLUDED.thumbnail_url, lecture_recordings.thumbnail_url),
        duration_seconds = GREATEST(lecture_recordings.duration_seconds, EXCLUDED.duration_seconds),
        status = EXCLUDED.status,
        end_time = EXCLUDED.end_time,
        is_published = EXCLUDED.is_published,
        updated_at = TIMEZONE('utc', NOW())
    RETURNING * INTO v_recording;

    -- Also update live_classes if session ID provided
    IF p_live_class_id IS NOT NULL THEN
        UPDATE public.live_classes
        SET recording_url = p_playback_url,
            cloudflare_video_uid = p_video_uid,
            recording_status = v_clean_status,
            actual_duration_seconds = GREATEST(actual_duration_seconds, p_duration_seconds),
            status = 'ended'
        WHERE id = p_live_class_id;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'recording', row_to_json(v_recording)
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 5. Authoritative RPC: Promote Recording Status (SECURITY DEFINER)
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.promote_lecture_recording_status(
    p_video_uid TEXT,
    p_status TEXT DEFAULT 'ready',
    p_duration_seconds INT DEFAULT NULL,
    p_playback_url TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_recording RECORD;
    v_clean_status TEXT := LOWER(TRIM(p_status));
BEGIN
    IF v_clean_status NOT IN ('processing', 'ready', 'unavailable', 'failed') THEN
        v_clean_status := 'ready';
    END IF;

    UPDATE public.lecture_recordings
    SET status = v_clean_status,
        duration_seconds = COALESCE(p_duration_seconds, duration_seconds),
        playback_url = COALESCE(p_playback_url, playback_url),
        updated_at = TIMEZONE('utc', NOW())
    WHERE video_uid = p_video_uid
    RETURNING * INTO v_recording;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', FALSE, 'error', 'Recording not found for video_uid: ' || p_video_uid);
    END IF;

    -- Mirror to live_classes
    UPDATE public.live_classes
    SET recording_status = v_clean_status,
        actual_duration_seconds = COALESCE(p_duration_seconds, actual_duration_seconds),
        recording_url = COALESCE(p_playback_url, recording_url)
    WHERE cloudflare_video_uid = p_video_uid;

    RETURN jsonb_build_object(
        'success', TRUE,
        'recording', row_to_json(v_recording)
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 6. Reconcile Existing Ended Live Classes into lecture_recordings
-- ------------------------------------------------------------------------------
DO $$
DECLARE
    r RECORD;
    v_cid UUID;
    v_vid TEXT;
    v_purl TEXT;
BEGIN
    FOR r IN
        SELECT lc.*, b.course_id as b_course_id, b.playback_url as b_playback_url
        FROM public.live_classes lc
        LEFT JOIN public.batches b ON b.id = lc.batch_id
        WHERE lc.status = 'ended'
          AND NOT EXISTS (
              SELECT 1 FROM public.lecture_recordings lr
              WHERE lr.live_class_id = lc.id
          )
    LOOP
        v_cid := COALESCE(r.b_course_id, 'd0239212-5733-4d3d-a13d-6fd9fe0ee774');
        v_vid := COALESCE(r.cloudflare_video_uid, 'rec_' || replace(r.id::text, '-', ''));
        v_purl := COALESCE(r.recording_url, r.stream_url, r.b_playback_url, 'https://videodelivery.net/' || v_vid || '/manifest/video.m3u8');

        INSERT INTO public.lecture_recordings (
            live_class_id,
            course_id,
            batch_id,
            teacher_id,
            title,
            live_input_uid,
            video_uid,
            playback_url,
            thumbnail_url,
            duration_seconds,
            status,
            start_time,
            end_time,
            is_published,
            created_at,
            updated_at
        ) VALUES (
            r.id,
            v_cid,
            r.batch_id,
            r.teacher_id,
            r.title,
            r.live_input_uid,
            v_vid,
            v_purl,
            r.thumbnail_url,
            COALESCE(r.actual_duration_seconds, 1800),
            'ready', -- Mark past historical broadcast as ready so it can be viewed immediately
            COALESCE(r.actual_start_time, r.scheduled_at, r.created_at),
            COALESCE(r.actual_end_time, r.scheduled_at + INTERVAL '90 minutes', r.created_at + INTERVAL '90 minutes'),
            TRUE,
            r.created_at,
            TIMEZONE('utc', NOW())
        )
        ON CONFLICT (video_uid) DO NOTHING;

        -- Update live_class recording_status to ready
        UPDATE public.live_classes
        SET recording_status = 'ready',
            recording_url = v_purl,
            cloudflare_video_uid = v_vid
        WHERE id = r.id;
    END LOOP;
END $$;

COMMIT;
