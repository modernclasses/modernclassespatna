-- ==============================================================================
-- Migration 001: Initial Schema for Modern Classes Patna Platform
-- Database: PostgreSQL / Supabase
-- ==============================================================================

-- Enable UUID extension if not enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ------------------------------------------------------------------------------
-- 1. Custom Enum Types
-- ------------------------------------------------------------------------------
CREATE TYPE user_role AS ENUM ('student', 'teacher', 'admin');
CREATE TYPE payment_status AS ENUM ('success', 'pending', 'failed');
CREATE TYPE live_class_status AS ENUM ('upcoming', 'live', 'ended');
CREATE TYPE test_status AS ENUM ('draft', 'published', 'completed');

-- ------------------------------------------------------------------------------
-- 2. Profiles Table (Extends Supabase auth.users)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    phone TEXT,
    role user_role NOT NULL DEFAULT 'student',
    avatar_url TEXT,
    bio TEXT,
    target_exam TEXT DEFAULT 'BPSC 71st Civil Services',
    medium TEXT DEFAULT 'Bilingual (Hindi + English)',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW())
);

-- Trigger to automatically create profile row on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, email, phone, role)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'Student'),
        NEW.email,
        NEW.raw_user_meta_data->>'phone',
        COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'student')
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ------------------------------------------------------------------------------
-- 3. Courses Catalog Table
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.courses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    subtitle TEXT,
    category TEXT NOT NULL, -- e.g., 'BPSC', 'BSSC', 'Railway', '12th Science'
    description TEXT,
    cover_image_url TEXT,
    price NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    original_price NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    play_product_id TEXT, -- Google Play In-App Product ID (e.g., 'course_bpsc_71st')
    instructor_name TEXT NOT NULL DEFAULT 'Madhurendra Kumar Yadav',
    instructor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    total_lessons INT NOT NULL DEFAULT 0,
    total_hours INT NOT NULL DEFAULT 0,
    total_tests INT NOT NULL DEFAULT 0,
    total_notes INT NOT NULL DEFAULT 0,
    rating NUMERIC(3, 2) NOT NULL DEFAULT 4.90,
    highlights JSONB DEFAULT '[]'::JSONB,
    is_featured BOOLEAN NOT NULL DEFAULT FALSE,
    is_published BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW())
);

-- ------------------------------------------------------------------------------
-- 4. Batches Table
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
    name TEXT NOT NULL, -- e.g., 'Morning Target Batch A'
    timing TEXT NOT NULL, -- e.g., '08:00 AM - 10:00 AM'
    start_date DATE NOT NULL,
    end_date DATE,
    assigned_teacher_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    assigned_teacher_name TEXT NOT NULL,
    max_students INT NOT NULL DEFAULT 500,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW())
);

-- ------------------------------------------------------------------------------
-- 5. Enrollments Table (Course & Batch Access)
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.enrollments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
    batch_id UUID REFERENCES public.batches(id) ON DELETE SET NULL,
    purchase_token TEXT, -- Google Play Purchase Token or Order ID
    amount_paid NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    enrolled_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    UNIQUE(student_id, course_id)
);

-- ------------------------------------------------------------------------------
-- 6. Video Lessons Table
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.lessons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
    batch_id UUID REFERENCES public.batches(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    chapter TEXT NOT NULL,
    video_url TEXT NOT NULL, -- YouTube Unlisted link or CDN stream URL
    duration_seconds INT NOT NULL DEFAULT 0,
    order_index INT NOT NULL DEFAULT 0,
    notes_pdf_url TEXT,
    is_free_preview BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW())
);

-- ------------------------------------------------------------------------------
-- 7. Study Materials / PDFs Table
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.study_materials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
    batch_id UUID REFERENCES public.batches(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    subject TEXT NOT NULL,
    file_url TEXT NOT NULL, -- Supabase Storage URL
    file_type TEXT NOT NULL DEFAULT 'PDF',
    file_size_bytes BIGINT NOT NULL DEFAULT 0,
    uploaded_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW())
);

