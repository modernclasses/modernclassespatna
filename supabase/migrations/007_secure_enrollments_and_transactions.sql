-- 007_secure_enrollments_and_transactions.sql
-- Stage 1B: Secure Enrollment & Transaction RLS

-- 1. Transactions Security
-- Drop the insecure policy that allows any student to forge transaction records
DROP POLICY IF EXISTS "Insert transactions on purchase" ON public.transactions;
CREATE POLICY "Admins can insert transactions" ON public.transactions FOR INSERT TO authenticated WITH CHECK (public.is_admin());
