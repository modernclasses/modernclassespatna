-- ==============================================================================
-- Migration 045: Enforce Lecture Recording Integrity & Anti-Hijacking
-- Database: PostgreSQL / Supabase
-- Target: Modern Classes Patna
--
-- Description:
--   1. Replaces public.sync_lecture_recording with authoritative verification:
--      - Authenticates caller and verifies role ('admin' or 'teacher').
--      - Enforces batch existence and verifies that p_batch_id belongs to p_course_id.
--      - For teachers: verifies assignment to p_batch_id via public.is_teacher_for_batch.
--      - Anti-spoofing: forces teacher_id = auth.uid() for teachers (only admins can specify).
--      - Conflict hijacking guard: prevents reassigning existing video_uid to foreign batches.
--      - Live class validation: validates that p_live_class_id belongs to p_batch_id and caller.
--      - Cleanses and constraints status to valid enum states.
--      - Atomically updates live_classes recording_url, duration, and status = 'ended'.
--   2. Explicitly revokes EXECUTE from PUBLIC and anon; grants to authenticated, service_role.
--   3. Hardens Row Level Security policies on public.lecture_recordings for INSERT and UPDATE.
-- ==============================================================================

BEGIN;

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
    v_batch RECORD;
    v_existing_rec RECORD;
    v_live_class RECORD;
    v_effective_teacher_id UUID;
    v_recording RECORD;
    v_clean_status TEXT := LOWER(TRIM(COALESCE(p_status, 'processing')));
BEGIN
    -- 1. Authentication Check
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required.';
    END IF;

    SELECT role INTO v_user_role FROM public.profiles WHERE id = v_user_id;
    IF v_user_role NOT IN ('admin', 'teacher') THEN
        RAISE EXCEPTION 'Forbidden: Faculty or Administrator privileges required.';
    END IF;

    -- 2. Verify Batch Existence & Course Association
    SELECT id, course_id INTO v_batch 
    FROM public.batches 
    WHERE id = p_batch_id;

    IF v_batch.id IS NULL THEN
        RAISE EXCEPTION 'Batch % not found.', p_batch_id;
    END IF;

    IF v_batch.course_id != p_course_id THEN
        RAISE EXCEPTION 'Integrity Error: Batch % does not belong to Course %.', p_batch_id, p_course_id;
    END IF;

    -- 3. Teacher Authorization & Anti-Spoofing
    IF v_user_role = 'teacher' THEN
        IF NOT public.is_teacher_for_batch(p_batch_id) THEN
            RAISE EXCEPTION 'Forbidden: You are not assigned to manage recordings for batch %.', p_batch_id;
        END IF;
        -- Force teacher_id to authenticated caller; prohibit spoofing
        v_effective_teacher_id := v_user_id;
    ELSE
        v_effective_teacher_id := COALESCE(p_teacher_id, v_user_id);
    END IF;

    -- 4. Conflict-Update Hijacking Guard
    SELECT id, batch_id, teacher_id INTO v_existing_rec
    FROM public.lecture_recordings
    WHERE video_uid = p_video_uid;

    IF v_existing_rec.id IS NOT NULL AND v_user_role = 'teacher' THEN
        IF NOT (
            public.is_teacher_for_batch(v_existing_rec.batch_id) 
            OR v_existing_rec.teacher_id = v_user_id
        ) THEN
            RAISE EXCEPTION 'Forbidden: Video UID % belongs to another batch which you do not manage.', p_video_uid;
        END IF;
    END IF;

    -- 5. Live Class Ownership & Session Validation
    IF p_live_class_id IS NOT NULL THEN
        SELECT id, batch_id, teacher_id INTO v_live_class
        FROM public.live_classes
        WHERE id = p_live_class_id;

        IF v_live_class.id IS NULL THEN
            RAISE EXCEPTION 'Live class session % not found.', p_live_class_id;
        END IF;

        IF v_live_class.batch_id != p_batch_id THEN
            RAISE EXCEPTION 'Integrity Error: Live class % belongs to batch %, not %.', p_live_class_id, v_live_class.batch_id, p_batch_id;
        END IF;

        IF v_user_role = 'teacher' AND NOT (
            public.is_teacher_for_batch(v_live_class.batch_id) 
            OR v_live_class.teacher_id = v_user_id
        ) THEN
            RAISE EXCEPTION 'Forbidden: You do not own live class %.', p_live_class_id;
        END IF;
    END IF;

    -- Sanitize recording status
    IF v_clean_status NOT IN ('processing', 'ready', 'unavailable', 'failed') THEN
        v_clean_status := 'processing';
    END IF;

    -- 6. Upsert Recording
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

    -- 7. Update Live Class Record
    IF p_live_class_id IS NOT NULL THEN
        UPDATE public.live_classes
        SET recording_url = p_playback_url,
            cloudflare_video_uid = p_video_uid,
            recording_status = v_clean_status,
            actual_duration_seconds = GREATEST(COALESCE(actual_duration_seconds, 0), p_duration_seconds),
            status = 'ended'
        WHERE id = p_live_class_id;
    END IF;

    RETURN jsonb_build_object(
        'success', TRUE,
        'recording', row_to_json(v_recording)
    );
END;
$$;

-- 8. Explicit Permissions
REVOKE ALL ON FUNCTION public.sync_lecture_recording(UUID, UUID, TEXT, TEXT, TEXT, UUID, TEXT, UUID, TEXT, INT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, BOOLEAN) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.sync_lecture_recording(UUID, UUID, TEXT, TEXT, TEXT, UUID, TEXT, UUID, TEXT, INT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, BOOLEAN) TO authenticated, service_role;

-- 9. Tighten direct RLS policies on public.lecture_recordings (Optimized InitPlans)
DROP POLICY IF EXISTS "Teachers insert recordings for their batches" ON public.lecture_recordings;
CREATE POLICY "Teachers insert recordings for their batches"
    ON public.lecture_recordings FOR INSERT
    TO authenticated
    WITH CHECK (
        (SELECT public.is_admin())
        OR (
            (SELECT public.current_user_role()) = 'teacher'
            AND (SELECT public.is_teacher_for_batch(batch_id))
            AND (teacher_id IS NULL OR teacher_id = (SELECT auth.uid()))
        )
    );

DROP POLICY IF EXISTS "Teachers update recordings for their batches" ON public.lecture_recordings;
CREATE POLICY "Teachers update recordings for their batches"
    ON public.lecture_recordings FOR UPDATE
    TO authenticated
    USING (
        (SELECT public.is_admin())
        OR (
            (SELECT public.current_user_role()) = 'teacher'
            AND (SELECT public.is_teacher_for_batch(batch_id))
        )
    )
    WITH CHECK (
        (SELECT public.is_admin())
        OR (
            (SELECT public.current_user_role()) = 'teacher'
            AND (SELECT public.is_teacher_for_batch(batch_id))
            AND (teacher_id IS NULL OR teacher_id = (SELECT auth.uid()))
        )
    );

COMMIT;
