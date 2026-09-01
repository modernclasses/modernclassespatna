-- ==============================================================================
-- Migration 002: Row Level Security (RLS) Policies
-- Database: PostgreSQL / Supabase
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. Enable RLS on All Public Tables
-- ------------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_materials ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.test_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.doubts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

-- ------------------------------------------------------------------------------
-- 2. Security Helper Functions
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS user_role AS $$
    SELECT role FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
    SELECT (public.current_user_role() = 'admin');
$$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.is_teacher_or_admin()
RETURNS BOOLEAN AS $$
    SELECT (public.current_user_role() IN ('teacher', 'admin'));
$$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.is_enrolled_in_course(p_course_id UUID)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.enrollments
        WHERE student_id = auth.uid()
          AND course_id = p_course_id
          AND is_active = TRUE
    );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- ------------------------------------------------------------------------------
-- 3. Profiles Policies
-- ------------------------------------------------------------------------------
-- Authenticated users can view profiles
CREATE POLICY "Allow authenticated to view profiles"
    ON public.profiles FOR SELECT
    TO authenticated
    USING (TRUE);

-- Users can update their own profile
CREATE POLICY "Allow users to update own profile"
    ON public.profiles FOR UPDATE
    TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Admins can update any profile (e.g. promote to teacher, change status)
CREATE POLICY "Allow admins to manage all profiles"
    ON public.profiles FOR ALL
    TO authenticated
    USING (public.is_admin());

-- ------------------------------------------------------------------------------
-- 4. Courses Policies
-- ------------------------------------------------------------------------------
-- Anyone (even unauthenticated) can browse published courses in the catalog
CREATE POLICY "Public read published courses"
    ON public.courses FOR SELECT
    USING (is_published = TRUE);

-- Only Admins can create, edit, or delete courses
CREATE POLICY "Admin full access courses"
    ON public.courses FOR ALL
    TO authenticated
    USING (public.is_admin());

-- ------------------------------------------------------------------------------
-- 5. Batches Policies
-- ------------------------------------------------------------------------------
-- Authenticated users can view batches
CREATE POLICY "View batches for authenticated users"
    ON public.batches FOR SELECT
    TO authenticated
    USING (TRUE);

-- Teachers and Admins can create/edit batches
CREATE POLICY "Teachers and admins manage batches"
    ON public.batches FOR ALL
    TO authenticated
    USING (public.is_teacher_or_admin());

-- ------------------------------------------------------------------------------
-- 6. Enrollments Policies
-- ------------------------------------------------------------------------------
-- Students can only read their own enrollments
CREATE POLICY "Students view own enrollments"
    ON public.enrollments FOR SELECT
    TO authenticated
    USING (auth.uid() = student_id OR public.is_teacher_or_admin());

-- System / Authenticated can insert enrollment on valid purchase
CREATE POLICY "Insert own enrollment"
    ON public.enrollments FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = student_id OR public.is_admin());

-- ------------------------------------------------------------------------------
-- 7. Lessons Policies
-- ------------------------------------------------------------------------------
-- Free preview lessons are open; other lessons require enrollment
CREATE POLICY "View lessons if free or enrolled"
    ON public.lessons FOR SELECT
    TO authenticated
    USING (
        is_free_preview = TRUE
        OR public.is_enrolled_in_course(course_id)
        OR public.is_teacher_or_admin()
    );

-- Teachers and Admins can upload/manage lessons
CREATE POLICY "Teachers and admins manage lessons"
    ON public.lessons FOR ALL
    TO authenticated
    USING (public.is_teacher_or_admin());

-- ------------------------------------------------------------------------------
-- 8. Study Materials Policies
-- ------------------------------------------------------------------------------
-- Students can only read materials if enrolled in the course
CREATE POLICY "Enrolled students view study materials"
    ON public.study_materials FOR SELECT
    TO authenticated
    USING (
        public.is_enrolled_in_course(course_id)
        OR public.is_teacher_or_admin()
    );

CREATE POLICY "Teachers and admins manage study materials"
    ON public.study_materials FOR ALL
    TO authenticated
    USING (public.is_teacher_or_admin());

-- ------------------------------------------------------------------------------
-- 9. Live Classes Policies
-- ------------------------------------------------------------------------------
CREATE POLICY "View live classes if authenticated"
    ON public.live_classes FOR SELECT
    TO authenticated
    USING (TRUE);

CREATE POLICY "Teachers and admins manage live classes"
    ON public.live_classes FOR ALL
    TO authenticated
    USING (public.is_teacher_or_admin());

-- ------------------------------------------------------------------------------
-- 10. Tests & Questions Policies
-- ------------------------------------------------------------------------------
CREATE POLICY "Enrolled students view published tests"
    ON public.tests FOR SELECT
    TO authenticated
    USING (
        status = 'published'
        OR public.is_teacher_or_admin()
    );

CREATE POLICY "Teachers and admins manage tests"
    ON public.tests FOR ALL
    TO authenticated
    USING (public.is_teacher_or_admin());

-- ------------------------------------------------------------------------------
-- 11. Test Submissions Policies
-- ------------------------------------------------------------------------------
-- Students can submit and view their own attempts; teachers/admins can view all
CREATE POLICY "Students manage own test submissions"
    ON public.test_submissions FOR ALL
    TO authenticated
    USING (auth.uid() = student_id OR public.is_teacher_or_admin())
    WITH CHECK (auth.uid() = student_id OR public.is_teacher_or_admin());

-- ------------------------------------------------------------------------------
-- 12. Attendance Policies
-- ------------------------------------------------------------------------------
CREATE POLICY "View attendance records"
    ON public.attendance FOR SELECT
    TO authenticated
    USING (TRUE);

CREATE POLICY "Teachers and admins mark attendance"
    ON public.attendance FOR ALL
    TO authenticated
    USING (public.is_teacher_or_admin());

-- ------------------------------------------------------------------------------
-- 13. Doubts Policies
-- ------------------------------------------------------------------------------
-- Anyone can view resolved doubts; students can view their own
CREATE POLICY "View doubts"
    ON public.doubts FOR SELECT
    TO authenticated
    USING (
        is_resolved = TRUE
        OR auth.uid() = student_id
        OR public.is_teacher_or_admin()
    );

-- Students can insert their own doubt
CREATE POLICY "Students insert doubts"
    ON public.doubts FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = student_id);

-- Teachers and Admins can update/resolve doubts
CREATE POLICY "Teachers and admins resolve doubts"
    ON public.doubts FOR UPDATE
    TO authenticated
    USING (public.is_teacher_or_admin());

-- ------------------------------------------------------------------------------
-- 14. Transactions Policies
-- ------------------------------------------------------------------------------
CREATE POLICY "Students view own transactions"
    ON public.transactions FOR SELECT
    TO authenticated
    USING (auth.uid() = student_id OR public.is_admin());

CREATE POLICY "Insert transactions on purchase"
    ON public.transactions FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = student_id OR public.is_admin());

-- ------------------------------------------------------------------------------
-- 15. Announcements Policies
-- ------------------------------------------------------------------------------
CREATE POLICY "View announcements"
    ON public.announcements FOR SELECT
    TO authenticated
    USING (TRUE);

CREATE POLICY "Admins manage announcements"
    ON public.announcements FOR ALL
    TO authenticated
    USING (public.is_admin());
