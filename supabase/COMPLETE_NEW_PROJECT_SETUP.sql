-- ==============================================================================
-- MODERN CLASSES PATNA: COMPLETE ALL-IN-ONE DATABASE SETUP SCRIPT
-- For New Supabase Project (PostgreSQL)
-- ==============================================================================

-- 1. Enable Required PostgreSQL Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_cron";

-- 2. Custom Enum Types
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('student', 'teacher', 'admin');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE payment_status AS ENUM ('success', 'pending', 'failed');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE live_class_status AS ENUM ('upcoming', 'live', 'ended');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE test_status AS ENUM ('draft', 'published', 'completed');
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- 3. Profiles Table (Linked to Supabase auth.users)
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
    current_device_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW())
);

CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_current_device_id ON public.profiles(current_device_id);

-- 4. Helper Function: Check Admin Status
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'admin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- 5. Courses Table
CREATE TABLE IF NOT EXISTS public.courses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    subtitle TEXT,
    category TEXT NOT NULL,
    description TEXT,
    cover_image_url TEXT,
    price NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    original_price NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    play_product_id TEXT,
    instructor_name TEXT NOT NULL DEFAULT 'Madhurendra Kumar Yadav',
    instructor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    total_lessons INT NOT NULL DEFAULT 0,
    total_hours INT NOT NULL DEFAULT 0,
    total_tests INT NOT NULL DEFAULT 0,
    total_notes INT NOT NULL DEFAULT 0,
    rating NUMERIC(3, 2) NOT NULL DEFAULT 4.90,
    highlights TEXT[] DEFAULT '{}',
    is_featured BOOLEAN NOT NULL DEFAULT FALSE,
    is_published BOOLEAN NOT NULL DEFAULT TRUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW())
);

-- 6. Batches Table
CREATE TABLE IF NOT EXISTS public.batches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    timing TEXT NOT NULL,
    start_date DATE NOT NULL DEFAULT CURRENT_DATE,
    end_date DATE DEFAULT (CURRENT_DATE + INTERVAL '90 days'),
    assigned_teacher_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    assigned_teacher_name TEXT NOT NULL DEFAULT 'Faculty Member',
    max_students INT NOT NULL DEFAULT 500,
    batch_price NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    medium TEXT NOT NULL DEFAULT 'Bilingual (Hindi + English)',
    stream_key TEXT,
    playback_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW())
);

CREATE INDEX IF NOT EXISTS idx_batches_course ON public.batches(course_id);

-- 7. Enrollments Table
CREATE TABLE IF NOT EXISTS public.enrollments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
    batch_id UUID REFERENCES public.batches(id) ON DELETE SET NULL,
    purchase_token TEXT,
    amount_paid NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    enrolled_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    UNIQUE(student_id, course_id)
);

CREATE INDEX IF NOT EXISTS idx_enrollments_student ON public.enrollments(student_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_batch ON public.enrollments(batch_id);

-- 8. Video Lessons Table
CREATE TABLE IF NOT EXISTS public.lessons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
    batch_id UUID REFERENCES public.batches(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    chapter TEXT NOT NULL,
    video_url TEXT NOT NULL,
    duration_seconds INT NOT NULL DEFAULT 0,
    order_index INT NOT NULL DEFAULT 0,
    notes_pdf_url TEXT,
    is_free_preview BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW())
);

-- 9. Study Materials / Notes Table
CREATE TABLE IF NOT EXISTS public.study_materials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id UUID NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
    batch_id UUID REFERENCES public.batches(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    subject TEXT NOT NULL,
    file_url TEXT NOT NULL,
    file_type TEXT NOT NULL DEFAULT 'PDF',
    file_size_bytes BIGINT NOT NULL DEFAULT 0,
    uploaded_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW())
);

-- 10. Live Classes Table
CREATE TABLE IF NOT EXISTS public.live_classes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    batch_id UUID NOT NULL REFERENCES public.batches(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    subject TEXT NOT NULL,
    teacher_name TEXT NOT NULL,
    teacher_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    stream_url TEXT NOT NULL,
    scheduled_at TIMESTAMPTZ NOT NULL,
    duration_minutes INT NOT NULL DEFAULT 90,
    status live_class_status NOT NULL DEFAULT 'upcoming',
    reminder_15m_sent BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW())
);

CREATE INDEX IF NOT EXISTS idx_live_classes_batch ON public.live_classes(batch_id);

-- 11. Tests Table
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
    questions JSONB NOT NULL DEFAULT '[]'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW())
);

-- 12. Test Submissions Table
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
    answers_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    UNIQUE(test_id, student_id)
);

-- 13. Doubts Table
CREATE TABLE IF NOT EXISTS public.doubts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    student_name TEXT NOT NULL,
    student_phone TEXT,
    batch_id UUID REFERENCES public.batches(id) ON DELETE SET NULL,
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

