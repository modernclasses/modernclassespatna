-- ==============================================================================
-- Migration 054: Auto Track Course Tests Stats
-- Modern Classes Patna
-- Automatically tracks and maintains courses.total_tests based on tests in public.tests.
-- ==============================================================================

BEGIN;

-- 1. Drop existing view to allow column schema updates without 42P16 conflict
DROP VIEW IF EXISTS public.vw_courses_with_stats CASCADE;

-- 2. Recreate view vw_courses_with_stats with dynamic live_total_tests
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
    COALESCE((SELECT COUNT(*) FROM public.lessons l WHERE l.course_id = c.id), c.total_lessons) AS live_total_lessons,
    COALESCE((SELECT ROUND(SUM(l.duration_seconds) / 3600.0)::INT FROM public.lessons l WHERE l.course_id = c.id), c.total_hours) AS live_total_hours,
    COALESCE((SELECT COUNT(*) FROM public.tests t WHERE t.course_id = c.id), c.total_tests) AS live_total_tests
FROM public.courses c
LEFT JOIN public.profiles p ON c.teacher_id = p.id;

-- 3. Grant permissions on the view
GRANT SELECT ON public.vw_courses_with_stats TO anon, authenticated, service_role;

-- 4. Trigger function to automatically maintain courses.total_tests
CREATE OR REPLACE FUNCTION public.sync_course_test_stats()
RETURNS TRIGGER AS $$
DECLARE
    v_course_id UUID;
    v_total_tests INT;
BEGIN
    v_course_id := COALESCE(NEW.course_id, OLD.course_id);
    IF v_course_id IS NOT NULL THEN
        SELECT COUNT(*)
        INTO v_total_tests
        FROM public.tests
        WHERE course_id = v_course_id;

        UPDATE public.courses
        SET total_tests = v_total_tests,
            updated_at = TIMEZONE('utc', NOW())
        WHERE id = v_course_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_course_test_stats ON public.tests;
CREATE TRIGGER trg_sync_course_test_stats
AFTER INSERT OR UPDATE OR DELETE ON public.tests
FOR EACH ROW EXECUTE FUNCTION public.sync_course_test_stats();

-- 5. Initial sync of existing courses with actual test counts
UPDATE public.courses c
SET total_tests = COALESCE((SELECT COUNT(*) FROM public.tests t WHERE t.course_id = c.id), 0);

COMMIT;
