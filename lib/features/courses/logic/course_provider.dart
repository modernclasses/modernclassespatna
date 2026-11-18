import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../models/payment_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/recent_lecture_playback.dart';
import '../data/models/course_model.dart';
import '../data/models/batch_model.dart';
import '../data/repositories/course_repository.dart';
import '../../../../core/utils/batch_timing_helper.dart';

enum LectureUploadStatus { idle, uploading, inserting, success, failure, cancelled }

class LectureUploadTask {
  final String batchId;
  final String batchName;
  final String courseId;
  final String title;
  final String chapter;
  final String fileName;
  final String? filePath;
  final Uint8List? fileBytes;
  final String? thumbnailName;
  final Uint8List? thumbnailBytes;
  final String? thumbnailUrl;
  final int totalBytes;

  int uploadedBytes = 0;
  double progress = 0.0;
  LectureUploadStatus status = LectureUploadStatus.uploading;
  String? error;
  VideoLessonModel? createdLesson;
  bool isCancelled = false;

  LectureUploadTask({
    required this.batchId,
    required this.batchName,
    required this.courseId,
    required this.title,
    required this.chapter,
    required this.fileName,
    this.filePath,
    this.fileBytes,
    this.thumbnailName,
    this.thumbnailBytes,
    this.thumbnailUrl,
    required this.totalBytes,
  });

  void cancel() {
    isCancelled = true;
    status = LectureUploadStatus.cancelled;
    error = 'Upload cancelled by user.';
  }
}

class CourseProvider extends ChangeNotifier {
  final CourseRepository _repository;

  List<CourseModel> _courses = [];
  List<BatchModel> _batches = [];
  final List<VideoLessonModel> _videoLessons = [];
  final List<CouponModel> _coupons = [];

  LectureUploadTask? _activeUploadTask;
  LectureUploadTask? get activeUploadTask => _activeUploadTask;
  bool get isUploadingLecture =>
      _activeUploadTask != null &&
      (_activeUploadTask!.status == LectureUploadStatus.uploading ||
          _activeUploadTask!.status == LectureUploadStatus.inserting);

  void cancelLectureUpload() {
    if (_activeUploadTask != null) {
      _activeUploadTask!.cancel();
      notifyListeners();
    }
  }

  void clearActiveUpload() {
    _activeUploadTask = null;
    notifyListeners();
  }
  List<PaymentTransactionModel> _studentTransactions = [];
  final List<PaymentTransactionModel> _adminLedger = [];
  double? _adminManualCollectionsTotal;
  bool _isLoadingCollectionsTotal = false;
  String? _collectionsTotalError;
  bool _isLoadingLedger = false;
  bool _hasMoreLedger = true;
  String? _ledgerError;

  bool _isLoading = false;
  List<String> _myAssignedBatchIds = [];
  List<String> get myAssignedBatchIds => _myAssignedBatchIds;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  List<String> _myEnrolledCourseIds = [];
  List<String> _myEnrolledBatchIds = [];
  bool _isLoadingEnrollments = false;

  List<String> get myEnrolledCourseIds => _myEnrolledCourseIds;
  List<String> get myEnrolledBatchIds => _myEnrolledBatchIds;
  bool get isLoadingEnrollments => _isLoadingEnrollments;

  List<CourseModel> get myEnrolledCourses =>
      _courses.where((c) => _myEnrolledCourseIds.contains(c.id)).toList();

  List<BatchModel> get myEnrolledBatches =>
      _batches.where((b) => _myEnrolledBatchIds.contains(b.id)).toList();

  List<CourseModel> get courses => _courses;
  List<BatchModel> get batches => _batches;
  List<VideoLessonModel> get videoLessons => _videoLessons;
  List<RecentLecturePlayback> _recentPlaybacks = [];
  List<RecentLecturePlayback> get recentPlaybacks => List.unmodifiable(_recentPlaybacks);
  RecentLecturePlayback? get mostRecentPlayback => _recentPlaybacks.isNotEmpty ? _recentPlaybacks.first : null;
  String? _currentPlaybackUserId;
  List<CouponModel> get coupons => _coupons;
  List<PaymentTransactionModel> get studentTransactions => _studentTransactions;
  List<PaymentTransactionModel> get adminLedger => _adminLedger;
  double? get adminManualCollectionsTotal => _adminManualCollectionsTotal;

  /// Net manual collections after deducting Google's 15% Play Store commission (85% of gross).
  double? get adminNetCollectionsTotal =>
      _adminManualCollectionsTotal != null
          ? double.parse((_adminManualCollectionsTotal! * 0.85).toStringAsFixed(2))
          : null;

