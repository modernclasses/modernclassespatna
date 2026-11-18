-- 023_secure_display_name_moderation.sql

-- 1. Remove the direct UPDATE policy for students to prevent direct DB bypass
DROP POLICY IF EXISTS "Allow users to update own profile" ON public.profiles;

-- Note: Admins retain ALL access via "Allow admins to manage all profiles" policy
