import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_classes_patna/features/courses/data/models/batch_model.dart';

void main() {
  group('Security Phase 2: Stream Credentials Isolation (SEC-03)', () {
    test('BatchModel correctly deserializes student view where stream_key and rtmps_url are NULL', () {
      final studentRow = {
        'id': 'b1000000-0000-0000-0000-000000000001',
        'course_id': 'c1000000-0000-0000-0000-000000000001',
        'name': 'Physics Target Batch 2026',
        'timing': '08:00 AM - 10:00 AM',
        'start_date': '2026-05-01T00:00:00Z',
        'end_date': '2026-11-01T00:00:00Z',
        'max_students': 500,
        'batch_price': 999.0,
        'medium': 'Bilingual',
        'is_active': true,
        'teacher_name': 'Prof. H.C. Verma',
        'teacher_id': 't1000000-0000-0000-0000-000000000001',
        'total_students': 42,
        'play_product_id': 'tier_batch_999',
        // Masked for student / anon
        'stream_key': null,
        'playback_url': 'https://customer-xyz.videodelivery.net/stream123/manifest/video.m3u8',
        'rtmps_url': null,
      };

      final batch = BatchModel.fromMap(studentRow);

      expect(batch.id, 'b1000000-0000-0000-0000-000000000001');
      expect(batch.playbackUrl, 'https://customer-xyz.videodelivery.net/stream123/manifest/video.m3u8');
      expect(batch.streamKey, isNull, reason: 'Students must never receive streamKey');
      expect(batch.rtmpsUrl, isNull, reason: 'Students must never receive rtmpsUrl');
    });

    test('BatchModel correctly deserializes staff view where stream_key and rtmps_url are populated', () {
      final staffRow = {
        'id': 'b1000000-0000-0000-0000-000000000001',
        'course_id': 'c1000000-0000-0000-0000-000000000001',
        'name': 'Physics Target Batch 2026',
        'timing': '08:00 AM - 10:00 AM',
        'start_date': '2026-05-01T00:00:00Z',
        'end_date': '2026-11-01T00:00:00Z',
        'max_students': 500,
        'batch_price': 999.0,
        'medium': 'Bilingual',
        'is_active': true,
        'teacher_name': 'Prof. H.C. Verma',
        'teacher_id': 't1000000-0000-0000-0000-000000000001',
        'total_students': 42,
        'play_product_id': 'tier_batch_999',
        'stream_key': 'secret_live_stream_key_999',
        'playback_url': 'https://customer-xyz.videodelivery.net/stream123/manifest/video.m3u8',
        'rtmps_url': 'rtmps://live.cloudflare.com:443/live/',
      };

      final batch = BatchModel.fromMap(staffRow);

      expect(batch.streamKey, 'secret_live_stream_key_999');
      expect(batch.rtmpsUrl, 'rtmps://live.cloudflare.com:443/live/');
      expect(batch.playbackUrl, 'https://customer-xyz.videodelivery.net/stream123/manifest/video.m3u8');
    });
  });

  group('Security Phase 2: Storage Path Regex Protection (SEC-04)', () {
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/',
      caseSensitive: false,
    );

    test('UUID path regex correctly matches valid course storage paths', () {
      const validPath = 'c1000000-0000-0000-0000-000000000001/1740000000_Notes.pdf';
      expect(uuidRegex.hasMatch(validPath), isTrue);

      final courseIdPart = validPath.split('/')[0];
      expect(courseIdPart, 'c1000000-0000-0000-0000-000000000001');
    });

    test('UUID path regex rejects invalid or malformed non-uuid paths preventing PostgreSQL cast crash', () {
      const invalidFlatPath = 'root_document.pdf';
      const invalidPrefixPath = 'course_notes/test.pdf';
      const nonUuidFolder = 'batch1/notes.pdf';

      expect(uuidRegex.hasMatch(invalidFlatPath), isFalse);
      expect(uuidRegex.hasMatch(invalidPrefixPath), isFalse);
      expect(uuidRegex.hasMatch(nonUuidFolder), isFalse);
    });
  });

  group('Security Phase 2: SQL Migration Verifications (043-045)', () {
    test('Migration 043 isolates credentials and sets security_invoker = false', () {
      final file = File('supabase/migrations/043_isolate_live_streaming_credentials.sql');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content.contains('WITH (security_invoker = false)'), isTrue);
      expect(content.contains('REVOKE SELECT (stream_key, rtmps_url) ON TABLE public.batches'), isTrue);
      expect(content.contains('Faculty and Admins view live inputs'), isTrue);
      expect(content.contains("key NOT IN ('live_stream_key', 'live_rtmps_url')"), isTrue);
    });

    test('Migration 044 drops permissive policy and guards UUID cast with regex', () {
      final file = File('supabase/migrations/044_secure_study_materials_storage.sql');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content.contains('DROP POLICY IF EXISTS "Authenticated Read Study Materials"'), isTrue);
      expect(content.contains(r"storage.objects.name ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/'"), isTrue);
      expect(content.contains("bucket_id = 'study-materials'"), isTrue);
      expect(content.contains('file_size_limit = 10485760'), isTrue);
    });

    test('Migration 045 enforces batch ownership, anti-spoofing and conflict guarding', () {
      final file = File('supabase/migrations/045_enforce_recording_and_batch_integrity.sql');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content.contains('public.sync_lecture_recording'), isTrue);
      expect(content.contains('v_batch.course_id != p_course_id'), isTrue);
      expect(content.contains('public.is_teacher_for_batch(p_batch_id)'), isTrue);
      expect(content.contains('v_effective_teacher_id := v_user_id'), isTrue);
      expect(content.contains('v_existing_rec.id IS NOT NULL AND v_user_role = \'teacher\''), isTrue);
      expect(content.contains('REVOKE ALL ON FUNCTION public.sync_lecture_recording'), isTrue);
    });

    test('Migration 046 optimizes RLS InitPlans across all tables to eliminate linter warnings', () {
      final file = File('supabase/migrations/046_optimize_rls_init_plans.sql');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content.contains('public.user_device_tokens'), isTrue);
      expect(content.contains('public.attendance'), isTrue);
      expect(content.contains('public.test_submissions'), isTrue);
      expect(content.contains('public.lecture_recordings'), isTrue);
      expect(content.contains('user_id = (SELECT auth.uid())'), isTrue);
      expect(content.contains('(SELECT public.is_admin())'), isTrue);
    });

    test('Migration 047 hardens SECURITY DEFINER execute permissions and clears storage listing', () {
      final file = File('supabase/migrations/047_advisor_security_hardening.sql');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content.contains('REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, anon;'), isTrue);
      expect(content.contains('REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;'), isTrue);
      expect(content.contains('ALTER FUNCTION public.is_admin() SECURITY INVOKER;'), isTrue);
      expect(content.contains('DROP POLICY IF EXISTS "course_thumbnails_select_policy" ON storage.objects;'), isTrue);
    });

    test('Migration 048 adds covering foreign key indexes and converts validate_doubt_update', () {
      final file = File('supabase/migrations/048_performance_indexes_and_fks.sql');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content.contains('ALTER FUNCTION public.validate_doubt_update() SECURITY INVOKER;'), isTrue);
      expect(content.contains('idx_announcements_target_batch_id'), isTrue);
      expect(content.contains('idx_courses_teacher_id'), isTrue);
      expect(content.contains('idx_cloudflare_live_inputs_batch_id'), isTrue);
      expect(content.contains('DROP INDEX IF EXISTS public.idx_cloudflare_live_inputs_uid;'), isTrue);
    });

    test('Migration 049 removes duplicate indexes on doubts, recordings, and live classes', () {
      final file = File('supabase/migrations/049_deduplicate_indexes.sql');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content.contains('DROP INDEX IF EXISTS public.idx_doubts_student_id;'), isTrue);
      expect(content.contains('DROP INDEX IF EXISTS public.idx_lecture_recordings_course_id;'), isTrue);
      expect(content.contains('DROP INDEX IF EXISTS public.idx_live_classes_batch_id;'), isTrue);
      expect(content.contains('DROP INDEX IF EXISTS public.idx_study_materials_course_id;'), isTrue);
    });

    test('Migration 050 dynamically converts authorized RPCs to SECURITY INVOKER', () {
      final file = File('supabase/migrations/050_convert_remaining_to_security_invoker.sql');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content.contains('pg_get_function_identity_arguments'), isTrue);
      expect(content.contains('sync_lecture_recording'), isTrue);
      expect(content.contains('start_authenticated_live_session'), isTrue);
    });
  });

  group('Security Phase 2: Edge Functions Hardening Verifications (SEC-01 & SEC-02)', () {
    test('send_push_notification validates Authorization and enforces admin or service_role', () {
      final file = File('supabase/functions/send_push_notification/index.ts');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content.contains("req.headers.get('Authorization')"), isTrue);
      expect(content.contains("SUPABASE_SERVICE_ROLE_KEY"), isTrue);
      expect(content.contains("profile?.role === 'admin'"), isTrue);
      expect(content.contains("status: 401"), isTrue);
      expect(content.contains("status: 403"), isTrue);
    });

    test('verify_purchase rejects mock tokens in production and uses Web Crypto RSA-SHA256', () {
      final file = File('supabase/functions/verify_purchase/index.ts');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content.contains("isMockAllowed = allowMock && (environment === 'development'"), isTrue);
      expect(content.contains("BILLING_GATEWAY_UNAVAILABLE"), isTrue);
      expect(content.contains("RSASSA-PKCS1-v1_5"), isTrue);
      expect(content.contains("SHA-256"), isTrue);
      expect(content.contains("purchaseStateGoogle === 'PURCHASED' || purchaseStateGoogle === 0"), isTrue);
    });
  });
}
