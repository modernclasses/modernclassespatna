-- 010_secure_study_materials.sql

-- 1. Safely replace the broken helper function with the new schema relationship.
CREATE OR REPLACE FUNCTION public.is_enrolled_in_course(p_course_id UUID)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 
        FROM public.enrollments e
        JOIN public.batches b ON e.batch_id = b.id
        WHERE e.student_id = auth.uid()
          AND e.status = 'active'
          AND b.course_id = p_course_id
    );
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

-- 2. Create the combined helper for study materials (handling course-wide vs batch-specific).
CREATE OR REPLACE FUNCTION public.has_study_material_access(p_course_id UUID, p_batch_id UUID)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 
        FROM public.enrollments e
        JOIN public.batches b ON e.batch_id = b.id
        WHERE e.student_id = auth.uid()
          AND e.status = 'active'
          AND (
              (p_batch_id IS NOT NULL AND e.batch_id = p_batch_id)
              OR 
              (p_batch_id IS NULL AND b.course_id = p_course_id)
          )
    );
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

-- 3. Replace the study_materials SELECT policy to use the new helper.
DROP POLICY IF EXISTS "Enrolled students view study materials" ON public.study_materials;
CREATE POLICY "Enrolled students view study materials"
    ON public.study_materials FOR SELECT
    TO authenticated
    USING (
        public.has_study_material_access(course_id, batch_id)
        OR public.is_teacher_or_admin()
    );
