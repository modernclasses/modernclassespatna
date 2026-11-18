-- 028_protect_name_trigger.sql

CREATE OR REPLACE FUNCTION public.protect_profile_fields()
RETURNS TRIGGER AS $$
DECLARE
    v_caller_role user_role;
    v_jwt_role TEXT;
BEGIN
    -- 1. Prevent modifying primary key for everyone
    IF (NEW.id IS DISTINCT FROM OLD.id) THEN
        RAISE EXCEPTION 'Access Denied: The user ID cannot be modified.';
    END IF;

    -- 2. Prevent modifying email directly on profiles (must use Supabase Auth for email changes)
    IF (NEW.email IS DISTINCT FROM OLD.email) THEN
        RAISE EXCEPTION 'Access Denied: Email cannot be updated via profiles table.';
    END IF;

    -- 3. Trusted Server-Side / Service Role bypass
    -- PostgREST sets request.jwt.claims. If missing, this returns NULL.
    v_jwt_role := current_setting('request.jwt.claims', true)::jsonb->>'role';
    IF v_jwt_role = 'service_role' THEN
        -- Ensure updated_at is refreshed even for service_role
        NEW.updated_at = TIMEZONE('utc', NOW());
        RETURN NEW;
    END IF;

    -- 4. Evaluate caller role from profiles
    IF auth.uid() IS NOT NULL THEN
        SELECT role INTO v_caller_role FROM public.profiles WHERE id = auth.uid();
        
        -- Admin bypass: Admins can modify any profile (except ID and email)
        IF v_caller_role = 'admin' THEN
            NEW.updated_at = TIMEZONE('utc', NOW());
            RETURN NEW;
        END IF;
    END IF;

    -- 5. Standard User (Student/Teacher) Rules
    IF auth.uid() = NEW.id THEN
        -- Self-update: Block sensitive fields
        IF (NEW.role IS DISTINCT FROM OLD.role) THEN
            RAISE EXCEPTION 'Access Denied: You cannot modify your own role.';
        END IF;
        
        IF (NEW.is_active IS DISTINCT FROM OLD.is_active) THEN
            RAISE EXCEPTION 'Access Denied: You cannot modify your own active status.';
        END IF;

        -- Immutability enforcement for full_name
        IF (NEW.full_name IS DISTINCT FROM OLD.full_name) THEN
            IF (OLD.full_name IS NOT NULL) THEN
                RAISE EXCEPTION 'Access Denied: Name cannot be changed once set.';
            END IF;
            -- If OLD.full_name IS NULL, they are setting it for the first time.
            -- However, normal users cannot directly UPDATE their name.
            -- Wait, if they do a direct UPDATE while full_name is NULL, should they be allowed?
            -- "no direct student profile name updates" -> We must block direct UPDATE even if it's NULL!
            RAISE EXCEPTION 'Access Denied: Name must be set through the official secure endpoint.';
        END IF;
    ELSE
        -- Someone else is trying to update this profile, and they are not an admin (handled in step 4)
        RAISE EXCEPTION 'Access Denied: Only administrators can modify other profiles.';
    END IF;

    NEW.updated_at = TIMEZONE('utc', NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;

DROP TRIGGER IF EXISTS trg_protect_profile_fields ON public.profiles;
CREATE TRIGGER trg_protect_profile_fields
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.protect_profile_fields();
