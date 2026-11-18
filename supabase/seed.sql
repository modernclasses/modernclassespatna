-- ==============================================================================
-- Seed Data for Modern Classes Patna Platform
-- Database: PostgreSQL / Supabase
-- ==============================================================================

-- 1. Seed Courses
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

-- 2. Seed Batches
INSERT INTO public.batches (id, course_id, name, timing, start_date, end_date, max_students, batch_price, medium, is_active, play_product_id)
VALUES
(
    'b1111111-1111-1111-1111-111111111111',
    'a1111111-1111-1111-1111-111111111111',
    'BPSC 71st Morning Rankers Batch',
    '07:30 AM - 10:30 AM (Mon-Sat)',
    '2026-09-01T00:00:00Z',
    '2027-04-30T23:59:59Z',
    500,
    4999.00,
    'Bilingual',
    TRUE,
    'mock_batch_product_001'
),
(
    'b2222222-2222-2222-2222-222222222222',
    'a2222222-2222-2222-2222-222222222222',
    'BSSC CGL Evening Target Batch',
    '04:00 PM - 07:00 PM (Mon-Sat)',
    '2026-09-10T00:00:00Z',
    '2026-12-20T23:59:59Z',
    500,
    1499.00,
    'Hindi',
    TRUE,
    'course_bssc_cgl_crash'
)
ON CONFLICT (id) DO NOTHING;

-- 3. Seed Announcements
INSERT INTO public.announcements (title, message, type)
VALUES
(
    'Welcome to Modern Classes Patna Official Learning App!',
    'Welcome aspirants! Access your daily live lectures, test series, and downloadable study notes directly inside the app.',
    'announcement'
),
(
    'BPSC 71st Civil Services New Batch Orientation',
    'Live orientation session for BPSC 71st Batch is scheduled for tomorrow at 8:00 AM. Join from the Live Classes tab.',
    'live'
);

-- Test Lessons for Batch A
INSERT INTO public.lessons (id, course_id, batch_id, title, chapter, video_url, duration_seconds, order_index)
VALUES 
(
    'c1111111-1111-1111-1111-111111111111',
    'a1111111-1111-1111-1111-111111111111',
    'b1111111-1111-1111-1111-111111111111',
    'Introduction to BPSC 71st - Syllabus Breakdown',
    'Orientation',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    3600,
    1
),
(
    'c1111111-2222-2222-2222-222222222222',
    'a1111111-1111-1111-1111-111111111111',
    'b1111111-1111-1111-1111-111111111111',
    'Ancient History of Bihar - Magadh Empire',
    'History',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    4200,
    2
)
ON CONFLICT (id) DO NOTHING;

-- Test Lessons for Batch B
INSERT INTO public.lessons (id, course_id, batch_id, title, chapter, video_url, duration_seconds, order_index)
VALUES 
(
    'c2222222-1111-1111-1111-111111111111',
    'a2222222-2222-2222-2222-222222222222',
    'b2222222-2222-2222-2222-222222222222',
    'BSSC CGL Math Tricks & Strategies',
    'Mathematics',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    3000,
    1
),
(
    'c2222222-2222-2222-2222-222222222222',
    'a2222222-2222-2222-2222-222222222222',
    'b2222222-2222-2222-2222-222222222222',
    'General Science - Biology Fundamentals',
    'Science',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    3800,
    2
)
ON CONFLICT (id) DO NOTHING;
