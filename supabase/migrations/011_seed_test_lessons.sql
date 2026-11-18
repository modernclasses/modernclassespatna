-- Inserts deterministic test lessons for development.
-- Safe to re-run due to ON CONFLICT DO NOTHING.

INSERT INTO public.lessons (
    id,
    course_id, 
    batch_id, 
    title, 
    chapter, 
    video_url, 
    duration_seconds, 
    order_index
)
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
),
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