-- 14. Transactions / Fee Invoices Table
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

-- 15. Announcements & Notifications Table
CREATE TABLE IF NOT EXISTS public.announcements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'announcement',
    target_role user_role,
    target_batch_id UUID REFERENCES public.batches(id) ON DELETE SET NULL,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW())
);

-- 16. Platform Settings Table (Live Stream Ingest & Security)
CREATE TABLE IF NOT EXISTS public.platform_settings (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT TIMEZONE('utc', NOW())
);

-- 17. Device Tokens Table (FCM Push Notifications)
CREATE TABLE IF NOT EXISTS public.user_device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL,
    device_type TEXT NOT NULL DEFAULT 'android',
    app_version TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT TIMEZONE('utc', NOW()),
    UNIQUE(user_id, fcm_token)
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON public.user_device_tokens(user_id);

-- 18. User Signup Trigger (Auto-create profile row on signup)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (
        id,
        full_name,
        email,
        phone,
        role,
        target_exam,
        medium,
        is_active,
        created_at,
        updated_at
    )
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'Student Aspirant'),
        NEW.email,
        NEW.raw_user_meta_data->>'phone',
        COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'student'),
        COALESCE(NEW.raw_user_meta_data->>'target_exam', 'BPSC 71st Civil Services'),
        COALESCE(NEW.raw_user_meta_data->>'medium', 'Bilingual (Hindi + English)'),
        TRUE,
        TIMEZONE('utc', NOW()),
        TIMEZONE('utc', NOW())
    )
    ON CONFLICT (id) DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone = COALESCE(EXCLUDED.phone, public.profiles.phone);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 19. Device Token Registration RPC
CREATE OR REPLACE FUNCTION public.register_device_token(
    p_fcm_token TEXT,
    p_device_type TEXT DEFAULT 'android',
    p_app_version TEXT DEFAULT '1.0.0'
)
RETURNS void AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    INSERT INTO public.user_device_tokens (user_id, fcm_token, device_type, app_version, updated_at)
    VALUES (auth.uid(), p_fcm_token, p_device_type, p_app_version, NOW())
    ON CONFLICT (user_id, fcm_token) 
    DO UPDATE SET 
        device_type = EXCLUDED.device_type,
        app_version = EXCLUDED.app_version,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 20. Automated 15-Minute Class Reminder Function
CREATE OR REPLACE FUNCTION public.process_upcoming_class_reminders()
RETURNS void AS $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN 
        SELECT 
            lc.id,
            lc.title,
            lc.subject,
            lc.teacher_name,
            lc.batch_id,
            b.name AS batch_name,
            lc.scheduled_at
        FROM public.live_classes lc
        JOIN public.batches b ON b.id = lc.batch_id
        WHERE lc.status = 'upcoming'
          AND lc.reminder_15m_sent = FALSE
          AND lc.scheduled_at <= NOW() + INTERVAL '15 minutes'
          AND lc.scheduled_at >= NOW() - INTERVAL '5 minutes'
    LOOP
        INSERT INTO public.announcements (
            title,
            message,
            type,
            target_batch_id,
            created_at
        )
        VALUES (
            '⏰ 15-Min Class Reminder: ' || r.title,
            'Reminder: Live class for ' || r.batch_name || ' on ' || r.subject || ' (' || r.teacher_name || ') starts in 15 minutes! Please be ready with your notes.',
            'liveClass',
            r.batch_id,
            NOW()
        );

        UPDATE public.live_classes
        SET reminder_15m_sent = TRUE
        WHERE id = r.id;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 21. Row Level Security (RLS) Policies
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_materials ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.test_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.doubts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platform_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_device_tokens ENABLE ROW LEVEL SECURITY;

-- Allow public read on courses and batches
CREATE POLICY "Public read active courses" ON public.courses FOR SELECT USING (is_active = true);
CREATE POLICY "Public read active batches" ON public.batches FOR SELECT USING (is_active = true);

-- Allow authenticated read on announcements
CREATE POLICY "Read announcements" ON public.announcements FOR SELECT TO authenticated USING (true);
CREATE POLICY "Insert announcements" ON public.announcements FOR INSERT TO authenticated WITH CHECK (true);

-- Allow authenticated read on lessons, study materials, live classes
CREATE POLICY "Read lessons" ON public.lessons FOR SELECT TO authenticated USING (true);
CREATE POLICY "Read study materials" ON public.study_materials FOR SELECT TO authenticated USING (true);
CREATE POLICY "Read live classes" ON public.live_classes FOR SELECT TO authenticated USING (true);
CREATE POLICY "Manage live classes" ON public.live_classes FOR ALL TO authenticated USING (true);

-- Allow users to manage their own profiles and device tokens
CREATE POLICY "Read profiles" ON public.profiles FOR SELECT TO authenticated USING (true);
CREATE POLICY "Update own profile" ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = id);

