-- ==============================================================================
-- Seed Data for Modern Classes Patna Platform
-- Database: PostgreSQL / Supabase
-- ==============================================================================

-- 1. Seed Courses
INSERT INTO public.courses (id, title, subtitle, category, description, price, original_price, play_product_id, instructor_name, total_lessons, total_hours, total_tests, total_notes, rating, highlights, is_featured, is_published)
VALUES
(
    'a1111111-1111-1111-1111-111111111111',
    'BPSC 71st CCE Prelims & Mains Comprehensive Batch 2026',
    'Complete syllabus coverage with Bihar Special, GS Paper 1 & 2 + 50 Mock Tests',
    'BPSC Civil Services',
    'Master the 71st BPSC Civil Services examination with Patna top civil services mentors. Includes daily live lectures, bilingual notes, NCERT drill, and weekly evaluation.',
    4999.00,
    9999.00,
    'course_bpsc_71st_comprehensive',
    'Madhurendra Kumar Yadav',
    180,
    240,
    50,
    85,
    4.95,
    '["Live Daily Classes (Bilingual)", "Complete Bihar Special GK/GS", "50 Full Length Test Series", "Printed & Digital PDF Notes", "One-on-One Doubt Clearing"]'::JSONB,
    TRUE,
    TRUE
),
(
    'a2222222-2222-2222-2222-222222222222',
    'Bihar SSC (BSSC) Inter Level & CGL 4.0 Target Crash Course',
    'Fast-track 90 days syllabus completion with 5000+ high-yield MCQs',
    'Bihar SSC',
    'Designed specifically for BSSC aspirants focusing on General Studies, Science, Mathematics, and Mental Ability Reasoning with PYQ analysis.',
    1499.00,
    2999.00,
    'course_bssc_cgl_crash',
    'Madhurendra Kumar Yadav',
    95,
    130,
    30,
    45,
    4.88,
    '["90-Day Focused Study Plan", "5000+ Target Practice MCQs", "Complete Math & Reasoning Tricks", "Full Mock Tests with Instant Rank"]'::JSONB,
    TRUE,
    TRUE
),
(
    'a3333333-3333-3333-3333-333333333333',
    'Railway NTPC & Group D Comprehensive Science & Math Booster',
    'Complete Physics, Chemistry, Biology & Arithmetic with previous 10 years papers',
    'Railway Exams',
    'Intensive booster course designed to maximize score in Railway NTPC & Group D CBT-1 and CBT-2 exams.',
    999.00,
    1999.00,
    'course_railway_ntpc_booster',
    'Er. R. K. Singh',
    75,
    100,
    25,
    35,
    4.90,
    '["Complete NCERT Science Coverage", "Speed Math & Shortcuts", "Topic-wise Chapter Tests", "Previous Year Question Drill"]'::JSONB,
    FALSE,
    TRUE
)
ON CONFLICT (id) DO NOTHING;

-- 2. Seed Batches
INSERT INTO public.batches (id, course_id, name, timing, start_date, end_date, assigned_teacher_name, max_students, is_active)
VALUES
(
    'b1111111-1111-1111-1111-111111111111',
    'a1111111-1111-1111-1111-111111111111',
    'BPSC 71st Morning Rankers Batch',
    '07:30 AM - 10:30 AM (Mon-Sat)',
    '2026-09-01',
    '2027-04-30',
    'Madhurendra Kumar Yadav',
    500,
    TRUE
),
(
    'b2222222-2222-2222-2222-222222222222',
    'a2222222-2222-2222-2222-222222222222',
    'BSSC CGL Evening Target Batch',
    '04:00 PM - 07:00 PM (Mon-Sat)',
    '2026-09-10',
    '2026-12-20',
    'Madhurendra Kumar Yadav',
    500,
    TRUE
)
ON CONFLICT (id) DO NOTHING;

-- 3. Seed Announcements
INSERT INTO public.announcements (title, message, type)
VALUES
(
    '🎉 Welcome to Modern Classes Patna Official Learning App!',
    'Welcome aspirants! Access your daily live lectures, test series, and downloadable study notes directly inside the app.',
    'announcement'
),
(
    '📅 BPSC 71st Civil Services New Batch Orientation',
    'Live orientation session for BPSC 71st Batch is scheduled for tomorrow at 8:00 AM. Join from the Live Classes tab.',
    'live'
);
