-- ==============================================================================
-- Migration: 059_teacher_lecture_deletion.sql
-- Purpose:   Allow teachers to permanently delete their uploaded prerecorded
--            lessons and completed lecture recordings for assigned batches,
--            requiring explicit confirmation and providing both updated RLS
--            and a safe server-side RPC function.
-- ==============================================================================

BEGIN;

-- 1. Update RLS on public.lessons to allow teachers of the batch to delete
DROP POLICY IF EXISTS "lessons_delete_policy" ON public.lessons;
CREATE POLICY "lessons_delete_policy" ON public.lessons
FOR DELETE TO authenticated
USING (
    (SELECT public.is_admin())
    OR (batch_id IS NOT NULL AND (SELECT public.is_teacher_for_batch(batch_id)))
    OR (course_id IS NOT NULL AND (SELECT public.is_teacher_for_course(course_id)))
);

-- 2. Update RLS on public.lecture_recordings to allow teachers of the batch to delete
DROP POLICY IF EXISTS "lecture_recordings_delete_policy" ON public.lecture_recordings;
CREATE POLICY "lecture_recordings_delete_policy" ON public.lecture_recordings
FOR DELETE TO authenticated
USING (
    (SELECT public.is_admin())
    OR (batch_id IS NOT NULL AND (SELECT public.is_teacher_for_batch(batch_id)))
    OR (teacher_id = (SELECT auth.uid()))
    OR (course_id IS NOT NULL AND (SELECT public.is_teacher_for_course(course_id)))
);

-- 3. Authoritative server-side deletion RPC
CREATE OR REPLACE FUNCTION public.delete_lecture(
    p_lecture_id TEXT,
    p_confirm TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_is_admin BOOLEAN;
    v_lecture_uuid UUID;
    v_deleted_count INT := 0;
    v_item_type TEXT := 'unknown';
    v_lesson_record RECORD;
    v_recording_record RECORD;
BEGIN
    -- 1. Validate confirmation string
    IF lower(trim(COALESCE(p_confirm, ''))) <> 'confirm' THEN
        RAISE EXCEPTION 'Confirmation mismatch. You must pass "confirm" to proceed.';
    END IF;

    -- 2. Validate authentication
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    v_is_admin := public.is_admin();

    -- Try parsing lecture ID as UUID
    BEGIN
        v_lecture_uuid := p_lecture_id::UUID;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid lecture ID format: %', p_lecture_id;
    END;

    -- 3. Check public.lessons first
    SELECT id, course_id, batch_id, title INTO v_lesson_record
    FROM public.lessons
    WHERE id = v_lecture_uuid;

    IF v_lesson_record.id IS NOT NULL THEN
        -- Check permissions
        IF NOT v_is_admin 
           AND NOT (v_lesson_record.batch_id IS NOT NULL AND public.is_teacher_for_batch(v_lesson_record.batch_id))
           AND NOT (v_lesson_record.course_id IS NOT NULL AND public.is_teacher_for_course(v_lesson_record.course_id)) THEN
            RAISE EXCEPTION 'Unauthorized: You can only delete lessons for your assigned batches.';
        END IF;

        DELETE FROM public.lessons WHERE id = v_lecture_uuid;
        GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
        v_item_type := 'lesson';

        RETURN jsonb_build_object(
            'success', true,
            'item_type', v_item_type,
            'deleted_id', p_lecture_id,
            'rows_affected', v_deleted_count
        );
    END IF;

    -- 4. Check public.lecture_recordings
    SELECT id, live_class_id, course_id, batch_id, teacher_id, title INTO v_recording_record
    FROM public.lecture_recordings
    WHERE id = v_lecture_uuid;

    IF v_recording_record.id IS NOT NULL THEN
        -- Check permissions
        IF NOT v_is_admin
           AND NOT (v_recording_record.batch_id IS NOT NULL AND public.is_teacher_for_batch(v_recording_record.batch_id))
           AND NOT (v_recording_record.teacher_id = v_user_id)
           AND NOT (v_recording_record.course_id IS NOT NULL AND public.is_teacher_for_course(v_recording_record.course_id)) THEN
            RAISE EXCEPTION 'Unauthorized: You can only delete recordings for your assigned batches.';
        END IF;

        DELETE FROM public.lecture_recordings WHERE id = v_lecture_uuid;
        GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
        v_item_type := 'lecture_recording';

        -- If linked to a live_class, update live_class status
        IF v_recording_record.live_class_id IS NOT NULL THEN
            UPDATE public.live_classes
            SET recording_status = 'deleted',
                recording_url = NULL
            WHERE id = v_recording_record.live_class_id;
        END IF;

        RETURN jsonb_build_object(
            'success', true,
            'item_type', v_item_type,
            'deleted_id', p_lecture_id,
            'rows_affected', v_deleted_count
        );
    END IF;

    -- 5. If not found in either table by ID, check if it matches a live_classes record
    IF v_is_admin THEN
        DELETE FROM public.live_classes WHERE id = v_lecture_uuid;
    ELSE
        DELETE FROM public.live_classes
        WHERE id = v_lecture_uuid
          AND public.is_teacher_for_batch(batch_id);
    END IF;
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;

    IF v_deleted_count > 0 THEN
        RETURN jsonb_build_object(
            'success', true,
            'item_type', 'live_class',
            'deleted_id', p_lecture_id,
            'rows_affected', v_deleted_count
        );
    END IF;

    RAISE EXCEPTION 'Lecture not found with ID %', p_lecture_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE EXECUTE ON FUNCTION public.delete_lecture(TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_lecture(TEXT, TEXT) TO authenticated;

COMMIT;
