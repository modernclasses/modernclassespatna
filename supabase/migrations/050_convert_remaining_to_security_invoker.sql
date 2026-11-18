-- ==============================================================================
-- Migration 050: Convert Safe Authorized RPCs to SECURITY INVOKER
-- Database: PostgreSQL / Supabase
-- Target: Modern Classes Patna
--
-- Description:
--   Dynamically inspects pg_proc to find the exact identity arguments for:
--   - start_authenticated_live_session
--   - end_authenticated_live_session
--   - sync_lecture_recording
--   - promote_lecture_recording_status
--   - get_admin_manual_collections_total
--   - admin_set_primary_batch_teacher
--   and converts them to SECURITY INVOKER, clearing them from Lint 0029.
-- ==============================================================================

BEGIN;

DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.proname IN (
              'start_authenticated_live_session',
              'end_authenticated_live_session',
              'sync_lecture_recording',
              'promote_lecture_recording_status',
              'get_admin_manual_collections_total',
              'admin_set_primary_batch_teacher'
          )
    ) LOOP
        EXECUTE format('ALTER FUNCTION public.%I(%s) SECURITY INVOKER;', r.proname, r.args);
    END LOOP;
END $$;

COMMIT;
