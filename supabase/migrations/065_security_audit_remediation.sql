-- ==============================================================================
-- Migration 065: Security Audit Release Remediation
-- Database: PostgreSQL / Supabase
-- Target: Modern Classes Patna
--
-- Fixes:
--   1. SEC-01: Restricts public.profiles SELECT policy so students cannot harvest
--      other students' phone numbers, emails, and PII.
--   2. SEC-02: Implements get_student_test_paper(UUID) stripping answer keys and
--      submit_student_test(UUID, JSONB, INT) for authoritative server-side grading.
--   3. SEC-04: Revokes public read on storage.objects for 'lecture-videos' and
--      enforces active enrollment / faculty assignment scoping.
--   4. SEC-08: Scopes storage.objects for 'doubt-attachments' to owner/staff.
--   5. SEC-09: Sets explicit search_path on sync_course_lesson_stats,
--      sync_course_test_stats, do_timings_overlap, parse_lecture_timing (Lint 0011).
--   6. Performance / Lint fixes: Drops duplicate idx_live_classes_batch (Lint 0009)
--      and optimizes live_chat_insert_policy init plan (Lint 0003).
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. SEC-01: Restrict public.profiles SELECT Policy (Stop PII Directory Harvest)
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "profiles_select_policy" ON public.profiles;

CREATE POLICY "profiles_select_policy" ON public.profiles
FOR SELECT TO authenticated
USING (
    -- Users can view their own profile
    id = (SELECT auth.uid())
    -- Administrators can view all profiles
    OR (SELECT public.is_admin())
    -- Normal users can view staff profiles (teachers and admins) for class discovery
    OR role IN ('teacher', 'admin')
);

-- ------------------------------------------------------------------------------
-- 2. SEC-02: Server-Authoritative Test Papers & Submission Grading
-- ------------------------------------------------------------------------------

