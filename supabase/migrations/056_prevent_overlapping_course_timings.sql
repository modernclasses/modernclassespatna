-- ==============================================================================
-- Migration: 056_prevent_overlapping_course_timings.sql
-- Description: Prevents timing slot overlaps for batches belonging to the same course.
--              Extends duplicate check to disallow overlapping class hours on shared days.
-- ==============================================================================

-- 1. Helper function to parse lecture timing string into start_mins, end_mins, and days array
CREATE OR REPLACE FUNCTION public.parse_lecture_timing(p_timing TEXT)
RETURNS TABLE (
    start_mins INT,
    end_mins INT,
    days TEXT[]
)
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_clean TEXT;
    v_paren_pos INT;
    v_time_part TEXT;
    v_days_part TEXT;
    v_dash_pos INT;
    v_start_str TEXT;
    v_end_str TEXT;
    v_colon_pos INT;
    v_start_h INT := 8;
    v_start_m INT := 0;
    v_end_h INT := 10;
    v_end_m INT := 0;
    v_start_mins INT;
    v_end_mins INT;
    v_is_pm BOOLEAN;
    v_days TEXT[];
    v_all_days CONSTANT TEXT[] := ARRAY['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    v_d TEXT;
BEGIN
    v_clean := TRIM(p_timing);
    IF v_clean = '' THEN
        RETURN QUERY SELECT 0, 0, ARRAY[]::TEXT[];
        RETURN;
    END IF;

    -- Days Extraction
    v_paren_pos := POSITION('(' IN v_clean);
    IF v_paren_pos > 0 THEN
        v_time_part := TRIM(SUBSTRING(v_clean FROM 1 FOR v_paren_pos - 1));
        v_days_part := TRIM(REPLACE(REPLACE(SUBSTRING(v_clean FROM v_paren_pos), '(', ''), ')', ''));
    ELSE
        v_time_part := v_clean;
        v_days_part := 'Mon-Sat';
    END IF;

    -- Standardize Days
    IF v_days_part IN ('Daily', 'Mon-Sun') THEN
        v_days := v_all_days;
    ELSIF v_days_part = 'Mon-Sat' THEN
        v_days := ARRAY['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    ELSIF v_days_part = 'Mon-Fri' THEN
        v_days := ARRAY['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    ELSIF v_days_part IN ('Weekend', 'Sat-Sun') THEN
        v_days := ARRAY['Sat', 'Sun'];
    ELSE
        v_days := ARRAY[]::TEXT[];
        FOREACH v_d IN ARRAY v_all_days LOOP
            IF POSITION(v_d IN v_days_part) > 0 THEN
                v_days := ARRAY_APPEND(v_days, v_d);
            END IF;
        END LOOP;
        IF ARRAY_LENGTH(v_days, 1) IS NULL THEN
            v_days := ARRAY['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        END IF;
    END IF;

    -- Time Extraction
    v_dash_pos := POSITION('-' IN v_time_part);
    IF v_dash_pos > 0 THEN
        v_start_str := TRIM(SUBSTRING(v_time_part FROM 1 FOR v_dash_pos - 1));
        v_end_str := TRIM(SUBSTRING(v_time_part FROM v_dash_pos + 1));

        -- Parse start
        v_is_pm := (POSITION('PM' IN UPPER(v_start_str)) > 0);
        v_start_str := TRIM(REPLACE(REPLACE(UPPER(v_start_str), 'AM', ''), 'PM', ''));
        v_colon_pos := POSITION(':' IN v_start_str);
        IF v_colon_pos > 0 THEN
            v_start_h := CAST(SUBSTRING(v_start_str FROM 1 FOR v_colon_pos - 1) AS INT);
            v_start_m := CAST(SUBSTRING(v_start_str FROM v_colon_pos + 1) AS INT);
            IF v_is_pm AND v_start_h < 12 THEN v_start_h := v_start_h + 12; END IF;
            IF NOT v_is_pm AND v_start_h = 12 THEN v_start_h := 0; END IF;
        END IF;

        -- Parse end
        v_is_pm := (POSITION('PM' IN UPPER(v_end_str)) > 0);
        v_end_str := TRIM(REPLACE(REPLACE(UPPER(v_end_str), 'AM', ''), 'PM', ''));
        v_colon_pos := POSITION(':' IN v_end_str);
        IF v_colon_pos > 0 THEN
            v_end_h := CAST(SUBSTRING(v_end_str FROM 1 FOR v_colon_pos - 1) AS INT);
            v_end_m := CAST(SUBSTRING(v_end_str FROM v_colon_pos + 1) AS INT);
            IF v_is_pm AND v_end_h < 12 THEN v_end_h := v_end_h + 12; END IF;
            IF NOT v_is_pm AND v_end_h = 12 THEN v_end_h := 0; END IF;
        END IF;
    END IF;

    v_start_mins := v_start_h * 60 + v_start_m;
    v_end_mins := v_end_h * 60 + v_end_m;
    IF v_end_mins <= v_start_mins THEN
        v_end_mins := v_end_mins + 1440;
    END IF;

    RETURN QUERY SELECT v_start_mins, v_end_mins, v_days;
END;
$$;

-- 2. Function to test if two timing strings overlap
CREATE OR REPLACE FUNCTION public.do_timings_overlap(p_timing_a TEXT, p_timing_b TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_a RECORD;
    v_b RECORD;
BEGIN
    IF TRIM(COALESCE(p_timing_a, '')) = '' OR TRIM(COALESCE(p_timing_b, '')) = '' THEN
        RETURN FALSE;
    END IF;

    IF LOWER(TRIM(p_timing_a)) = LOWER(TRIM(p_timing_b)) THEN
        RETURN TRUE;
    END IF;

    SELECT * INTO v_a FROM public.parse_lecture_timing(p_timing_a);
    SELECT * INTO v_b FROM public.parse_lecture_timing(p_timing_b);

    -- Check if they share any active days
    IF NOT (v_a.days && v_b.days) THEN
        RETURN FALSE;
    END IF;

    -- Interval overlap condition: GREATEST(start_a, start_b) < LEAST(end_a, end_b)
    RETURN GREATEST(v_a.start_mins, v_b.start_mins) < LEAST(v_a.end_mins, v_b.end_mins);
END;
$$;

-- 3. Upgrade trigger function on public.batches to block overlapping slots
CREATE OR REPLACE FUNCTION public.check_duplicate_batch_timing()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_conflict_timing TEXT;
BEGIN
    -- Guard against empty/null timing
    IF NEW.timing IS NULL OR TRIM(NEW.timing) = '' THEN
        RAISE EXCEPTION 'Timing schedule cannot be empty for a course slot.'
            USING ERRCODE = '23514'; -- check_violation
    END IF;

    -- Check for exact duplicate OR overlapping timing slots for the same course
    SELECT timing INTO v_conflict_timing
    FROM public.batches 
    WHERE course_id = NEW.course_id 
      AND id IS DISTINCT FROM NEW.id 
      AND public.do_timings_overlap(timing, NEW.timing)
    LIMIT 1;

    IF v_conflict_timing IS NOT NULL THEN
        RAISE EXCEPTION 'A timing slot with schedule "%" overlaps with existing schedule "%" for this course. Two slots of the same course cannot have overlapping class hours.', NEW.timing, v_conflict_timing
            USING ERRCODE = '23505'; -- unique_violation
    END IF;

    RETURN NEW;
END;
$$;

-- 4. Re-bind trigger on public.batches
DROP TRIGGER IF EXISTS trg_check_duplicate_batch_timing ON public.batches;
CREATE TRIGGER trg_check_duplicate_batch_timing
    BEFORE INSERT OR UPDATE OF timing ON public.batches
    FOR EACH ROW
    EXECUTE FUNCTION public.check_duplicate_batch_timing();

COMMENT ON FUNCTION public.check_duplicate_batch_timing() IS 'Enforces non-overlapping schedule constraints for multiple slots within the same course.';
