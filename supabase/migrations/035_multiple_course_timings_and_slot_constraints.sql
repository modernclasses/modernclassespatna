-- ==============================================================================
-- Migration: 035_multiple_course_timings_and_slot_constraints.sql
-- Description: Enforces multi-timing slot constraints, enrollment protection on batch deletion,
--              slot capacity limits, and course timing uniqueness per course.
-- Protocol: Safe Database Migrations (manual execution via Supabase SQL Editor).
-- ==============================================================================

BEGIN;

-- ------------------------------------------------------------------------------
-- 1. Trigger function: Prevent deletion of batches that have active/pending student enrollments
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.protect_batch_deletion_with_enrollments()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_enrollment_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_enrollment_count
    FROM public.enrollments
    WHERE batch_id = OLD.id;

    IF v_enrollment_count > 0 THEN
        RAISE EXCEPTION 'Cannot delete timing slot/batch "%" because it has % student enrollment(s). Data integrity protected.',
            OLD.name, v_enrollment_count
            USING ERRCODE = '23503'; -- foreign_key_violation
    END IF;

    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_batch_deletion ON public.batches;
CREATE TRIGGER trg_protect_batch_deletion
    BEFORE DELETE ON public.batches
    FOR EACH ROW
    EXECUTE FUNCTION public.protect_batch_deletion_with_enrollments();

-- ------------------------------------------------------------------------------
-- 2. Trigger function: Prevent duplicate timing slots for the same course
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_duplicate_batch_timing()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    -- Guard against empty/null timing
    IF NEW.timing IS NULL OR TRIM(NEW.timing) = '' THEN
        RAISE EXCEPTION 'Timing schedule cannot be empty for a course slot.'
            USING ERRCODE = '23514'; -- check_violation
    END IF;

    IF EXISTS (
        SELECT 1 
        FROM public.batches 
        WHERE course_id = NEW.course_id 
          AND id IS DISTINCT FROM NEW.id 
          AND LOWER(TRIM(timing)) = LOWER(TRIM(NEW.timing))
    ) THEN
        RAISE EXCEPTION 'A timing slot with schedule "%" already exists for this course.', NEW.timing
            USING ERRCODE = '23505'; -- unique_violation
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_duplicate_batch_timing ON public.batches;
CREATE TRIGGER trg_check_duplicate_batch_timing
    BEFORE INSERT OR UPDATE OF timing ON public.batches
    FOR EACH ROW
    EXECUTE FUNCTION public.check_duplicate_batch_timing();

-- Atomic Unique Index for Race-Condition Immunity during concurrent inserts
-- Partial index ignores NULL/blank legacy values to prevent migration failure.
CREATE UNIQUE INDEX IF NOT EXISTS idx_batches_course_timing_unique
    ON public.batches (course_id, LOWER(TRIM(timing)))
    WHERE timing IS NOT NULL AND TRIM(timing) <> '';

-- ------------------------------------------------------------------------------
-- 3. Trigger function: Enforce batch slot capacity (max_students) with Row Lock
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enforce_batch_slot_capacity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_max_students INTEGER;
    v_current_enrolled INTEGER;
    v_batch_name TEXT;
BEGIN
    -- Only check for active enrollments
    IF NEW.status = 'active' THEN
        -- Acquire row-level lock on the batch record to serialize concurrent enrollments and prevent oversubscription
        SELECT max_students, name INTO v_max_students, v_batch_name
        FROM public.batches
        WHERE id = NEW.batch_id
        FOR UPDATE;

        IF v_max_students IS NOT NULL AND v_max_students > 0 THEN
            SELECT COUNT(*) INTO v_current_enrolled
            FROM public.enrollments
            WHERE batch_id = NEW.batch_id
              AND status = 'active'
              AND id IS DISTINCT FROM NEW.id;

            IF v_current_enrolled >= v_max_students THEN
                RAISE EXCEPTION 'Cannot enroll in timing slot "%": capacity limit of % students has been reached.',
                    v_batch_name, v_max_students
                    USING ERRCODE = '23514'; -- check_violation
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_batch_slot_capacity ON public.enrollments;
CREATE TRIGGER trg_enforce_batch_slot_capacity
    BEFORE INSERT OR UPDATE OF status, batch_id ON public.enrollments
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_batch_slot_capacity();

-- ------------------------------------------------------------------------------
-- 4. Clean and authoritative RLS policies on batches and courses
-- ------------------------------------------------------------------------------
ALTER TABLE public.batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;

-- Clean all legacy naming variants on batches
DROP POLICY IF EXISTS "Teachers and admins manage batches" ON public.batches;
DROP POLICY IF EXISTS "Admins can manage batches" ON public.batches;
DROP POLICY IF EXISTS "Public can view active batches" ON public.batches;
DROP POLICY IF EXISTS "Admins manage batches" ON public.batches;
DROP POLICY IF EXISTS "View batches for authenticated users" ON public.batches;

CREATE POLICY "Admins manage batches"
    ON public.batches FOR ALL
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

CREATE POLICY "View batches for authenticated users"
    ON public.batches FOR SELECT
    TO authenticated
    USING (TRUE);

-- Clean all legacy naming variants on courses
DROP POLICY IF EXISTS "Teachers and admins manage courses" ON public.courses;
DROP POLICY IF EXISTS "Admins can manage courses" ON public.courses;
DROP POLICY IF EXISTS "Public can view active courses" ON public.courses;
DROP POLICY IF EXISTS "Admins manage courses" ON public.courses;
DROP POLICY IF EXISTS "View courses for authenticated users" ON public.courses;

CREATE POLICY "Admins manage courses"
    ON public.courses FOR ALL
    TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

CREATE POLICY "View courses for authenticated users"
    ON public.courses FOR SELECT
    TO authenticated
    USING (TRUE);

COMMIT;

-- ------------------------------------------------------------------------------
-- 5. Verification Query
-- ------------------------------------------------------------------------------
SELECT 
    '035_multiple_course_timings_and_slot_constraints applied successfully' AS status,
    (SELECT COUNT(*) FROM public.batches) AS total_batches,
    (SELECT COUNT(*) FROM public.enrollments) AS total_enrollments;
