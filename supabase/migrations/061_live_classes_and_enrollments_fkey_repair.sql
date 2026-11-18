-- ==============================================================================
-- Migration: 061_live_classes_and_enrollments_fkey_repair.sql
-- Description: Restores explicit foreign key constraints between live_classes,
--              enrollments, and batches to repair PostgREST PGRST200 schema cache
--              relationship lookups and ensure cascading integrity.
-- ==============================================================================

BEGIN;

-- 1. Ensure live_classes -> batches foreign key constraint is present and valid
ALTER TABLE public.live_classes
    DROP CONSTRAINT IF EXISTS live_classes_batch_id_fkey;

ALTER TABLE public.live_classes
    ADD CONSTRAINT live_classes_batch_id_fkey
    FOREIGN KEY (batch_id)
    REFERENCES public.batches(id)
    ON DELETE CASCADE;

-- 2. Ensure live_classes -> profiles foreign key constraint (teacher_id)
ALTER TABLE public.live_classes
    DROP CONSTRAINT IF EXISTS live_classes_teacher_id_fkey;

ALTER TABLE public.live_classes
    ADD CONSTRAINT live_classes_teacher_id_fkey
    FOREIGN KEY (teacher_id)
    REFERENCES public.profiles(id)
    ON DELETE SET NULL;

-- 3. Ensure enrollments -> batches foreign key constraint is explicitly defined
ALTER TABLE public.enrollments
    DROP CONSTRAINT IF EXISTS enrollments_batch_id_fkey;

ALTER TABLE public.enrollments
    ADD CONSTRAINT enrollments_batch_id_fkey
    FOREIGN KEY (batch_id)
    REFERENCES public.batches(id)
    ON DELETE CASCADE;

-- 4. Create performance indexes if missing
CREATE INDEX IF NOT EXISTS idx_live_classes_batch_id ON public.live_classes(batch_id);
CREATE INDEX IF NOT EXISTS idx_live_classes_teacher_id ON public.live_classes(teacher_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_batch_id ON public.enrollments(batch_id);

-- 5. Notify PostgREST to immediately refresh its schema cache for resource embedding
NOTIFY pgrst, 'reload schema';

COMMIT;
