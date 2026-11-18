-- 027_fix_signup_trigger.sql

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (
        id,
        full_name,
        email,
        phone,
        role,
        target_exam,
        medium,
        is_active,
        created_at,
        updated_at
    )
    VALUES (
        NEW.id,
        NULL, -- Force NULL so the student must set it via the Edge Function
        NEW.email,
        NEW.raw_user_meta_data->>'phone',
        'student', -- FORCED DEFAULT: Never trust user_metadata for role elevation
        COALESCE(NEW.raw_user_meta_data->>'target_exam', 'BPSC 71st Civil Services'),
        COALESCE(NEW.raw_user_meta_data->>'medium', 'Bilingual (Hindi + English)'),
        TRUE,
        TIMEZONE('utc', NOW()),
        TIMEZONE('utc', NOW())
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp;
