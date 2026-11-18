-- ------------------------------------------------------------------------------
-- Migration: 038_remove_max_students_capacity_enforcement.sql
-- Description: Drops the batch slot capacity enforcement trigger and function
--              on enrollments so that course schedules are never artificially
--              blocked or marked "full" by an arbitrary max_students number.
-- ------------------------------------------------------------------------------

-- 1. Drop the capacity check trigger on enrollments
DROP TRIGGER IF EXISTS trg_enforce_batch_slot_capacity ON public.enrollments;

-- 2. Drop the capacity trigger function
DROP FUNCTION IF EXISTS public.enforce_batch_slot_capacity();

-- 3. Make max_students column nullable in batches to maintain backward compatibility
--    with existing records without enforcing any minimum or capacity checks.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'batches'
          AND column_name = 'max_students'
    ) THEN
        ALTER TABLE public.batches ALTER COLUMN max_students DROP NOT NULL;
    END IF;
END $$;