-- ------------------------------------------------------------------------------
-- 8. Live Classes Table
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.live_classes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id UUID NOT NULL REFERENCES public.batches(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    subject TEXT NOT NULL,
    teacher_name TEXT NOT NULL,
    teacher_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    stream_url TEXT NOT NULL, -- YouTube Live / WebRTC link
    scheduled_at TIMESTAMPTZ NOT NULL,
    duration_minutes INT NOT NULL DEFAULT 60,
    status live_class_status NOT NULL DEFAULT 'upcoming',
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW())
);

-- ------------------------------------------------------------------------------
-- 9. Tests & Questions Table
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.tests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
    batch_id UUID REFERENCES public.batches(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'Full Length Mock',
    subject TEXT NOT NULL,
    duration_minutes INT NOT NULL DEFAULT 60,
    total_marks INT NOT NULL DEFAULT 100,
    negative_marking NUMERIC(3, 2) NOT NULL DEFAULT 0.33,
    status test_status NOT NULL DEFAULT 'published',
    questions JSONB NOT NULL DEFAULT '[]'::JSONB, -- Array of {id, question, options[], correctIndex, explanation}
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW())
);

-- ------------------------------------------------------------------------------
-- 10. Test Submissions Table
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.test_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    test_id UUID NOT NULL REFERENCES public.tests(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    score NUMERIC(6, 2) NOT NULL DEFAULT 0.00,
    total_marks INT NOT NULL DEFAULT 100,
    correct_count INT NOT NULL DEFAULT 0,
    incorrect_count INT NOT NULL DEFAULT 0,
    unattempted_count INT NOT NULL DEFAULT 0,
    time_taken_seconds INT NOT NULL DEFAULT 0,
    answers_json JSONB NOT NULL DEFAULT '{}'::JSONB, -- {questionIndex: selectedIndex}
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    UNIQUE(test_id, student_id)
);

-- ------------------------------------------------------------------------------
-- 11. Attendance Register Table
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id UUID NOT NULL REFERENCES public.batches(id) ON DELETE CASCADE,
    attendance_date DATE NOT NULL,
    present_student_ids UUID[] NOT NULL DEFAULT '{}',
    marked_by_teacher_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    UNIQUE(batch_id, attendance_date)
);

-- ------------------------------------------------------------------------------
-- 12. Doubts Q&A Desk Table
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.doubts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    student_name TEXT NOT NULL,
    student_phone TEXT,
    subject TEXT NOT NULL,
    question_text TEXT NOT NULL,
    attachment_url TEXT,
    is_resolved BOOLEAN NOT NULL DEFAULT FALSE,
    faculty_reply TEXT,
    faculty_name TEXT,
    resolved_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    resolved_at TIMESTAMPTZ
);

-- ------------------------------------------------------------------------------
-- 13. Transactions & Invoices Table
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_number TEXT UNIQUE NOT NULL,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    student_name TEXT NOT NULL,
    course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
    course_title TEXT NOT NULL,
    amount_paid NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    payment_method TEXT NOT NULL DEFAULT 'Google Play In-App Billing',
    transaction_reference TEXT NOT NULL,
    status payment_status NOT NULL DEFAULT 'success',
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW())
);

-- ------------------------------------------------------------------------------
-- 14. Broadcast Announcements Table
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'announcement', -- 'announcement', 'live', 'exam', 'fee'
    target_role user_role, -- NULL means all roles
    target_batch_id UUID REFERENCES public.batches(id) ON DELETE SET NULL,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW())
);

-- ------------------------------------------------------------------------------
-- 15. Performance Indexes
-- ------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_courses_category ON public.courses(category);
CREATE INDEX IF NOT EXISTS idx_enrollments_student ON public.enrollments(student_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_course ON public.enrollments(course_id);
CREATE INDEX IF NOT EXISTS idx_lessons_course ON public.lessons(course_id);
CREATE INDEX IF NOT EXISTS idx_study_materials_course ON public.study_materials(course_id);
CREATE INDEX IF NOT EXISTS idx_live_classes_batch ON public.live_classes(batch_id);
CREATE INDEX IF NOT EXISTS idx_doubts_student ON public.doubts(student_id);
CREATE INDEX IF NOT EXISTS idx_doubts_is_resolved ON public.doubts(is_resolved);
CREATE INDEX IF NOT EXISTS idx_transactions_student ON public.transactions(student_id);
