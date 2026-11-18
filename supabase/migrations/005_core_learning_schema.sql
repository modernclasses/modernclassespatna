-- 005_core_learning_schema.sql
-- Fix 2: Re-defining core learning schema with strict constraints, RLS, and normalized teacher assignments.

DROP TABLE IF EXISTS public.enrollments CASCADE;
DROP TABLE IF EXISTS public.lessons CASCADE;
DROP TABLE IF EXISTS public.batch_teachers CASCADE;
DROP TABLE IF EXISTS public.batches CASCADE;
DROP TABLE IF EXISTS public.courses CASCADE;

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc', NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE public.courses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    category TEXT NOT NULL,
    description TEXT,
    cover_image_url TEXT,
    price NUMERIC NOT NULL CHECK (price >= 0),
    original_price NUMERIC NOT NULL CHECK (original_price >= 0),
    teacher_id UUID REFERENCES public.profiles(id) ON DELETE RESTRICT,
    total_lessons INT NOT NULL DEFAULT 0,
    total_hours INT NOT NULL DEFAULT 0,
    total_tests INT NOT NULL DEFAULT 0,
    total_notes INT NOT NULL DEFAULT 0,
    rating NUMERIC NOT NULL DEFAULT 4.9 CHECK (rating >= 0 AND rating <= 5),
    reviews_count INT NOT NULL DEFAULT 0,
    highlights TEXT[] DEFAULT '{}',
    is_featured BOOLEAN NOT NULL DEFAULT false,
    is_crash_course BOOLEAN NOT NULL DEFAULT false,
    is_active BOOLEAN NOT NULL DEFAULT true,
    play_product_id TEXT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW())
);

CREATE TRIGGER update_courses_updated_at BEFORE UPDATE ON public.courses FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TABLE public.batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE RESTRICT,
    name TEXT NOT NULL,
    timing TEXT NOT NULL,
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ,
    max_students INT NOT NULL CHECK (max_students > 0),
    batch_price NUMERIC NOT NULL CHECK (batch_price >= 0),
    medium TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW())
);

CREATE TRIGGER update_batches_updated_at BEFORE UPDATE ON public.batches FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TABLE public.batch_teachers (
    batch_id UUID NOT NULL REFERENCES public.batches(id) ON DELETE CASCADE,
    teacher_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    is_primary BOOLEAN NOT NULL DEFAULT false,
    PRIMARY KEY (batch_id, teacher_id)
);

CREATE UNIQUE INDEX idx_batch_teachers_primary ON public.batch_teachers(batch_id) WHERE is_primary = true;

CREATE TABLE public.lessons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE RESTRICT,
    batch_id UUID NOT NULL REFERENCES public.batches(id) ON DELETE RESTRICT,
    title TEXT NOT NULL,
    chapter TEXT NOT NULL,
    video_url TEXT NOT NULL,
    notes_pdf_url TEXT,
    duration_seconds INT NOT NULL DEFAULT 0 CHECK (duration_seconds >= 0),
    order_index INT NOT NULL DEFAULT 0 CHECK (order_index >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    UNIQUE(batch_id, order_index)
);

CREATE TRIGGER update_lessons_updated_at BEFORE UPDATE ON public.lessons FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE OR REPLACE FUNCTION check_lesson_course_match()
RETURNS TRIGGER AS $$
DECLARE
    expected_course_id UUID;
BEGIN
    SELECT course_id INTO expected_course_id FROM public.batches WHERE id = NEW.batch_id;
    IF NEW.course_id != expected_course_id THEN
        RAISE EXCEPTION 'Lesson course_id does not match batch course_id';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_lesson_course BEFORE INSERT OR UPDATE ON public.lessons FOR EACH ROW EXECUTE FUNCTION check_lesson_course_match();

CREATE TABLE public.enrollments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
    batch_id UUID NOT NULL REFERENCES public.batches(id) ON DELETE RESTRICT,
    transaction_id TEXT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'cancelled')),
    enrolled_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    UNIQUE(student_id, batch_id)
);

CREATE OR REPLACE VIEW public.vw_courses_with_stats WITH (security_invoker = true) AS
SELECT 
    c.*,
    p.full_name AS teacher_name
FROM public.courses c
LEFT JOIN public.profiles p ON c.teacher_id = p.id;

CREATE OR REPLACE VIEW public.vw_batches_with_stats WITH (security_invoker = true) AS
SELECT 
    b.*,
    p.full_name AS teacher_name, bt.teacher_id,
    (SELECT COUNT(*) FROM public.enrollments e WHERE e.batch_id = b.id AND e.status = 'active') AS total_students
FROM public.batches b
LEFT JOIN public.batch_teachers bt ON b.id = bt.batch_id AND bt.is_primary = true
LEFT JOIN public.profiles p ON bt.teacher_id = p.id;

CREATE INDEX idx_enrollments_lookup ON public.enrollments(student_id, batch_id, status);
CREATE INDEX idx_batch_teachers_lookup ON public.batch_teachers(teacher_id, batch_id);
CREATE INDEX idx_batches_course_id ON public.batches(course_id);
CREATE INDEX idx_lessons_lookup ON public.lessons(batch_id, order_index);

ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.batch_teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.enrollments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public can view active courses" ON public.courses
FOR SELECT USING (is_active = true OR (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')));

CREATE POLICY "Admins can manage courses" ON public.courses
FOR ALL USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

CREATE POLICY "Public can view active batches" ON public.batches
FOR SELECT USING (is_active = true OR (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')));

CREATE POLICY "Admins can manage batches" ON public.batches
FOR ALL USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

CREATE POLICY "Authenticated users can view batch teachers" ON public.batch_teachers
FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Admins can manage batch teachers" ON public.batch_teachers
FOR ALL USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

CREATE POLICY "Students can view lessons for active enrollments" ON public.lessons
FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.enrollments WHERE student_id = auth.uid() AND batch_id = lessons.batch_id AND status = 'active')
    OR EXISTS (SELECT 1 FROM public.batch_teachers WHERE teacher_id = auth.uid() AND batch_id = lessons.batch_id)
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

CREATE POLICY "Teachers can manage lessons for their batches" ON public.lessons
FOR ALL USING (
    EXISTS (SELECT 1 FROM public.batch_teachers WHERE teacher_id = auth.uid() AND batch_id = lessons.batch_id)
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
)
WITH CHECK (
    EXISTS (SELECT 1 FROM public.batch_teachers WHERE teacher_id = auth.uid() AND batch_id = lessons.batch_id)
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

CREATE POLICY "Students view own enrollments" ON public.enrollments
FOR SELECT USING (
    student_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.batch_teachers WHERE teacher_id = auth.uid() AND batch_id = enrollments.batch_id)
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

CREATE POLICY "Admins manage enrollments" ON public.enrollments
FOR ALL USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));
