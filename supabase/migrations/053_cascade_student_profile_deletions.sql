-- ==============================================================================
-- Migration 053: Cascade Student Profile Deletions & Administrative Student Deletion RPC
-- Modern Classes Patna
-- 
-- Fixes:
-- 1. Foreign key constraint "purchases_student_id_fkey" (and "purchases_student id_fkey") 
--    violating 23503 when deleting student profiles.
-- 2. Foreign key constraint "enrollments_student_id_fkey" set to ON DELETE CASCADE.
-- 3. Foreign key constraint "enrollments_purchase_id_fkey" set to ON DELETE SET NULL.
-- 4. Grants full administrative management policy on public.purchases.
-- 5. Implements public.delete_student_account(p_student_id) RPC to cleanly purge 
--    student data across public tables and auth.users.
-- ==============================================================================

BEGIN;

-- 1. Dynamic Drop & Recreate Foreign Keys with ON DELETE CASCADE
DO $$
DECLARE
    r RECORD;
BEGIN
    -- 1.1 Drop any existing foreign key from purchases(student_id) -> profiles(id)
    FOR r IN (
        SELECT tc.constraint_name 
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
        WHERE tc.constraint_type = 'FOREIGN KEY'
          AND tc.table_schema = 'public'
          AND tc.table_name = 'purchases'
          AND kcu.column_name = 'student_id'
    ) LOOP
        EXECUTE 'ALTER TABLE public.purchases DROP CONSTRAINT IF EXISTS ' || quote_ident(r.constraint_name);
    END LOOP;

    EXECUTE 'ALTER TABLE public.purchases DROP CONSTRAINT IF EXISTS purchases_student_id_fkey';
    EXECUTE 'ALTER TABLE public.purchases DROP CONSTRAINT IF EXISTS "purchases_student id_fkey"';

    -- Re-add with ON DELETE CASCADE
    ALTER TABLE public.purchases 
      ADD CONSTRAINT purchases_student_id_fkey 
      FOREIGN KEY (student_id) 
      REFERENCES public.profiles(id) 
      ON DELETE CASCADE;

    -- 1.2 Drop any existing foreign key from enrollments(student_id) -> profiles(id)
    FOR r IN (
        SELECT tc.constraint_name 
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
        WHERE tc.constraint_type = 'FOREIGN KEY'
          AND tc.table_schema = 'public'
          AND tc.table_name = 'enrollments'
          AND kcu.column_name = 'student_id'
    ) LOOP
        EXECUTE 'ALTER TABLE public.enrollments DROP CONSTRAINT IF EXISTS ' || quote_ident(r.constraint_name);
    END LOOP;

    EXECUTE 'ALTER TABLE public.enrollments DROP CONSTRAINT IF EXISTS enrollments_student_id_fkey';
    EXECUTE 'ALTER TABLE public.enrollments DROP CONSTRAINT IF EXISTS "enrollments_student id_fkey"';

    -- Re-add with ON DELETE CASCADE
    ALTER TABLE public.enrollments 
      ADD CONSTRAINT enrollments_student_id_fkey 
      FOREIGN KEY (student_id) 
      REFERENCES public.profiles(id) 
      ON DELETE CASCADE;

    -- 1.3 Drop any existing foreign key from enrollments(purchase_id) -> purchases(id)
    FOR r IN (
        SELECT tc.constraint_name 
        FROM information_schema.table_constraints tc
        JOIN information_schema.key_column_usage kcu
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
        WHERE tc.constraint_type = 'FOREIGN KEY'
          AND tc.table_schema = 'public'
          AND tc.table_name = 'enrollments'
          AND kcu.column_name = 'purchase_id'
    ) LOOP
        EXECUTE 'ALTER TABLE public.enrollments DROP CONSTRAINT IF EXISTS ' || quote_ident(r.constraint_name);
    END LOOP;

    EXECUTE 'ALTER TABLE public.enrollments DROP CONSTRAINT IF EXISTS enrollments_purchase_id_fkey';

    -- Re-add with ON DELETE SET NULL so deleting purchases never blocks enrollment cleanup
    ALTER TABLE public.enrollments 
      ADD CONSTRAINT enrollments_purchase_id_fkey 
      FOREIGN KEY (purchase_id) 
      REFERENCES public.purchases(id) 
      ON DELETE SET NULL;
END $$;

-- 2. Add Administrator Management RLS Policy for purchases
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'purchases' AND policyname = 'Admins full access on purchases'
    ) THEN
        CREATE POLICY "Admins full access on purchases"
        ON public.purchases FOR ALL
        TO authenticated
        USING (public.is_admin())
        WITH CHECK (public.is_admin());
    END IF;
END $$;

-- 3. Administrative Student Deletion RPC Function
CREATE OR REPLACE FUNCTION public.delete_student_account(p_student_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_target_role TEXT;
BEGIN
    -- 3.1 Authorization: Ensure the calling user is an administrator
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Access denied: Only administrators can delete student accounts.';
    END IF;

    -- 3.2 Role Safety Guard: Protect admins and teachers from accidental account deletion
    SELECT role::TEXT INTO v_target_role FROM public.profiles WHERE id = p_student_id;
    IF v_target_role IS NOT NULL AND v_target_role != 'student' THEN
        RAISE EXCEPTION 'Safety check failed: Cannot delete account with role "%". Only student accounts may be deleted.', v_target_role;
    END IF;

    -- 3.3 Explicit Cleanup of Related Student Data
    DELETE FROM public.enrollments WHERE student_id = p_student_id;
    DELETE FROM public.purchases WHERE student_id = p_student_id;
    DELETE FROM public.doubts WHERE student_id = p_student_id;
    DELETE FROM public.test_submissions WHERE student_id = p_student_id;
    DELETE FROM public.attendance WHERE student_id = p_student_id;
    DELETE FROM public.transactions WHERE student_id = p_student_id;
    DELETE FROM public.user_device_tokens WHERE user_id = p_student_id;

    -- 3.4 Delete Student Profile
    DELETE FROM public.profiles WHERE id = p_student_id;

    -- 3.5 Clean up Supabase Auth Record (frees the email address for new registration)
    BEGIN
        DELETE FROM auth.users WHERE id = p_student_id;
    EXCEPTION WHEN OTHERS THEN
        -- Allow profile deletion to succeed even if auth.users cascade has external locks
        NULL;
    END;

    RETURN TRUE;
END;
$$;

-- Grant permissions on RPC
REVOKE ALL ON FUNCTION public.delete_student_account(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_student_account(UUID) TO authenticated;

COMMIT;
