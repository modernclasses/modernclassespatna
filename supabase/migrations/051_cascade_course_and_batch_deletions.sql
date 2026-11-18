-- Migration 051: Cascade Course and Batch Deletions
-- Allows safe administrative deletion of courses and batches without 23503 FK constraint violations.

BEGIN;

-- 1. Batches referencing Courses
ALTER TABLE public.batches 
  DROP CONSTRAINT IF EXISTS batches_course_id_fkey;

ALTER TABLE public.batches 
  ADD CONSTRAINT batches_course_id_fkey 
  FOREIGN KEY (course_id) 
  REFERENCES public.courses(id) 
  ON DELETE CASCADE;

-- 2. Lessons referencing Courses and Batches
ALTER TABLE public.lessons 
  DROP CONSTRAINT IF EXISTS lessons_course_id_fkey;

ALTER TABLE public.lessons 
  ADD CONSTRAINT lessons_course_id_fkey 
  FOREIGN KEY (course_id) 
  REFERENCES public.courses(id) 
  ON DELETE CASCADE;

ALTER TABLE public.lessons 
  DROP CONSTRAINT IF EXISTS lessons_batch_id_fkey;

ALTER TABLE public.lessons 
  ADD CONSTRAINT lessons_batch_id_fkey 
  FOREIGN KEY (batch_id) 
  REFERENCES public.batches(id) 
  ON DELETE CASCADE;

-- 3. Enrollments referencing Batches
ALTER TABLE public.enrollments 
  DROP CONSTRAINT IF EXISTS enrollments_batch_id_fkey;

ALTER TABLE public.enrollments 
  ADD CONSTRAINT enrollments_batch_id_fkey 
  FOREIGN KEY (batch_id) 
  REFERENCES public.batches(id) 
  ON DELETE CASCADE;

COMMIT;
