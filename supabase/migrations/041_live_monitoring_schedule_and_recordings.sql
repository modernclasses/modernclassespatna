-- ==============================================================================
-- Migration: 041_live_monitoring_schedule_and_recordings.sql
-- Description: Live lecture monitoring, strict Asia/Kolkata schedule enforcement,
--              Cloudflare Stream recording persistence, and recordings library RLS.
-- Database: PostgreSQL / Supabase
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. Enhance public.live_classes with authoritative session & recording metadata
-- ------------------------------------------------------------------------------
ALTER TABLE public.live_classes
    ADD COLUMN IF NOT EXISTS actual_start_time TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS actual_end_time TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS actual_duration_seconds INT DEFAULT 0,
    ADD COLUMN IF NOT EXISTS live_input_uid TEXT,
    ADD COLUMN IF NOT EXISTS cloudflare_video_uid TEXT,
    ADD COLUMN IF NOT EXISTS recording_url TEXT,
    ADD COLUMN IF NOT EXISTS recording_status TEXT DEFAULT 'pending';

-- Add check constraint for recording_status if not present
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'chk_live_classes_recording_status'
    ) THEN
        ALTER TABLE public.live_classes
            ADD CONSTRAINT chk_live_classes_recording_status
            CHECK (recording_status IN ('pending', 'processing', 'ready', 'unavailable', 'failed'));
    END IF;
END $$;

-- ------------------------------------------------------------------------------
-- 2. Create public.lecture_recordings table
-- ------------------------------------------------------------------------------
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

-- Indexes for efficient querying by course, batch, teacher, and status
CREATE INDEX IF NOT EXISTS idx_lecture_recordings_course ON public.lecture_recordings(course_id);
CREATE INDEX IF NOT EXISTS idx_lecture_recordings_batch ON public.lecture_recordings(batch_id);
CREATE INDEX IF NOT EXISTS idx_lecture_recordings_teacher ON public.lecture_recordings(teacher_id);
CREATE INDEX IF NOT EXISTS idx_lecture_recordings_status ON public.lecture_recordings(status);
CREATE INDEX IF NOT EXISTS idx_lecture_recordings_video_uid ON public.lecture_recordings(video_uid);

-- ------------------------------------------------------------------------------
-- 3. Row Level Security for public.lecture_recordings
-- ------------------------------------------------------------------------------
ALTER TABLE public.lecture_recordings ENABLE ROW LEVEL SECURITY;

-- Admins: Full management
DROP POLICY IF EXISTS "Admins manage all lecture recordings" ON public.lecture_recordings;
CREATE POLICY "Admins manage all lecture recordings"
    ON public.lecture_recordings FOR ALL
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

