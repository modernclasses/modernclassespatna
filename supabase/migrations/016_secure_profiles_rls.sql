-- 016_secure_profiles_rls.sql
-- Restrict public.profiles SELECT access to owners and admins

-- 1. Drop the overly permissive SELECT policy
DROP POLICY IF EXISTS "Allow authenticated to view profiles" ON public.profiles;

-- 2. Add the restrictive SELECT policy for regular users
CREATE POLICY "Allow users to view own profile"
    ON public.profiles FOR SELECT
    TO authenticated
    USING (auth.uid() = id);

-- Note: The existing "Allow admins to manage all profiles" policy
-- (FOR ALL USING (public.is_admin())) naturally preserves admin access.