-- 2a. Stripped Test Paper RPC for Students (No correct answers or explanations leaked)
CREATE OR REPLACE FUNCTION public.get_test_paper(p_test_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_test RECORD;
    v_user_id UUID := auth.uid();
    v_is_staff BOOLEAN;
    v_sanitized_questions JSONB := '[]'::JSONB;
    v_elem JSONB;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    SELECT * INTO v_test FROM public.tests WHERE id = p_test_id;
    IF v_test.id IS NULL THEN
        RAISE EXCEPTION 'Test not found';
    END IF;

    v_is_staff := (SELECT public.is_admin()) 
               OR (v_test.batch_id IS NOT NULL AND (SELECT public.is_teacher_for_batch(v_test.batch_id)))
               OR (v_test.course_id IS NOT NULL AND (SELECT public.is_teacher_for_course(v_test.course_id)));

    -- If staff, return full test with answer keys and explanations
    IF v_is_staff THEN
        RETURN to_jsonb(v_test);
    END IF;

    -- If student, verify enrollment / access permission
    IF NOT public.has_test_access(v_test.course_id, v_test.batch_id) OR v_test.status != 'published' THEN
        RAISE EXCEPTION 'Access denied: You are not enrolled in the batch for this test.';
    END IF;

    -- Strip correctOptionIndices, correct_option_indices, correctIndex, explanation, sampleAnswer from each question
    FOR v_elem IN SELECT * FROM jsonb_array_elements(v_test.questions)
    LOOP
        v_sanitized_questions := v_sanitized_questions || jsonb_build_array(
            v_elem - 'correctOptionIndices' - 'correct_option_indices' - 'correctIndex' - 'explanation' - 'sample_answer' - 'sampleAnswer'
        );
    END LOOP;

    RETURN jsonb_build_object(
        'id', v_test.id,
        'course_id', v_test.course_id,
        'batch_id', v_test.batch_id,
        'title', v_test.title,
        'category', v_test.category,
        'subject', v_test.subject,
        'duration_minutes', v_test.duration_minutes,
        'total_marks', v_test.total_marks,
        'negative_marking', v_test.negative_marking,
        'status', v_test.status,
        'created_at', v_test.created_at,
        'questions', v_sanitized_questions
    );
END;
$$;

REVOKE ALL ON FUNCTION public.get_test_paper(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_test_paper(UUID) TO authenticated, service_role;

-- 2b. Authoritative Server-Side Test Submission & Grading RPC
CREATE OR REPLACE FUNCTION public.submit_student_test(
    p_test_id UUID,
    p_answers_json JSONB,
    p_time_taken_seconds INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_test RECORD;
    v_q JSONB;
    v_q_id TEXT;
    v_q_marks NUMERIC;
    v_correct_indices JSONB;
    v_submitted_answer JSONB;
    v_correct_count INT := 0;
    v_incorrect_count INT := 0;
    v_unattempted_count INT := 0;
    v_score NUMERIC(6, 2) := 0.00;
    v_submission_id UUID;
    v_cor_first INT;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentication required';
    END IF;

    SELECT * INTO v_test FROM public.tests WHERE id = p_test_id;
    IF v_test.id IS NULL THEN
        RAISE EXCEPTION 'Test not found';
    END IF;

    IF NOT (public.has_test_access(v_test.course_id, v_test.batch_id) OR public.is_admin()) THEN
        RAISE EXCEPTION 'Unauthorized: Student is not enrolled for this test.';
    END IF;

    FOR v_q IN SELECT * FROM jsonb_array_elements(v_test.questions)
    LOOP
        v_q_id := v_q->>'id';
        v_q_marks := COALESCE((v_q->>'marks')::NUMERIC, 2.0);
        v_correct_indices := COALESCE(
            v_q->'correct_option_indices',
            v_q->'correctOptionIndices',
            CASE WHEN v_q->'correctIndex' IS NOT NULL 
                 THEN jsonb_build_array((v_q->>'correctIndex')::INT)
                 ELSE '[]'::JSONB END
        );

        v_submitted_answer := p_answers_json->v_q_id;

        IF v_submitted_answer IS NULL THEN
            v_unattempted_count := v_unattempted_count + 1;
        ELSIF jsonb_typeof(v_submitted_answer) = 'number' THEN
            -- Single option index passed as integer (e.g. 0)
            v_cor_first := NULL;
            IF jsonb_array_length(v_correct_indices) > 0 THEN
                v_cor_first := (v_correct_indices->>0)::INT;
            END IF;
            IF v_cor_first IS NOT NULL AND (v_submitted_answer::TEXT)::INT = v_cor_first THEN
                v_correct_count := v_correct_count + 1;
                v_score := v_score + v_q_marks;
            ELSE
                v_incorrect_count := v_incorrect_count + 1;
                v_score := v_score - (v_q_marks * v_test.negative_marking);
            END IF;
        ELSIF jsonb_typeof(v_submitted_answer) = 'array' THEN
            -- Array of selected option indices
            IF jsonb_array_length(v_submitted_answer) = 0 THEN
                v_unattempted_count := v_unattempted_count + 1;
            ELSIF v_submitted_answer = v_correct_indices THEN
                v_correct_count := v_correct_count + 1;
                v_score := v_score + v_q_marks;
            ELSE
                v_incorrect_count := v_incorrect_count + 1;
                v_score := v_score - (v_q_marks * v_test.negative_marking);
            END IF;
        ELSIF jsonb_typeof(v_submitted_answer) = 'string' THEN
            -- Descriptive text answer (subjective: no auto negative marking)
            IF length(trim(v_submitted_answer#>>'{}')) = 0 THEN
                v_unattempted_count := v_unattempted_count + 1;
            END IF;
        ELSE
            v_unattempted_count := v_unattempted_count + 1;
        END IF;
    END LOOP;

    v_score := GREATEST(0.00, LEAST(v_test.total_marks, v_score));

    INSERT INTO public.test_submissions (
        test_id,
        student_id,
        score,
        total_marks,
        correct_count,
        incorrect_count,
        unattempted_count,
        time_taken_seconds,
        answers_json,
        submitted_at
    ) VALUES (
        p_test_id,
        v_user_id,
        v_score,
        v_test.total_marks,
        v_correct_count,
        v_incorrect_count,
        v_unattempted_count,
        p_time_taken_seconds,
        p_answers_json,
        TIMEZONE('utc', NOW())
    )
    ON CONFLICT (test_id, student_id) DO UPDATE SET
        score = EXCLUDED.score,
        correct_count = EXCLUDED.correct_count,
        incorrect_count = EXCLUDED.incorrect_count,
        unattempted_count = EXCLUDED.unattempted_count,
        time_taken_seconds = EXCLUDED.time_taken_seconds,
        answers_json = EXCLUDED.answers_json,
        submitted_at = TIMEZONE('utc', NOW())
    RETURNING id INTO v_submission_id;

    RETURN jsonb_build_object(
        'submission_id', v_submission_id,
        'score', v_score,
        'total_marks', v_test.total_marks,
        'correct_count', v_correct_count,
        'incorrect_count', v_incorrect_count,
        'unattempted_count', v_unattempted_count
    );
END;
$$;

REVOKE ALL ON FUNCTION public.submit_student_test(UUID, JSONB, INT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_student_test(UUID, JSONB, INT) TO authenticated, service_role;

-- ------------------------------------------------------------------------------
-- 3. SEC-04: Drop Public Read Access on lecture-videos Storage Bucket
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "Public Read Lecture Videos" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated Read Lecture Videos" ON storage.objects;
DROP POLICY IF EXISTS "Enrolled students and staff read lecture videos" ON storage.objects;

-- Enforce Course/Batch enrollment scoping for lecture videos
CREATE POLICY "Enrolled students and staff read lecture videos"
ON storage.objects
FOR SELECT TO authenticated
USING (
    bucket_id = 'lecture-videos'
    AND (
        (SELECT public.is_admin())
        OR (
            (SELECT public.current_user_role()) = 'teacher'
            AND storage.objects.name ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/'
            AND (
                (SELECT public.is_teacher_for_course((split_part(storage.objects.name, '/', 1))::uuid))
                OR EXISTS (
                    SELECT 1 FROM public.batch_teachers bt
                    JOIN public.batches b ON bt.batch_id = b.id
                    WHERE bt.teacher_id = (SELECT auth.uid())
                      AND b.course_id = (split_part(storage.objects.name, '/', 1))::uuid
                )
            )
        )
        OR (
            storage.objects.name ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/'
            AND EXISTS (
                SELECT 1 FROM public.enrollments e
                JOIN public.batches b ON e.batch_id = b.id
                WHERE e.student_id = (SELECT auth.uid())
                  AND e.status = 'active'
                  AND b.course_id = (split_part(storage.objects.name, '/', 1))::uuid
            )
        )
    )
);

-- ------------------------------------------------------------------------------
-- 4. SEC-08: Scope doubt-attachments Storage Bucket
-- ------------------------------------------------------------------------------
DROP POLICY IF EXISTS "doubt_attachments_select_policy" ON storage.objects;

CREATE POLICY "doubt_attachments_select_policy" ON storage.objects
FOR SELECT TO authenticated
USING (
    bucket_id = 'doubt-attachments'
    AND (
        (SELECT public.is_admin())
        OR (owner = (SELECT auth.uid()))
        OR ((SELECT public.current_user_role()) = 'teacher')
    )
);

-- ------------------------------------------------------------------------------
-- 5. SEC-09: Fix Mutable search_path on Database Functions (Lint 0011)
-- ------------------------------------------------------------------------------
ALTER FUNCTION public.sync_course_lesson_stats() SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_course_test_stats() SET search_path = public, pg_temp;
ALTER FUNCTION public.do_timings_overlap(TEXT, TEXT) SET search_path = public, pg_temp;
ALTER FUNCTION public.parse_lecture_timing(TEXT) SET search_path = public, pg_temp;

-- ------------------------------------------------------------------------------
-- 6. Performance & Lint Polish (Lint 0009 & Lint 0003)
-- ------------------------------------------------------------------------------
-- Drop duplicate index on live_classes
DROP INDEX IF EXISTS public.idx_live_classes_batch;

-- Optimize live_chat_messages insert policy InitPlan (Lint 0003)
DROP POLICY IF EXISTS "live_chat_insert_policy" ON public.live_chat_messages;
CREATE POLICY "live_chat_insert_policy" ON public.live_chat_messages
FOR INSERT TO authenticated
WITH CHECK (
    (SELECT auth.uid()) IS NOT NULL
);

-- Drop redundant duplicate policies on purchases (Lint 0006)
DROP POLICY IF EXISTS "Admins full access on purchases" ON public.purchases;

COMMIT;