-- Teachers: View recordings for batches they teach or authored
DROP POLICY IF EXISTS "Teachers view assigned batch recordings" ON public.lecture_recordings;
CREATE POLICY "Teachers view assigned batch recordings"
    ON public.lecture_recordings FOR SELECT
    TO authenticated
    USING (
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
-- 4. Authoritative Asia/Kolkata Schedule Enforcement Function
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.validate_batch_live_schedule(p_batch_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_timing TEXT;
    v_is_active BOOLEAN;
    v_now_ist TIMESTAMP;
    v_day_of_week INT; -- 1 = Mon, 7 = Sun
    v_day_abbr TEXT;
    v_days TEXT[];
    v_start_str TEXT;
    v_end_str TEXT;
    v_start_hour INT;
    v_start_min INT;
    v_end_hour INT;
    v_end_min INT;
    v_start_total_mins INT;
    v_end_total_mins INT;
    v_current_total_mins INT;
    v_dash_pos INT;
    v_paren_pos INT;
    v_time_part TEXT;
    v_days_part TEXT;
    v_is_pm BOOLEAN;
    v_colon_pos INT;
BEGIN
    -- 1. Fetch batch
    SELECT timing, is_active INTO v_timing, v_is_active
    FROM public.batches
    WHERE id = p_batch_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'is_valid', FALSE,
            'error_code', 'BATCH_NOT_FOUND',
            'message', 'Batch not found.'
        );
    END IF;

    IF v_is_active IS FALSE THEN
        RETURN jsonb_build_object(
            'is_valid', FALSE,
            'error_code', 'BATCH_INACTIVE',
            'message', 'Batch is currently inactive.'
        );
    END IF;

    -- If no timing configured, default permit
    IF v_timing IS NULL OR TRIM(v_timing) = '' THEN
        RETURN jsonb_build_object(
            'is_valid', TRUE,
            'message', 'No slot restrictions configured for this batch.'
        );
    END IF;

    -- Current time in Asia/Kolkata (IST)
    v_now_ist := (NOW() AT TIME ZONE 'Asia/Kolkata');
    v_day_of_week := EXTRACT(ISODOW FROM v_now_ist); -- 1 (Mon) to 7 (Sun)
    v_current_total_mins := EXTRACT(HOUR FROM v_now_ist) * 60 + EXTRACT(MINUTE FROM v_now_ist);

    v_day_abbr := CASE v_day_of_week
        WHEN 1 THEN 'Mon'
        WHEN 2 THEN 'Tue'
        WHEN 3 THEN 'Wed'
        WHEN 4 THEN 'Thu'
        WHEN 5 THEN 'Fri'
        WHEN 6 THEN 'Sat'
        WHEN 7 THEN 'Sun'
    END;

    -- Extract days portion e.g. "(Mon-Sat)"
    v_paren_pos := POSITION('(' IN v_timing);
    IF v_paren_pos > 0 THEN
        v_time_part := TRIM(SUBSTRING(v_timing FROM 1 FOR v_paren_pos - 1));
        v_days_part := TRIM(REPLACE(REPLACE(SUBSTRING(v_timing FROM v_paren_pos), '(', ''), ')', ''));
    ELSE
        v_time_part := TRIM(v_timing);
        v_days_part := 'Mon-Sat';
    END IF;

    -- Check Day match
    IF v_days_part = 'Daily' OR v_days_part = 'Mon-Sun' THEN
        -- all days allowed
        NULL;
    ELSIF v_days_part = 'Mon-Sat' THEN
        IF v_day_abbr = 'Sun' THEN
            RETURN jsonb_build_object(
                'is_valid', FALSE,
                'error_code', 'INVALID_DAY',
                'message', 'This batch is scheduled for Mon-Sat. Today is Sunday (Asia/Kolkata).'
            );
        END IF;
    ELSIF v_days_part = 'Mon-Fri' THEN
        IF v_day_abbr IN ('Sat', 'Sun') THEN
            RETURN jsonb_build_object(
                'is_valid', FALSE,
                'error_code', 'INVALID_DAY',
                'message', 'This batch is scheduled for Mon-Fri. Today is ' || v_day_abbr || ' (Asia/Kolkata).'
            );
        END IF;
    ELSIF v_days_part = 'Weekend' OR v_days_part = 'Sat-Sun' THEN
        IF v_day_abbr NOT IN ('Sat', 'Sun') THEN
            RETURN jsonb_build_object(
                'is_valid', FALSE,
                'error_code', 'INVALID_DAY',
                'message', 'This batch is scheduled for weekends only. Today is ' || v_day_abbr || ' (Asia/Kolkata).'
            );
        END IF;
    ELSE
        IF POSITION(v_day_abbr IN v_days_part) = 0 THEN
            RETURN jsonb_build_object(
                'is_valid', FALSE,
                'error_code', 'INVALID_DAY',
                'message', 'This batch is scheduled for ' || v_days_part || '. Today is ' || v_day_abbr || ' (Asia/Kolkata).'
            );
        END IF;
    END IF;

    -- Parse time string e.g. "08:00 AM - 10:00 AM"
    v_dash_pos := POSITION('-' IN v_time_part);
    IF v_dash_pos > 0 THEN
        v_start_str := TRIM(SUBSTRING(v_time_part FROM 1 FOR v_dash_pos - 1));
        v_end_str := TRIM(SUBSTRING(v_time_part FROM v_dash_pos + 1));

        -- Parse start time
        v_is_pm := (POSITION('PM' IN UPPER(v_start_str)) > 0);
        v_start_str := TRIM(REPLACE(REPLACE(UPPER(v_start_str), 'AM', ''), 'PM', ''));
        v_colon_pos := POSITION(':' IN v_start_str);
        IF v_colon_pos > 0 THEN
            v_start_hour := CAST(SUBSTRING(v_start_str FROM 1 FOR v_colon_pos - 1) AS INT);
            v_start_min := CAST(SUBSTRING(v_start_str FROM v_colon_pos + 1) AS INT);
            IF v_is_pm AND v_start_hour < 12 THEN v_start_hour := v_start_hour + 12; END IF;
            IF NOT v_is_pm AND v_start_hour = 12 THEN v_start_hour := 0; END IF;
            v_start_total_mins := v_start_hour * 60 + v_start_min;
        END IF;

        -- Parse end time
        v_is_pm := (POSITION('PM' IN UPPER(v_end_str)) > 0);
        v_end_str := TRIM(REPLACE(REPLACE(UPPER(v_end_str), 'AM', ''), 'PM', ''));
        v_colon_pos := POSITION(':' IN v_end_str);
        IF v_colon_pos > 0 THEN
            v_end_hour := CAST(SUBSTRING(v_end_str FROM 1 FOR v_colon_pos - 1) AS INT);
            v_end_min := CAST(SUBSTRING(v_end_str FROM v_colon_pos + 1) AS INT);
            IF v_is_pm AND v_end_hour < 12 THEN v_end_hour := v_end_hour + 12; END IF;
            IF NOT v_is_pm AND v_end_hour = 12 THEN v_end_hour := 0; END IF;
            v_end_total_mins := v_end_hour * 60 + v_end_min;
        END IF;

        -- Check time bounds
        IF v_start_total_mins IS NOT NULL AND v_end_total_mins IS NOT NULL THEN
            -- Allow 15-minute early start for teacher setup
            IF v_current_total_mins < (v_start_total_mins - 15) THEN
                RETURN jsonb_build_object(
                    'is_valid', FALSE,
                    'error_code', 'TOO_EARLY',
                    'message', 'Class slot begins at ' || TRIM(SUBSTRING(v_time_part FROM 1 FOR v_dash_pos - 1)) || ' IST. Early start allowed only within 15 minutes of slot start.'
                );
            END IF;

            -- STRICT: Block starting after scheduled slot end time
            IF v_current_total_mins > v_end_total_mins THEN
                RETURN jsonb_build_object(
                    'is_valid', FALSE,
                    'error_code', 'SLOT_ENDED',
                    'message', 'Class slot ended at ' || TRIM(SUBSTRING(v_time_part FROM v_dash_pos + 1)) || ' IST. Starting a new live broadcast after the scheduled end time is not permitted.'
                );
            END IF;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'is_valid', TRUE,
        'message', 'Active slot verified: ' || v_timing || ' (Asia/Kolkata)'
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 5. Stored Procedure: Authoritative Start Live Session with Server Validation
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.start_authenticated_live_session(
    p_batch_id UUID,
    p_title TEXT,
    p_subject TEXT,
    p_stream_url TEXT,
    p_thumbnail_url TEXT DEFAULT NULL,
    p_live_input_uid TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_user_role TEXT;
    v_teacher_name TEXT;
    v_schedule_check JSONB;
    v_batch RECORD;
    v_course RECORD;
    v_existing_live RECORD;
    v_created RECORD;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required to start a live broadcast.';
    END IF;

    -- Get profile role
    SELECT role, full_name INTO v_user_role, v_teacher_name
    FROM public.profiles
    WHERE id = v_user_id;

    IF v_user_role NOT IN ('teacher', 'admin') THEN
        RAISE EXCEPTION 'Forbidden: Only faculty or administrators can broadcast live.';
    END IF;

    -- If teacher, verify assignment to batch
    IF v_user_role = 'teacher' THEN
        IF NOT (public.is_teacher_for_batch(p_batch_id) OR EXISTS (
            SELECT 1 FROM public.batches WHERE id = p_batch_id AND teacher_id = v_user_id
        )) THEN
            RAISE EXCEPTION 'Forbidden: You are not assigned to broadcast for this batch.';
        END IF;
    END IF;

    -- Run server-side schedule validation
    v_schedule_check := public.validate_batch_live_schedule(p_batch_id);
    IF (v_schedule_check->>'is_valid')::BOOLEAN IS FALSE THEN
        RAISE EXCEPTION '%', (v_schedule_check->>'message');
    END IF;

    -- Fetch batch and course details
    SELECT * INTO v_batch FROM public.batches WHERE id = p_batch_id;
    SELECT * INTO v_course FROM public.courses WHERE id = v_batch.course_id;

    -- Guard against duplicate simultaneous active sessions for the same batch
    SELECT id, status INTO v_existing_live
    FROM public.live_classes
    WHERE batch_id = p_batch_id AND status = 'live'
    LIMIT 1;

    IF v_existing_live.id IS NOT NULL THEN
        -- If session already exists, update and return it
        UPDATE public.live_classes
        SET title = COALESCE(NULLIF(TRIM(p_title), ''), title),
            subject = COALESCE(NULLIF(TRIM(p_subject), ''), subject),
            thumbnail_url = COALESCE(p_thumbnail_url, thumbnail_url),
            live_input_uid = COALESCE(p_live_input_uid, live_input_uid)
        WHERE id = v_existing_live.id
        RETURNING * INTO v_created;

        RETURN jsonb_build_object(
            'success', TRUE,
            'session_id', v_created.id,
            'is_resumed', TRUE,
            'live_class', row_to_json(v_created)
        );
    END IF;

    -- Insert new live_classes session
    INSERT INTO public.live_classes (
        batch_id,
        title,
        subject,
        teacher_name,
        teacher_id,
        stream_url,
        scheduled_at,
        actual_start_time,
        status,
        thumbnail_url,
        live_input_uid,
        duration_minutes
    ) VALUES (
        p_batch_id,
        COALESCE(NULLIF(TRIM(p_title), ''), 'Live Classroom Lecture'),
        COALESCE(NULLIF(TRIM(p_subject), ''), 'General Studies'),
        COALESCE(v_teacher_name, 'Faculty Member'),
        v_user_id,
        p_stream_url,
        TIMEZONE('utc', NOW()),
        TIMEZONE('utc', NOW()),
        'live',
        p_thumbnail_url,
        p_live_input_uid,
        90
    )
    RETURNING * INTO v_created;

    RETURN jsonb_build_object(
        'success', TRUE,
        'session_id', v_created.id,
        'is_resumed', FALSE,
        'live_class', row_to_json(v_created)
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 6. Stored Procedure: End Live Session & Record Final Timestamps
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
    v_start_time TIMESTAMPTZ;
    v_end_time TIMESTAMPTZ := TIMEZONE('utc', NOW());
    v_duration_seconds INT := 0;
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

    v_start_time := COALESCE(v_session.actual_start_time, v_session.created_at);
    v_duration_seconds := GREATEST(0, EXTRACT(EPOCH FROM (v_end_time - v_start_time))::INT);

    UPDATE public.live_classes
    SET status = 'ended',
        actual_end_time = v_end_time,
        actual_duration_seconds = v_duration_seconds,
        recording_status = 'processing'
    WHERE id = p_live_class_id;

    RETURN jsonb_build_object(
        'success', TRUE,
        'live_class_id', p_live_class_id,
        'duration_seconds', v_duration_seconds,
        'actual_end_time', v_end_time
    );
END;
$$;

-- ------------------------------------------------------------------------------
-- 7. Verification Query
-- ------------------------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM public.profiles) AS preserved_profiles,
    (SELECT COUNT(*) FROM auth.users) AS preserved_users;

COMMIT;
