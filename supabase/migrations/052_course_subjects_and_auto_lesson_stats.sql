-- Migration 052: Course Subjects and Automated Curriculum Lesson Stats Tracking
-- Modern Classes Patna
-- Allows administrators to configure course subjects and automatically tracks lesson counts and hours.

-- 1. Add subjects text array column to courses
ALTER TABLE public.courses ADD COLUMN IF NOT EXISTS subjects TEXT[] DEFAULT '{}';

-- 2. Drop existing view to allow column order update without 42P16 column rename conflict
DROP VIEW IF EXISTS public.vw_courses_with_stats CASCADE;

-- 3. Recreate view vw_courses_with_stats with subjects and live dynamic counts
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
    COALESCE((SELECT ROUND(SUM(l.duration_seconds) / 3600.0)::INT FROM public.lessons l WHERE l.course_id = c.id), c.total_hours) AS live_total_hours
FROM public.courses c
LEFT JOIN public.profiles p ON c.teacher_id = p.id;

-- 4. Grant permissions on the view
GRANT SELECT ON public.vw_courses_with_stats TO anon, authenticated, service_role;

-- 5. Trigger function to automatically maintain courses.total_lessons and courses.total_hours
CREATE OR REPLACE FUNCTION public.sync_course_lesson_stats()
RETURNS TRIGGER AS $$
DECLARE
    v_course_id UUID;
    v_total_lessons INT;
    v_total_hours INT;
BEGIN
    v_course_id := COALESCE(NEW.course_id, OLD.course_id);
    IF v_course_id IS NOT NULL THEN
        SELECT 
            COUNT(*), 
            COALESCE(ROUND(SUM(duration_seconds) / 3600.0)::INT, 0)
        INTO v_total_lessons, v_total_hours
        FROM public.lessons
        WHERE course_id = v_course_id;

        UPDATE public.courses
        SET total_lessons = v_total_lessons,
            total_hours = v_total_hours,
            updated_at = TIMEZONE('utc', NOW())
        WHERE id = v_course_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_course_lesson_stats ON public.lessons;
CREATE TRIGGER trg_sync_course_lesson_stats
AFTER INSERT OR UPDATE OR DELETE ON public.lessons
FOR EACH ROW EXECUTE FUNCTION public.sync_course_lesson_stats();

-- 6. Initial sync of existing courses with actual lesson counts and total hours
UPDATE public.courses c
SET 
    total_lessons = COALESCE((SELECT COUNT(*) FROM public.lessons l WHERE l.course_id = c.id), 0),
    total_hours = COALESCE((SELECT ROUND(SUM(duration_seconds) / 3600.0)::INT FROM public.lessons l WHERE l.course_id = c.id), 0);
