import 'package:flutter_test/flutter_test.dart';
import 'package:modern_classes_patna/features/courses/data/models/batch_model.dart';
import 'package:modern_classes_patna/features/courses/data/models/course_model.dart';
import 'package:modern_classes_patna/features/courses/data/repositories/course_repository.dart';
import 'package:modern_classes_patna/features/courses/logic/course_provider.dart';

class MockCourseRepositoryWithStreamCreds implements CourseRepository {
  final List<BatchModel> _batches;
  bool updateBatchCalled = false;

  MockCourseRepositoryWithStreamCreds(this._batches);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<CourseModel>> getCourses() async => [
        const CourseModel(
          id: 'course_101',
          title: 'Class 12 Board PCM',
          category: 'CBSE',
          description: 'Physics, Chemistry, Maths',
          coverImageUrl: '',
          price: 2499,
          originalPrice: 4999,
          teacherName: 'Senior Faculty',
          teacherId: 'tch_01',
          totalLessons: 20,
          totalHours: 50,
          totalTests: 5,
          totalNotes: 10,
          highlights: ['Live Classes', 'Recorded Lectures'],
        ),
      ];

  @override
  Future<List<BatchModel>> getBatches() async => List.from(_batches);

  @override
  Future<void> updateBatch(BatchModel batch, {List<String>? teacherIds}) async {
    updateBatchCalled = true;
    final idx = _batches.indexWhere((b) => b.id == batch.id);
    if (idx != -1) {
      _batches[idx] = batch;
    } else {
      _batches.add(batch);
    }
  }

  @override
  Future<void> createBatch(BatchModel batch, {List<String>? teacherIds}) async {
    _batches.add(batch);
  }

  @override
  Future<List<String>> getBatchTeacherIds(String batchId) async => [];
}

void main() {
  group('Batch Stream Credentials Persistence & Enrichment Tests', () {
    test('BatchModel correctly serializes and deserializes streamKey, playbackUrl, rtmpsUrl', () {
      final batch = BatchModel(
        id: 'batch_pcm_1',
        courseId: 'course_101',
        name: 'PCM Morning Batch',
        timing: '07:00 AM - 09:00 AM',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: 'Dr. Verma',
        teacherId: 'tch_01',
        totalStudents: 15,
        maxStudents: 500,
        batchPrice: 2499,
        medium: 'Bilingual (Hindi + English)',
        isActive: true,
        streamKey: 'live_stream_key_cloudflare_abc123',
        playbackUrl: 'https://videodelivery.net/abc123m3u8/manifest/video.m3u8',
        rtmpsUrl: 'rtmps://live.cloudflare.com:443/live/',
      );

      final map = batch.toMap(includeNullsForUpdates: true);
      expect(map['stream_key'], 'live_stream_key_cloudflare_abc123');
      expect(map['playback_url'], 'https://videodelivery.net/abc123m3u8/manifest/video.m3u8');
      expect(map['rtmps_url'], 'rtmps://live.cloudflare.com:443/live/');

      // Deserialization from map
      final restored = BatchModel.fromMap(map);
      expect(restored.streamKey, 'live_stream_key_cloudflare_abc123');
      expect(restored.playbackUrl, 'https://videodelivery.net/abc123m3u8/manifest/video.m3u8');
      expect(restored.rtmpsUrl, 'rtmps://live.cloudflare.com:443/live/');
    });

    test('Enrichment simulates row from vw_batches_with_stats missing stream credentials', () {
      // Raw row from vw_batches_with_stats (which lacks stream_key, playback_url, rtmps_url)
      final rawViewRow = {
        'id': 'batch_pcm_1',
        'course_id': 'course_101',
        'name': 'PCM Morning Batch',
        'timing': '07:00 AM - 09:00 AM',
        'start_date': DateTime.now().toIso8601String(),
        'end_date': DateTime.now().add(const Duration(days: 90)).toIso8601String(),
        'teacher_name': 'Dr. Verma',
        'teacher_id': 'tch_01',
        'total_students': 15,
        'max_students': 500,
        'batch_price': 2499,
        'medium': 'Bilingual (Hindi + English)',
        'is_active': true,
        'play_product_id': null,
        // Notice: stream_key, playback_url, rtmps_url are absent from this view!
      };

      // Raw credentials fetched directly from batches table
      final batchCredentials = {
        'batch_pcm_1': {
          'id': 'batch_pcm_1',
          'stream_key': 'live_secret_key_778899',
          'playback_url': 'https://customer-xyz.cloudflarestream.com/manifest/video.m3u8',
          'rtmps_url': 'rtmps://live.cloudflare.com:443/live/',
        }
      };

      // Simulate enrichment
      final enrichedMap = Map<String, dynamic>.from(rawViewRow);
      final id = enrichedMap['id']?.toString();
      if (id != null && batchCredentials.containsKey(id)) {
        final creds = batchCredentials[id]!;
        if (enrichedMap['stream_key'] == null) {
          enrichedMap['stream_key'] = creds['stream_key'];
        }
        if (enrichedMap['playback_url'] == null) {
          enrichedMap['playback_url'] = creds['playback_url'];
        }
        if (enrichedMap['rtmps_url'] == null) {
          enrichedMap['rtmps_url'] = creds['rtmps_url'];
        }
      }

      final batch = BatchModel.fromMap(enrichedMap);
      expect(batch.streamKey, 'live_secret_key_778899');
      expect(batch.playbackUrl, 'https://customer-xyz.cloudflarestream.com/manifest/video.m3u8');
      expect(batch.rtmpsUrl, 'rtmps://live.cloudflare.com:443/live/');
    });

    test('CourseProvider.updateBatch preserves streamKey and updates in-memory catalog immediately', () async {
      final initialBatch = BatchModel(
        id: 'batch_pcm_1',
        courseId: 'course_101',
        name: 'PCM Morning Batch',
        timing: '07:00 AM - 09:00 AM',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 90)),
        teacherName: 'Dr. Verma',
        teacherId: 'tch_01',
        totalStudents: 15,
        maxStudents: 500,
        batchPrice: 2499,
        medium: 'Bilingual (Hindi + English)',
        isActive: true,
        streamKey: null, // initially unconfigured
        playbackUrl: null,
        rtmpsUrl: null,
      );

      final repo = MockCourseRepositoryWithStreamCreds([initialBatch]);
      final provider = CourseProvider(repository: repo);
      await provider.fetchCatalog();

      expect(provider.batches.first.streamKey, isNull);

      // Admin configures stream credentials in batch settings
      final updatedBatch = initialBatch.copyWith(
        streamKey: 'cf_stream_key_live_9988',
        playbackUrl: 'https://videodelivery.net/cf9988/manifest/video.m3u8',
        rtmpsUrl: 'rtmps://live.cloudflare.com:443/live/',
      );

      await provider.updateBatch(updatedBatch);

      expect(repo.updateBatchCalled, isTrue);
      final currentBatch = provider.batches.firstWhere((b) => b.id == 'batch_pcm_1');
      expect(currentBatch.streamKey, 'cf_stream_key_live_9988');
      expect(currentBatch.playbackUrl, 'https://videodelivery.net/cf9988/manifest/video.m3u8');
      expect(currentBatch.rtmpsUrl, 'rtmps://live.cloudflare.com:443/live/');
    });
  });
}
