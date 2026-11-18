-- 009_recreate_batches_view.sql
-- Safely replace vw_batches_with_stats to expose play_product_id by appending it at the end.

CREATE OR REPLACE VIEW public.vw_batches_with_stats WITH (security_invoker = true) AS
SELECT 
    b.id,
    b.course_id,
    b.name,
    b.timing,
    b.start_date,
    b.end_date,
    b.max_students,
    b.batch_price,
    b.medium,
    b.is_active,
    b.created_at,
    b.updated_at,
    p.full_name AS teacher_name, 
    bt.teacher_id,
    (SELECT COUNT(*) FROM public.enrollments e WHERE e.batch_id = b.id AND e.status = 'active') AS total_students,
    b.play_product_id
FROM public.batches b
LEFT JOIN public.batch_teachers bt ON b.id = bt.batch_id AND bt.is_primary = true
LEFT JOIN public.profiles p ON bt.teacher_id = p.id;