CREATE POLICY "Own device tokens" ON public.user_device_tokens FOR ALL TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Platform settings access
CREATE POLICY "Read platform settings" ON public.platform_settings FOR SELECT TO authenticated USING (true);
CREATE POLICY "Manage platform settings" ON public.platform_settings FOR ALL TO authenticated USING (true);

-- 22. Seed Foundation Courses & Batches
INSERT INTO public.courses (id, title, category, description, price, original_price, total_lessons, total_hours, total_tests, total_notes, rating, highlights, is_featured, is_active, play_product_id)
VALUES
(
    'a1111111-1111-1111-1111-111111111111',
    'BPSC 71st CCE Prelims & Mains Comprehensive Batch 2026',
    'BPSC Civil Services',
    'Master the 71st BPSC Civil Services examination with Patna top civil services mentors. Includes daily live lectures, bilingual notes, NCERT drill, and weekly evaluation.',
    4999.00,
    9999.00,
    180,
    240,
    50,
    85,
    4.95,
    ARRAY['Live Daily Classes (Bilingual)', 'Complete Bihar Special GK/GS', '50 Full Length Test Series', 'Printed & Digital PDF Notes', 'One-on-One Doubt Clearing'],
    TRUE,
    TRUE,
    'course_bpsc_71st_comprehensive'
),
(
    'a2222222-2222-2222-2222-222222222222',
    'Bihar SSC (BSSC) Inter Level & CGL 4.0 Target Crash Course',
    'Bihar SSC',
    'Designed specifically for BSSC aspirants focusing on General Studies, Science, Mathematics, and Mental Ability Reasoning with PYQ analysis.',
    1499.00,
    2999.00,
    95,
    130,
    30,
    45,
    4.88,
    ARRAY['90-Day Focused Study Plan', '5000+ Target Practice MCQs', 'Complete Math & Reasoning Tricks', 'Full Mock Tests with Instant Rank'],
    TRUE,
    TRUE,
    'course_bssc_cgl_crash'
),
(
    'a3333333-3333-3333-3333-333333333333',
    'Railway NTPC & Group D Comprehensive Science & Math Booster',
    'Railway Exams',
    'Intensive booster course designed to maximize score in Railway NTPC & Group D CBT-1 and CBT-2 exams.',
    999.00,
    1999.00,
    75,
    100,
    25,
    35,
    4.90,
    ARRAY['Complete NCERT Science Coverage', 'Speed Math & Shortcuts', 'Topic-wise Chapter Tests', 'Previous Year Question Drill'],
    FALSE,
    TRUE,
    'course_railway_ntpc_booster'
)
ON CONFLICT (id) DO NOTHING;

-- Seed Batches for Courses
INSERT INTO public.batches (id, course_id, name, timing, start_date, end_date, max_students, batch_price, medium, is_active)
VALUES
(
    'b1111111-1111-1111-1111-111111111111',
    'a1111111-1111-1111-1111-111111111111',
    'Morning Target Batch A',
    '08:00 AM - 10:00 AM (Mon-Sat)',
    CURRENT_DATE,
    CURRENT_DATE + INTERVAL '90 days',
    500,
    4999.00,
    'Bilingual (Hindi + English)',
    TRUE
),
(
    'b2222222-2222-2222-2222-222222222222',
    'a1111111-1111-1111-1111-111111111111',
    'Evening Foundation Batch B',
    '05:00 PM - 07:00 PM (Mon-Sat)',
    CURRENT_DATE,
    CURRENT_DATE + INTERVAL '90 days',
    500,
    4999.00,
    'Bilingual (Hindi + English)',
    TRUE
),
(
    'b3333333-3333-3333-3333-333333333333',
    'a2222222-2222-2222-2222-222222222222',
    'BSSC Target Super 50 Batch',
    '10:30 AM - 12:30 PM (Mon-Sat)',
    CURRENT_DATE,
    CURRENT_DATE + INTERVAL '60 days',
    500,
    1499.00,
    'Hindi',
    TRUE
),
(
    'b4444444-4444-4444-4444-444444444444',
    'a3333333-3333-3333-3333-333333333333',
    'Railway Fast-Track Batch 1',
    '02:00 PM - 04:00 PM (Mon-Sat)',
    CURRENT_DATE,
    CURRENT_DATE + INTERVAL '60 days',
    500,
    999.00,
    'Bilingual (Hindi + English)',
    TRUE
)
ON CONFLICT (id) DO NOTHING;

-- Default Platform Settings for Live Streaming
INSERT INTO public.platform_settings (key, value)
VALUES (
    'live_streaming',
    '{
        "rtmp_url": "rtmps://live.cloudflare.com:443/live/",
        "stream_key": "",
        "playback_url": ""
    }'::JSONB
)
ON CONFLICT (key) DO NOTHING;
