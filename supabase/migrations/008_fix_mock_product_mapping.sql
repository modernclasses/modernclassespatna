-- 008_fix_mock_product_mapping.sql
-- Stage 1B Hotfix: Maps the target batch to the mock Edge Function product ID for testing.

UPDATE public.batches
SET play_product_id = 'mock_batch_product_001'
WHERE id = 'b1111111-1111-1111-1111-111111111111'
AND is_active = TRUE;
