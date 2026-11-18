-- ==============================================================================
-- Migration 049: Performance Optimization - Remove Duplicate Indexes
-- Database: PostgreSQL / Supabase
-- Target: Modern Classes Patna
--
-- Description:
--   Removes redundant duplicate indexes identified by Supabase Advisor.
--   Preserves the original indexes so all foreign keys remain fully indexed:
--   1. doubts: drops idx_doubts_student_id (preserves idx_doubts_student)
--   2. lecture_recordings: drops idx_lecture_recordings_course_id, batch_id, teacher_id
--      (preserves idx_lecture_recordings_course, batch, teacher)
--   3. live_classes: drops idx_live_classes_batch_id (preserves idx_live_classes_batch)
--   4. study_materials: drops idx_study_materials_course_id (preserves idx_study_materials_course)
-- ==============================================================================

BEGIN;

DROP INDEX IF EXISTS public.idx_doubts_student_id;
DROP INDEX IF EXISTS public.idx_lecture_recordings_course_id;
DROP INDEX IF EXISTS public.idx_lecture_recordings_batch_id;
DROP INDEX IF EXISTS public.idx_lecture_recordings_teacher_id;
DROP INDEX IF EXISTS public.idx_live_classes_batch_id;
DROP INDEX IF EXISTS public.idx_study_materials_course_id;

COMMIT;
