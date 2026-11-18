import 'package:flutter/foundation.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/utils/batch_timing_helper.dart';
import '../datasources/live_class_remote_data_source.dart';
import '../models/lecture_recording_model.dart';
import '../models/live_class_model.dart';

abstract class LiveClassRepository {
  Future<List<LiveClassModel>> getLiveClasses();
  Future<LiveClassModel> scheduleLiveClass(
    LiveClassModel liveClass, {
    String? teacherId,
  });
  Future<void> updateLiveClassStatus(String id, LiveStatus status);
  Future<String> uploadLiveClassThumbnail({
    required String fileName,
    required Uint8List fileBytes,
  });

  /// Authoritative server-side batch schedule validation
  Future<SlotValidationResult> validateBatchSchedule(String batchId);

  /// Starts an authenticated live session with server-side validation
  Future<LiveClassModel> startAuthenticatedLiveSession({
    required String batchId,
    required String title,
    required String subject,
    required String streamUrl,
    String? thumbnailUrl,
    String? liveInputUid,
  });

  /// Ends live session, records actual duration, and marks recording processing
  Future<void> endAuthenticatedLiveSession(
    String liveClassId, {
    int? durationSeconds,
    DateTime? endTime,
  });

  /// Retrieves lecture recordings with optional filters
  Future<List<LectureRecordingModel>> getLectureRecordings({
    String? courseId,
    String? batchId,
    String? teacherId,
  });

  /// Synchronizes broadcast recording with Cloudflare Stream
  Future<LectureRecordingModel?> syncBroadcastRecording({
    required String batchId,
    required String courseId,
    required String title,
    String? liveClassId,
    String? liveInputUid,
    String? teacherId,
    String? playbackUrl,
    int? durationSeconds,
    DateTime? startTime,
    DateTime? endTime,
  });

  /// Refreshes processing status of a recording from Cloudflare Stream
  Future<LectureRecordingModel?> refreshRecordingStatus(String videoUid);

  /// Checks live input connection status from Cloudflare Stream
  Future<Map<String, dynamic>> checkCloudflareLiveStatus(String liveInputUid);

  /// Updates recording details such as title and thumbnail
  Future<LectureRecordingModel> updateRecordingDetails({
    required String recordingId,
    String? title,
    String? thumbnailUrl,
  });

  /// Deletes a lecture recording permanently
  Future<void> deleteRecording(String recordingId);
}

class LiveClassRepositoryImpl implements LiveClassRepository {
  final LiveClassRemoteDataSource _remoteDataSource;

  LiveClassRepositoryImpl({LiveClassRemoteDataSource? remoteDataSource})
    : _remoteDataSource = remoteDataSource ?? LiveClassRemoteDataSourceImpl();

  @override
  Future<List<LiveClassModel>> getLiveClasses() async {
    try {
      return await _remoteDataSource.getLiveClasses();
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<LiveClassModel> scheduleLiveClass(
    LiveClassModel liveClass, {
    String? teacherId,
  }) async {
    try {
      return await _remoteDataSource.scheduleLiveClass(
        liveClass,
        teacherId: teacherId,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> updateLiveClassStatus(String id, LiveStatus status) async {
    try {
      await _remoteDataSource.updateLiveClassStatus(id, status);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<String> uploadLiveClassThumbnail({
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    try {
      return await _remoteDataSource.uploadLiveClassThumbnail(
        fileName: fileName,
        fileBytes: fileBytes,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<SlotValidationResult> validateBatchSchedule(String batchId) async {
    try {
      return await _remoteDataSource.validateBatchSchedule(batchId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<LiveClassModel> startAuthenticatedLiveSession({
    required String batchId,
    required String title,
    required String subject,
    required String streamUrl,
    String? thumbnailUrl,
    String? liveInputUid,
  }) async {
    try {
      return await _remoteDataSource.startAuthenticatedLiveSession(
        batchId: batchId,
        title: title,
        subject: subject,
        streamUrl: streamUrl,
        thumbnailUrl: thumbnailUrl,
        liveInputUid: liveInputUid,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> endAuthenticatedLiveSession(
    String liveClassId, {
    int? durationSeconds,
    DateTime? endTime,
  }) async {
    try {
      await _remoteDataSource.endAuthenticatedLiveSession(
        liveClassId,
        durationSeconds: durationSeconds,
        endTime: endTime,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<List<LectureRecordingModel>> getLectureRecordings({
    String? courseId,
    String? batchId,
    String? teacherId,
  }) async {
    try {
      return await _remoteDataSource.getLectureRecordings(
        courseId: courseId,
        batchId: batchId,
        teacherId: teacherId,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<LectureRecordingModel?> syncBroadcastRecording({
    required String batchId,
    required String courseId,
    required String title,
    String? liveClassId,
    String? liveInputUid,
    String? teacherId,
    String? playbackUrl,
    int? durationSeconds,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    try {
      return await _remoteDataSource.syncBroadcastRecording(
        batchId: batchId,
        courseId: courseId,
        title: title,
        liveClassId: liveClassId,
        liveInputUid: liveInputUid,
        teacherId: teacherId,
        playbackUrl: playbackUrl,
        durationSeconds: durationSeconds,
        startTime: startTime,
        endTime: endTime,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<LectureRecordingModel?> refreshRecordingStatus(String videoUid) async {
    try {
      return await _remoteDataSource.refreshRecordingStatus(videoUid);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<Map<String, dynamic>> checkCloudflareLiveStatus(
    String liveInputUid,
  ) async {
    try {
      return await _remoteDataSource.checkCloudflareLiveStatus(liveInputUid);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<LectureRecordingModel> updateRecordingDetails({
    required String recordingId,
    String? title,
    String? thumbnailUrl,
  }) async {
    try {
            return await _remoteDataSource.updateRecordingDetails(
        recordingId: recordingId,
        title: title,
        thumbnailUrl: thumbnailUrl,
      );
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }

  @override
  Future<void> deleteRecording(String recordingId) async {
    try {
      await _remoteDataSource.deleteRecording(recordingId);
    } catch (e) {
      throw ErrorHandler.handle(e);
    }
  }
}