  /// Google Play commission amount (15% of gross).
  double? get adminGoogleCommissionTotal =>
      _adminManualCollectionsTotal != null
          ? double.parse((_adminManualCollectionsTotal! * 0.15).toStringAsFixed(2))
          : null;
  bool get isLoadingCollectionsTotal => _isLoadingCollectionsTotal;
  String? get collectionsTotalError => _collectionsTotalError;
  bool get isLoadingLedger => _isLoadingLedger;
  bool get hasMoreLedger => _hasMoreLedger;
  String? get ledgerError => _ledgerError;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;

  List<String> get categories {
    final set = {'All'};
    for (var c in _courses) {
      set.add(c.category);
    }
    return set.toList();
  }

  List<CourseModel> get filteredCourses {
    return _courses.where((course) {
      final matchesSearch =
          course.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          course.description.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          course.category.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory =
          _selectedCategory == 'All' || course.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  Future<void> fetchMyEnrollments() async {
    if (_isLoadingEnrollments) return;
    _isLoadingEnrollments = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final enrollments = await _repository.getMyEnrollments();
      _myEnrolledCourseIds = enrollments['courseIds'] ?? [];
      _myEnrolledBatchIds = enrollments['batchIds'] ?? [];

      // Resolve any missing course IDs from loaded batches in memory to guarantee
      // course-level access even if direct SQL nested joins encountered schema cache limitations.
      final resolvedCourseIds = Set<String>.from(_myEnrolledCourseIds);
      for (final bId in _myEnrolledBatchIds) {
        final match = _batches.where((b) => b.id == bId).firstOrNull;
        if (match != null && match.courseId.isNotEmpty) {
          resolvedCourseIds.add(match.courseId);
        }
      }
      _myEnrolledCourseIds = resolvedCourseIds.toList();

      // Fetch lessons for all enrolled batches into a temporary list to prevent race conditions
      final allLoadedLessons = <VideoLessonModel>[];
      for (final batchId in _myEnrolledBatchIds.toSet()) {
        try {
          final batchLessons = await _repository.getVideoLessons(batchId);
          for (final bl in batchLessons) {
            final exists = allLoadedLessons.any((existing) =>
                existing.id == bl.id ||
                (existing.videoUrl.isNotEmpty && existing.videoUrl == bl.videoUrl) ||
                (existing.title.trim().toLowerCase() == bl.title.trim().toLowerCase() &&
                    (bl.duration == Duration.zero || existing.duration > Duration.zero)));
            if (!exists) {
              allLoadedLessons.add(bl);
            }
          }
        } catch (e) {
          debugPrint('Failed to load lessons for batch $batchId: $e');
        }
      }

      _videoLessons.clear();
      _videoLessons.addAll(allLoadedLessons);

      // Re-apply cached student playback progress to in-memory lessons
      for (final p in _recentPlaybacks) {
        final idx = _videoLessons.indexWhere((l) => l.id == p.lectureId);
        if (idx != -1) {
          _videoLessons[idx] = _videoLessons[idx].copyWith(
            progressPercent: p.progressPercent,
            isCompleted: p.progressPercent >= 0.75,
          );
        }
      }
    } catch (e) {
      _errorMessage = "Failed to load enrollments: $e";
    } finally {
      _isLoadingEnrollments = false;
      notifyListeners();
    }
  }

  CourseProvider({CourseRepository? repository})
    : _repository = repository ?? CourseRepositoryImpl() {
    _initCoupons();
    fetchCatalog();
  }

  void _initCoupons() {
    if (_coupons.isEmpty) {
      _coupons.addAll([
        const CouponModel(
          code: "FREE100",
          discountAmount: 100,
          discountType: "percentage",
          minOrderValue: 0,
          description: "100% Free Full Course Access",
          isActive: true,
          applicableCourseIds: [],
        ),
        const CouponModel(
          code: "SCHOLARSHIP100",
          discountAmount: 100,
          discountType: "percentage",
          minOrderValue: 0,
          description: "100% Merit Scholarship Access",
          isActive: true,
          applicableCourseIds: [],
        ),
        const CouponModel(
          code: "PATNA50",
          discountAmount: 200,
          discountType: "flat",
          minOrderValue: 500,
          description: "Special Patna Aspirant Flat ₹200 Off",
          isActive: true,
          applicableCourseIds: [],
        ),
        const CouponModel(
          code: "WELCOME100",
          discountAmount: 100,
          discountType: "flat",
          minOrderValue: 400,
          description: "New Student Enrollment Welcome Discount",
          isActive: true,
          applicableCourseIds: [],
        ),
        const CouponModel(
          code: "BPSC300",
          discountAmount: 300,
          discountType: "flat",
          minOrderValue: 1000,
          description: "Civil Services Foundation Batch Flat ₹300 Off",
          isActive: true,
          applicableCourseIds: [],
        ),
      ]);
    }
  }

  Future<void> fetchCoupons() async {
    try {
      final fetchedCoupons = await _repository.getCoupons();
      if (fetchedCoupons.isNotEmpty) {
        _coupons.clear();
        _coupons.addAll(fetchedCoupons);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching coupons: $e');
    }
  }

  Future<bool> addCustomCoupon(CouponModel coupon) async {
    try {
      CouponModel persisted;
      if (coupon.id != null && coupon.id!.isNotEmpty) {
        await _repository.updateCoupon(coupon);
        persisted = coupon;
      } else {
        persisted = await _repository.createCoupon(coupon);
      }

      final idx = _coupons.indexWhere(
        (c) => c.code.toUpperCase() == persisted.code.trim().toUpperCase(),
      );
      if (idx != -1) {
        _coupons[idx] = persisted;
      } else {
        _coupons.insert(0, persisted);
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error saving coupon to database: $e');
      // Update in-memory so UI responds
      final idx = _coupons.indexWhere(
        (c) => c.code.toUpperCase() == coupon.code.trim().toUpperCase(),
      );
      if (idx != -1) {
        _coupons[idx] = coupon;
      } else {
        _coupons.insert(0, coupon);
      }
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCoupon(CouponModel coupon) async {
    return await addCustomCoupon(coupon);
  }

  void updateCouponEligibleCourses(String code, List<String> courseIds) {
    final idx = _coupons.indexWhere(
      (c) => c.code.toUpperCase() == code.trim().toUpperCase(),
    );
    if (idx != -1) {
      final updated = _coupons[idx].copyWith(applicableCourseIds: courseIds);
      _coupons[idx] = updated;
      notifyListeners();
      _repository.updateCoupon(updated).catchError((e) {
        debugPrint('Error updating coupon eligible courses: $e');
      });
    }
  }

  void toggleCouponCourseEligibility(String code, String courseId) {
    final idx = _coupons.indexWhere(
      (c) => c.code.toUpperCase() == code.trim().toUpperCase(),
    );
    if (idx != -1) {
      final currentList = List<String>.from(_coupons[idx].applicableCourseIds);
      if (currentList.contains(courseId)) {
        currentList.remove(courseId);
      } else {
        currentList.add(courseId);
      }
      final updated = _coupons[idx].copyWith(applicableCourseIds: currentList);
      _coupons[idx] = updated;
      notifyListeners();
      _repository.updateCoupon(updated).catchError((e) {
        debugPrint('Error toggling coupon course: $e');
      });
    }
  }

  List<CouponModel> getCouponsForCourse(String courseId) {
    return _coupons.where((c) => c.isActive && c.isEligibleForCourse(courseId)).toList();
  }

  Future<void> removeCustomCoupon(String code) async {
    final target = _coupons.firstWhere(
      (c) => c.code.toUpperCase() == code.trim().toUpperCase(),
      orElse: () => const CouponModel(code: '', discountAmount: 0, description: ''),
    );
    _coupons.removeWhere(
      (c) => c.code.toUpperCase() == code.trim().toUpperCase(),
    );
    notifyListeners();

    if (target.id != null && target.id!.isNotEmpty) {
      try {
        await _repository.deleteCoupon(target.id!);
      } catch (e) {
        debugPrint('Error deleting coupon from database: $e');
      }
    }
  }

  /// Asynchronously fetch courses and batches from repository.
  Future<void> fetchCatalog() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetchedCourses = await _repository.getCourses();
      final fetchedBatches = await _repository.getBatches();

      _courses = fetchedCourses;
      _batches = fetchedBatches;

      // Fetch coupons from Supabase database concurrently
      try {
        final fetchedCoupons = await _repository.getCoupons();
        if (fetchedCoupons.isNotEmpty) {
          _coupons.clear();
          _coupons.addAll(fetchedCoupons);
        }
      } catch (ce) {
        debugPrint('Error fetching coupons in catalog: $ce');
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  CourseModel? getCourseById(String id) {
    try {
      return _courses.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  BatchModel? getBatchById(String id) {
    try {
      return _batches.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  List<BatchModel> getBatchesForCourse(String courseId) {
    return _batches.where((b) => b.courseId == courseId).toList();
  }

  List<VideoLessonModel> getLessonsForBatch(String batchId) {
    final rawLessons = _videoLessons.where((l) => l.batchId == batchId).toList();
    final sorted = List<VideoLessonModel>.from(rawLessons)
      ..sort((a, b) => b.duration.compareTo(a.duration));

    final seenIds = <String>{};
    final seenUrls = <String>{};
    final seenTitles = <String>{};
    final deduplicated = <VideoLessonModel>[];

    for (final l in sorted) {
      if (seenIds.contains(l.id)) continue;
      if (l.videoUrl.isNotEmpty && seenUrls.contains(l.videoUrl)) continue;

      final normTitle = l.title.trim().toLowerCase();
      if (seenTitles.contains(normTitle) && l.duration == Duration.zero) continue;
      if (seenTitles.contains(normTitle) && l.videoUrl.isNotEmpty && seenUrls.any((u) => u.isNotEmpty)) {
        continue;
      }

      seenIds.add(l.id);
      if (l.videoUrl.isNotEmpty) seenUrls.add(l.videoUrl);
      seenTitles.add(normTitle);
      deduplicated.add(l);
    }

    return deduplicated;
  }

  void updateLessonProgress(
    String lessonId,
    double progress, [
    bool? isCompleted,
  ]) {
    final index = _videoLessons.indexWhere((l) => l.id == lessonId);
    if (index != -1) {
      final lesson = _videoLessons[index];
      _videoLessons[index] = lesson.copyWith(
        progressPercent: progress,
        isCompleted: isCompleted ?? (progress >= 0.75),
      );
    }

    // Also update progress in recent playbacks if present
    final rIndex = _recentPlaybacks.indexWhere((p) => p.lectureId == lessonId);
    if (rIndex != -1) {
      final rItem = _recentPlaybacks[rIndex];
      _recentPlaybacks[rIndex] = rItem.copyWith(
        progressPercent: progress,
        lastWatchedAt: DateTime.now(),
      );
      _persistRecentPlaybacks();
    }

    notifyListeners();
  }

  Future<void> loadRecentPlaybacks(String userId) async {
    if (userId.isEmpty) return;
    _currentPlaybackUserId = userId;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'student_recent_playbacks_$userId';
      final rawList = prefs.getStringList(key);
      if (rawList != null && rawList.isNotEmpty) {
        _recentPlaybacks = rawList
            .map((str) {
              try {
                return RecentLecturePlayback.fromJson(str);
              } catch (_) {
                return null;
              }
            })
            .whereType<RecentLecturePlayback>()
            .toList();

        // Sort descending by most recent
        _recentPlaybacks.sort((a, b) => b.lastWatchedAt.compareTo(a.lastWatchedAt));

        // Sync with in-memory lessons
        for (final p in _recentPlaybacks) {
          final idx = _videoLessons.indexWhere((l) => l.id == p.lectureId);
          if (idx != -1) {
            _videoLessons[idx] = _videoLessons[idx].copyWith(
              progressPercent: p.progressPercent,
              isCompleted: p.progressPercent >= 0.75,
            );
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[CourseProvider] Error loading recent playbacks: $e');
    }
  }

  Future<void> recordLecturePlayback({
    required String lectureId,
    required String courseId,
    required String batchId,
    required String courseName,
    required String batchName,
    required String title,
    required String subject,
    required String teacherName,
    required String videoUrl,
    String? thumbnailUrl,
    required Duration duration,
    required double progressPercent,
    required int positionSeconds,
    bool isLiveRecording = false,
    String? userId,
  }) async {
    final effectiveUserId = userId ?? _currentPlaybackUserId;

    final updatedItem = RecentLecturePlayback(
      lectureId: lectureId,
      courseId: courseId,
      batchId: batchId,
      courseName: courseName,
      batchName: batchName,
      title: title,
      subject: subject,
      teacherName: teacherName,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      duration: duration,
      progressPercent: progressPercent.clamp(0.0, 1.0),
      positionSeconds: positionSeconds,
      lastWatchedAt: DateTime.now(),
      isLiveRecording: isLiveRecording,
    );

    // Place at the very front of recent playbacks
    _recentPlaybacks.removeWhere((p) => p.lectureId == lectureId);
    _recentPlaybacks.insert(0, updatedItem);

    if (_recentPlaybacks.length > 15) {
      _recentPlaybacks = _recentPlaybacks.sublist(0, 15);
    }

    // Sync in-memory lesson list
    final idx = _videoLessons.indexWhere((l) => l.id == lectureId);
    if (idx != -1) {
      _videoLessons[idx] = _videoLessons[idx].copyWith(
        progressPercent: progressPercent.clamp(0.0, 1.0),
        isCompleted: progressPercent >= 0.75,
      );
    }

    notifyListeners();

    if (effectiveUserId != null && effectiveUserId.isNotEmpty) {
      _persistRecentPlaybacks(effectiveUserId);
    }
  }

  Future<void> _persistRecentPlaybacks([String? userId]) async {
    final effectiveUserId = userId ?? _currentPlaybackUserId;
    if (effectiveUserId == null || effectiveUserId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'student_recent_playbacks_$effectiveUserId';
      final rawList = _recentPlaybacks.map((p) => p.toJson()).toList();
      await prefs.setStringList(key, rawList);
    } catch (e) {
      debugPrint('[CourseProvider] Error persisting recent playbacks: $e');
    }
  }

  Future<void> addCourse(
    CourseModel course, {
    List<BatchModel>? initialBatches,
    Map<int, List<String>>? batchTeacherIds,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.createCourse(
        course,
        initialBatches: initialBatches,
        batchTeacherIds: batchTeacherIds,
      );
    } catch (e) {
      _errorMessage = 'Create failed: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }

    await fetchCatalog();
    if (_errorMessage != null) {
      final originalError = _errorMessage;
      _errorMessage =
          'Created successfully, but failed to refresh catalog: $originalError';
      notifyListeners();
      throw Exception('refresh_failed');
    }
  }

  Future<void> updateCourse(CourseModel course) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.updateCourse(course);
    } catch (e) {
      _errorMessage = 'Course update failed: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }

    await fetchCatalog();
    if (_errorMessage != null) {
      final originalError = _errorMessage;
      _errorMessage =
          'Updated successfully, but failed to refresh catalog: $originalError';
      notifyListeners();
      throw Exception('refresh_failed');
    }
  }

  Future<void> addBatch(BatchModel batch, {List<String>? teacherIds}) async {
    final existingBatches = getBatchesForCourse(batch.courseId).where((b) => b.id != batch.id);
    final conflict = BatchTimingHelper.findOverlappingTiming(
      batch.timing,
      existingBatches.map((b) => b.timing),
    );
    if (conflict != null) {
      final msg = 'Timing overlaps with an existing course slot ($conflict). Two slots of the same course cannot have overlapping class hours on the same days.';
      _errorMessage = msg;
      notifyListeners();
      throw Exception(msg);
    }

    _isLoading = true;
    _errorMessage = null;
    if (batch.id.isNotEmpty && !_batches.any((b) => b.id == batch.id)) {
      _batches.add(batch);
    }
    notifyListeners();
    try {
      await _repository.createBatch(batch, teacherIds: teacherIds);
    } catch (e) {
      _errorMessage = 'Create failed: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }

    await fetchCatalog();
    if (_errorMessage != null) {
      final originalError = _errorMessage;
      _errorMessage =
          'Created successfully, but failed to refresh catalog: $originalError';
      notifyListeners();
      throw Exception('refresh_failed');
    }
  }

  Future<void> updateBatch(BatchModel batch, {List<String>? teacherIds}) async {
    final existingBatches = getBatchesForCourse(batch.courseId).where((b) => b.id != batch.id);
    final conflict = BatchTimingHelper.findOverlappingTiming(
      batch.timing,
      existingBatches.map((b) => b.timing),
    );
    if (conflict != null) {
      final msg = 'Timing overlaps with an existing course slot ($conflict). Two slots of the same course cannot have overlapping class hours on the same days.';
      _errorMessage = msg;
      notifyListeners();
      throw Exception(msg);
    }

    _isLoading = true;
    _errorMessage = null;
    final idx = _batches.indexWhere((b) => b.id == batch.id);
    if (idx != -1) {
      _batches[idx] = batch;
    }
    notifyListeners();
    try {
      await _repository.updateBatch(batch, teacherIds: teacherIds);
    } catch (e) {
      _errorMessage = 'Update failed: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }

    await fetchCatalog();
    if (_errorMessage != null) {
      final originalError = _errorMessage;
      _errorMessage =
          'Updated successfully, but failed to refresh catalog: $originalError';
      notifyListeners();
      throw Exception('refresh_failed');
    }
  }

  Future<List<String>> getBatchTeacherIds(String batchId) async {
    try {
      return await _repository.getBatchTeacherIds(batchId);
    } catch (e) {
      return [];
    }
  }

  Future<void> updateBatchTeachers(
    String batchId,
    List<String> teacherIds,
  ) async {
    try {
      await _repository.updateBatchTeachers(batchId, teacherIds);
      await fetchCatalog();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteBatch(String batchId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.deleteBatch(batchId);
    } catch (e) {
      _errorMessage = 'Delete failed: $e';
      _isLoading = false;
      notifyListeners();
      rethrow;
    }

    await fetchCatalog();
    if (_errorMessage != null) {
      final originalError = _errorMessage;
      _errorMessage =
          'Deleted successfully, but failed to refresh catalog: $originalError';
      notifyListeners();
      throw Exception('refresh_failed');
    }
  }

  CouponValidationResult validateCouponDetailed(
    String code,
    double amount, {
    String? courseId,
  }) {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      return const CouponValidationResult(
        status: CouponValidationStatus.notFound,
        errorMessage: "Please enter a coupon code.",
      );
    }

    try {
      final coupon = _coupons.firstWhere(
        (c) => c.code.toUpperCase() == cleanCode,
      );

      if (!coupon.isActive) {
        return CouponValidationResult(
          status: CouponValidationStatus.inactive,
          coupon: coupon,
          errorMessage: "Coupon '$cleanCode' is currently inactive.",
        );
      }

      if (!coupon.isFreeCourse && amount < coupon.minOrderValue) {
        return CouponValidationResult(
          status: CouponValidationStatus.minOrderNotMet,
          coupon: coupon,
          errorMessage:
              "Minimum order value of ₹${coupon.minOrderValue.toInt()} required for coupon '$cleanCode'.",
        );
      }

      if (!coupon.isEligibleForCourse(courseId)) {
        return CouponValidationResult(
          status: CouponValidationStatus.courseNotEligible,
          coupon: coupon,
          errorMessage: "Coupon '$cleanCode' is not eligible for this course.",
        );
      }

      return CouponValidationResult(
        status: CouponValidationStatus.valid,
        coupon: coupon,
      );
    } catch (_) {
      return const CouponValidationResult(
        status: CouponValidationStatus.notFound,
        errorMessage: "Invalid coupon code.",
      );
    }
  }

  CouponModel? validateCoupon(String code, double amount, {String? courseId}) {
    final result = validateCouponDetailed(code, amount, courseId: courseId);
    return result.isValid ? result.coupon : null;
  }

  Future<void> processPayment({
    required String purchaseToken,
    String? batchId,
    String? couponCode,
    double? amountPaid,
  }) async {
    await _repository.enrollInBatch(
      purchaseToken: purchaseToken,
      batchId: batchId,
      couponCode: couponCode,
      amountPaid: amountPaid,
    );
    if (batchId != null && !_myEnrolledBatchIds.contains(batchId)) {
      _myEnrolledBatchIds.add(batchId);
    }
    await fetchMyEnrollments();
    notifyListeners();
  }

  /// Direct 0 rupee / 100% scholarship bypass for Scenario 1
  Future<void> enrollFreeBatch({
    required String batchId,
    String? couponCode,
  }) async {
    await _repository.enrollInBatch(
      batchId: batchId,
      amountPaid: 0.0,
      couponCode: couponCode,
    );
    if (!_myEnrolledBatchIds.contains(batchId)) {
      _myEnrolledBatchIds.add(batchId);
    }
    await fetchMyEnrollments();
    notifyListeners();
  }

  Future<List<BatchModel>> adminGetAllBatches() async {
    try {
      return await _repository.adminGetAllBatches();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return [];
    }
  }

  Future<void> fetchMyTeacherAssignments(String teacherId) async {
    try {
      final res = await _repository.getTeacherAssignments(teacherId);
      _myAssignedBatchIds = res.map((a) => a['batch_id'] as String).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load my teacher assignments: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getTeacherAssignments(
    String teacherId,
  ) async {
    try {
      _isLoading = true;
      notifyListeners();
      return await _repository.getTeacherAssignments(teacherId);
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> assignTeacherToBatch(String teacherId, String batchId) async {
    try {
      _isLoading = true;
      notifyListeners();
      await _repository.assignTeacherToBatch(teacherId, batchId);
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> removeTeacherFromBatch(String teacherId, String batchId) async {
    try {
      _isLoading = true;
      notifyListeners();
      await _repository.removeTeacherFromBatch(teacherId, batchId);
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setPrimaryBatchTeacher(String teacherId, String batchId) async {
    try {
      _isLoading = true;
      notifyListeners();
      await _repository.setPrimaryBatchTeacher(teacherId, batchId);
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchStudentTransactions(String studentId) async {
    _isLoadingLedger = true;
    _ledgerError = null;
    notifyListeners();
    try {
      _studentTransactions = await _repository.getStudentTransactions(
        studentId,
      );
    } catch (e) {
      _ledgerError = e.toString();
    } finally {
      _isLoadingLedger = false;
      notifyListeners();
    }
  }

  Future<void> fetchAdminLedger({bool refresh = false}) async {
    if (_isLoadingLedger) return;

    if (refresh) {
      _adminLedger.clear();
      _hasMoreLedger = true;
    }
    if (!_hasMoreLedger) return;

    _isLoadingLedger = true;
    _ledgerError = null;
    notifyListeners();

    try {
      final newItems = await _repository.getAdminLedger(
        _adminLedger.length,
        20,
      );
      if (newItems.isEmpty) {
        _hasMoreLedger = false;
      } else {
        for (var item in newItems) {
          if (!_adminLedger.any((e) => e.id == item.id)) {
            _adminLedger.add(item);
          }
        }
        if (newItems.length < 20) {
          _hasMoreLedger = false;
        }
      }
    } catch (e) {
      _ledgerError = e.toString();
    } finally {
      _isLoadingLedger = false;
      notifyListeners();
    }
  }

  Future<void> fetchAdminManualCollectionsTotal() async {
    if (_isLoadingCollectionsTotal) return;
    _isLoadingCollectionsTotal = true;
    _collectionsTotalError = null;
    notifyListeners();

    try {
      _adminManualCollectionsTotal = await _repository
          .getAdminManualCollectionsTotal();
    } catch (e) {
      _adminManualCollectionsTotal = null; // Unavailable
      _collectionsTotalError = e.toString();
    } finally {
      _isLoadingCollectionsTotal = false;
      notifyListeners();
    }
  }

  Future<String> uploadLectureVideo({
    required String batchId,
    required String fileName,
    Uint8List? fileBytes,
    String? filePath,
    void Function(int uploadedBytes, int totalBytes)? onProgress,
    bool Function()? isCancelled,
  }) async {
    try {
      return await _repository.uploadLectureVideo(
        batchId: batchId,
        fileName: fileName,
        fileBytes: fileBytes,
        filePath: filePath,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<List<VideoLessonModel>> getLessonsForBatches(List<String> batchIds) async {
    return await _repository.getLessonsForBatches(batchIds);
  }

  Future<VideoLessonModel?> startBackgroundLectureUpload({
    required String batchId,
    required String batchName,
    required String courseId,
    required String title,
    required String chapter,
    required String fileName,
    String? filePath,
    Uint8List? fileBytes,
    String? thumbnailName,
    Uint8List? thumbnailBytes,
    String? thumbnailUrl,
    required int totalBytes,
  }) async {
    final task = LectureUploadTask(
      batchId: batchId,
      batchName: batchName,
      courseId: courseId,
      title: title,
      chapter: chapter,
      fileName: fileName,
      filePath: filePath,
      fileBytes: fileBytes,
      thumbnailName: thumbnailName,
      thumbnailBytes: thumbnailBytes,
      thumbnailUrl: thumbnailUrl,
      totalBytes: totalBytes,
    );
    _activeUploadTask = task;
    notifyListeners();

    try {
      final storagePath = await uploadLectureVideo(
        batchId: batchId,
        fileName: fileName,
        fileBytes: fileBytes,
        filePath: filePath,
        onProgress: (upBytes, totBytes) {
          if (task.isCancelled) return;
          task.uploadedBytes = upBytes;
          task.progress = totBytes > 0 ? (upBytes / totBytes).clamp(0.0, 1.0) : 0.0;
          notifyListeners();
        },
        isCancelled: () => task.isCancelled,
      );

      if (task.isCancelled) {
        task.status = LectureUploadStatus.cancelled;
        notifyListeners();
        return null;
      }

      String? finalThumbnailPath;
      if (thumbnailBytes != null && thumbnailName != null) {
        try {
          finalThumbnailPath = await uploadLessonThumbnail(
            batchId: batchId,
            fileName: thumbnailName,
            fileBytes: thumbnailBytes,
          );
        } catch (e) {
          debugPrint('Warning: thumbnail upload failed: $e');
        }
      } else if (thumbnailUrl != null && thumbnailUrl.trim().isNotEmpty) {
        finalThumbnailPath = thumbnailUrl.trim();
      } else if (storagePath.contains('cloudflarestream.com') ||
          storagePath.contains('videodelivery.net')) {
        final uidMatch = RegExp(r'([a-f0-9]{32})').firstMatch(storagePath);
        if (uidMatch != null) {
          finalThumbnailPath =
              'https://videodelivery.net/${uidMatch.group(1)}/thumbnails/thumbnail.jpg';
        }
      }

      if (task.isCancelled) {
        task.status = LectureUploadStatus.cancelled;
        notifyListeners();
        return null;
      }

      task.status = LectureUploadStatus.inserting;
      task.progress = 1.0;
      notifyListeners();

      final lesson = await createLesson(
        courseId: courseId,
        batchId: batchId,
        title: title,
        chapter: chapter,
        videoUrl: storagePath,
        thumbnailUrl: finalThumbnailPath,
        durationSeconds: 0,
      );

      task.createdLesson = lesson;
      task.status = LectureUploadStatus.success;
      notifyListeners();
      return lesson;
    } catch (e) {
      if (task.isCancelled) {
        task.status = LectureUploadStatus.cancelled;
        task.error = 'Upload cancelled by user.';
      } else {
        task.status = LectureUploadStatus.failure;
        String displayMsg = e.toString().replaceAll('Exception:', '').replaceAll('ServerException:', '').trim();
        if (displayMsg.contains('Storage capacity exceeded') ||
            displayMsg.contains('allocated storage quota') ||
            displayMsg.contains('10011') ||
            displayMsg.contains('quota exceeded') ||
            displayMsg.contains('1,000-minute')) {
          displayMsg =
              "Cloudflare Stream storage limit exceeded: You have uploaded 1,200+ minutes, exceeding your 1,000-minute allocation. Please delete older or test videos in your Cloudflare Dashboard (Stream > Videos) or upgrade your minutes to continue uploading.";
        } else if (displayMsg.contains('NoSuchBucket') ||
            displayMsg.contains('Bucket not found') ||
            displayMsg.contains('404')) {
          displayMsg =
              "Storage bucket 'lecture-videos' is not yet provisioned on the Supabase backend. Please review and apply the required Storage migration.";
        }
        task.error = displayMsg;
      }
      notifyListeners();
      return null;
    }
  }

  Future<String> uploadCourseCoverImage({
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    return await _repository.uploadCourseCoverImage(
      fileName: fileName,
      fileBytes: fileBytes,
    );
  }

  Future<String> uploadLessonThumbnail({
    required String batchId,
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    return await _repository.uploadLessonThumbnail(
      batchId: batchId,
      fileName: fileName,
      fileBytes: fileBytes,
    );
  }

  Future<VideoLessonModel> updateLessonThumbnail({
    required String lessonId,
    required String thumbnailUrl,
  }) async {
    try {
      final updated = await _repository.updateLessonThumbnail(
        lessonId: lessonId,
        thumbnailUrl: thumbnailUrl,
      );
      final idx = _videoLessons.indexWhere((l) => l.id == lessonId);
      if (idx != -1) {
        _videoLessons[idx] = updated;
      }
      notifyListeners();
      return updated;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<VideoLessonModel> updateLesson({
    required String lessonId,
    String? title,
    String? chapter,
    String? thumbnailUrl,
    String? notesPdfUrl,
  }) async {
    try {
      final updated = await _repository.updateLesson(
        lessonId: lessonId,
        title: title,
        chapter: chapter,
        thumbnailUrl: thumbnailUrl,
        notesPdfUrl: notesPdfUrl,
      );
      final idx = _videoLessons.indexWhere((l) => l.id == lessonId);
      if (idx != -1) {
        _videoLessons[idx] = updated;
      }
      notifyListeners();
      return updated;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<VideoLessonModel> createLesson({
    required String courseId,
    required String batchId,
    required String title,
    required String chapter,
    required String videoUrl,
    String? thumbnailUrl,
    int durationSeconds = 0,
    int? orderIndex,
  }) async {
    try {
      final lesson = await _repository.createLesson(
        courseId: courseId,
        batchId: batchId,
        title: title,
        chapter: chapter,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        durationSeconds: durationSeconds,
        orderIndex: orderIndex,
      );
      _videoLessons.add(lesson);
      notifyListeners();
      return lesson;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<VideoLessonModel> uploadAndCreateLesson({
    required String courseId,
    required String batchId,
    required String title,
    required String chapter,
    required String fileName,
    required Uint8List fileBytes,
    Uint8List? thumbnailBytes,
    String? thumbnailFileName,
    int durationSeconds = 0,
    int? orderIndex,
  }) async {
    final storagePath = await _repository.uploadLectureVideo(
      batchId: batchId,
      fileName: fileName,
      fileBytes: fileBytes,
    );

    String? thumbnailPath;
    if (thumbnailBytes != null && thumbnailFileName != null) {
      try {
        thumbnailPath = await _repository.uploadLessonThumbnail(
          batchId: batchId,
          fileName: thumbnailFileName,
          fileBytes: thumbnailBytes,
        );
      } catch (e) {
        debugPrint('Warning: thumbnail upload failed: $e');
        rethrow;
      }
    }

    final lesson = await _repository.createLesson(
      courseId: courseId,
      batchId: batchId,
      title: title,
      chapter: chapter,
      videoUrl: storagePath,
      thumbnailUrl: thumbnailPath,
      durationSeconds: durationSeconds,
      orderIndex: orderIndex,
    );

    _videoLessons.add(lesson);
    notifyListeners();
    return lesson;
  }

  Future<String> getLessonSignedUrl(String videoUrlOrPath) async {
    return await _repository.getLessonVideoSignedUrl(videoUrlOrPath);
  }

  Future<void> deleteCourse(String courseId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.deleteCourse(courseId);
      _courses.removeWhere((c) => c.id == courseId);
      _batches.removeWhere((b) => b.courseId == courseId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteLesson(
    String lessonId, {
    String? videoPath,
    String? thumbnailPath,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.deleteLesson(
        lessonId,
        videoPath: videoPath,
        thumbnailPath: thumbnailPath,
      );
      _videoLessons.removeWhere((l) => l.id == lessonId);
      _recentPlaybacks.removeWhere((p) => p.lectureId == lessonId);
      _persistRecentPlaybacks();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Removes a deleted or invalid lecture from recent playbacks cache
  void removeRecentPlayback(String lectureId) {
    _recentPlaybacks.removeWhere((p) => p.lectureId == lectureId);
    _persistRecentPlaybacks();
    notifyListeners();
  }
}
