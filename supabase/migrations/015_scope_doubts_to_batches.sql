-- ==============================================================================
-- Migration: 015_scope_doubts_to_batches.sql
-- Description: Adds batch_id to doubts, enforces teacher-batch scoping, limits
--              inserts to actively enrolled students, and hardens updates to 
--              protect immutable fields and enforce resolution state validity.
--              SAFE MIGRATION: Asserts 0 rows before applying NOT NULL constraint.
-- ==============================================================================

-- 1. Precondition Check: Ensure no data is orphaned or corrupted
DO $$
DECLARE
    doubt_count INT;
BEGIN
    SELECT COUNT(*) INTO doubt_count FROM public.doubts;
    IF doubt_count > 0 THEN
        RAISE EXCEPTION 'Cannot apply migration: public.doubts contains existing rows (%). Resolve these manually before adding NOT NULL batch_id.', doubt_count;
    END IF;
END $$;

-- 2. Safely Add Schema Changes
ALTER TABLE public.doubts ADD COLUMN batch_id UUID REFERENCES public.batches(id) ON DELETE CASCADE;
ALTER TABLE public.doubts ALTER COLUMN batch_id SET NOT NULL;

CREATE INDEX idx_doubts_batch_id ON public.doubts(batch_id);

-- 3. Protect Immutable Fields & Validate Resolution State via Trigger
CREATE OR REPLACE FUNCTION public.validate_doubt_update()
RETURNS TRIGGER AS $$
BEGIN
    -- A. Enforce Immutability
    IF (NEW.id IS DISTINCT FROM OLD.id) THEN
        RAISE EXCEPTION 'Access Denied: The doubt id cannot be modified.';
    END IF;
    IF (NEW.student_id IS DISTINCT FROM OLD.student_id) THEN
        RAISE EXCEPTION 'Access Denied: The student_id cannot be modified.';
    END IF;
    IF (NEW.student_name IS DISTINCT FROM OLD.student_name) THEN
        RAISE EXCEPTION 'Access Denied: The student_name cannot be modified.';
    END IF;
    IF (NEW.student_phone IS DISTINCT FROM OLD.student_phone) THEN
        RAISE EXCEPTION 'Access Denied: The student_phone cannot be modified.';
    END IF;
    IF (NEW.subject IS DISTINCT FROM OLD.subject) THEN
        RAISE EXCEPTION 'Access Denied: The subject cannot be modified.';
    END IF;
    IF (NEW.question_text IS DISTINCT FROM OLD.question_text) THEN
        RAISE EXCEPTION 'Access Denied: The question_text cannot be modified.';
    END IF;
    IF (NEW.attachment_url IS DISTINCT FROM OLD.attachment_url) THEN
        RAISE EXCEPTION 'Access Denied: The attachment_url cannot be modified.';
    END IF;
    IF (NEW.batch_id IS DISTINCT FROM OLD.batch_id) THEN
        RAISE EXCEPTION 'Access Denied: The batch_id cannot be modified.';
    END IF;
    IF (NEW.created_at IS DISTINCT FROM OLD.created_at) THEN
        RAISE EXCEPTION 'Access Denied: The created_at timestamp cannot be modified.';
    END IF;

    -- B. Enforce Resolution State Validity
    IF NEW.is_resolved = true THEN
        IF NEW.faculty_reply IS NULL OR trim(NEW.faculty_reply) = '' THEN
            RAISE EXCEPTION 'Invalid State: faculty_reply must be provided when resolving a doubt.';
        END IF;
        IF NEW.faculty_name IS NULL OR trim(NEW.faculty_name) = '' THEN
            RAISE EXCEPTION 'Invalid State: faculty_name must be provided when resolving a doubt.';
        END IF;
        IF NEW.resolved_by IS NULL OR NEW.resolved_by != auth.uid() THEN
            RAISE EXCEPTION 'Invalid State: resolved_by must match the currently authenticated user (no spoofing).';
        END IF;
        IF NEW.resolved_at IS NULL THEN
            RAISE EXCEPTION 'Invalid State: resolved_at cannot be null when resolving a doubt.';
        END IF;
    ELSE
        IF NEW.faculty_reply IS NOT NULL THEN
            RAISE EXCEPTION 'Invalid State: faculty_reply must be null if doubt is unresolved.';
        END IF;
        IF NEW.faculty_name IS NOT NULL THEN
            RAISE EXCEPTION 'Invalid State: faculty_name must be null if doubt is unresolved.';
        END IF;
        IF NEW.resolved_by IS NOT NULL THEN
            RAISE EXCEPTION 'Invalid State: resolved_by must be null if doubt is unresolved.';
        END IF;
        IF NEW.resolved_at IS NOT NULL THEN
            RAISE EXCEPTION 'Invalid State: resolved_at must be null if doubt is unresolved.';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE EXECUTE ON FUNCTION public.validate_doubt_update() FROM PUBLIC, anon;

DROP TRIGGER IF EXISTS trg_validate_doubt_update ON public.doubts;
CREATE TRIGGER trg_validate_doubt_update
    BEFORE UPDATE ON public.doubts
    FOR EACH ROW
    EXECUTE FUNCTION public.validate_doubt_update();


-- 4. Create the precise batch-teacher helper
CREATE OR REPLACE FUNCTION public.is_teacher_for_batch(p_batch_id UUID)
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.batch_teachers 
        WHERE batch_id = p_batch_id 
          AND teacher_id = auth.uid()
    );
$$ LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp;

REVOKE EXECUTE ON FUNCTION public.is_teacher_for_batch(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_teacher_for_batch(UUID) TO authenticated;


-- 5. Replace all existing doubt policies with strictly scoped equivalents
DROP POLICY IF EXISTS "View doubts" ON public.doubts;
DROP POLICY IF EXISTS "Students insert doubts" ON public.doubts;
DROP POLICY IF EXISTS "Teachers and admins resolve doubts" ON public.doubts;

-- SELECT: Students see own, Teachers see own batches, Admins see all.
CREATE POLICY "View doubts scoped"
    ON public.doubts FOR SELECT
    TO authenticated
    USING (
        auth.uid() = student_id
        OR public.is_teacher_for_batch(batch_id)
        OR public.is_admin()
    );

-- INSERT: Only actively enrolled students can submit doubts for their batch.
CREATE POLICY "Students insert scoped doubts"
    ON public.doubts FOR INSERT
    TO authenticated
    WITH CHECK (
        auth.uid() = student_id
        AND EXISTS (
            SELECT 1 FROM public.enrollments 
            WHERE student_id = auth.uid() 
              AND batch_id = doubts.batch_id 
              AND status = 'active'
        )
        AND is_resolved = false
        AND faculty_reply IS NULL
        AND faculty_name IS NULL
        AND resolved_by IS NULL
        AND resolved_at IS NULL
    );

-- UPDATE: Only assigned teachers or global admins can resolve doubts.
CREATE POLICY "Teachers and admins update scoped doubts"
    ON public.doubts FOR UPDATE
    TO authenticated
    USING (
        public.is_teacher_for_batch(batch_id)
        OR public.is_admin()
    )
    WITH CHECK (
        public.is_teacher_for_batch(batch_id)
        OR public.is_admin()
    );
