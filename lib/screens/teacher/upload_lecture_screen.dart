import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';

import 'package:image_picker/image_picker.dart';

import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';

import '../../core/constants/app_colors.dart';

import '../../core/theme/app_typography.dart';

import '../../core/widgets/modern_button.dart';

import '../../core/widgets/modern_card.dart';

import '../../features/courses/data/models/batch_model.dart';

import '../../features/courses/data/models/course_model.dart';

import '../../providers/auth_provider.dart';

import '../../providers/course_provider.dart';



enum UploadStatus { idle, uploading, inserting, success, failure }



class UploadLectureScreen extends StatefulWidget {

  final String? initialBatchId;

  const UploadLectureScreen({super.key, this.initialBatchId});



  @override

  State<UploadLectureScreen> createState() => _UploadLectureScreenState();

}



class _UploadLectureScreenState extends State<UploadLectureScreen> {

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();

  final TextEditingController _chapterController = TextEditingController();

  final TextEditingController _filePathController = TextEditingController();

  final TextEditingController _thumbnailUrlController = TextEditingController();



  String? _selectedBatchId;

  String? _fileName;

  Uint8List? _fileBytes;

  String? _videoFilePath;

  Uint8List? _thumbnailBytes;

  String? _thumbnailName;

  int _fileSizeBytes = 0;

  String? _fileLoadError;

  bool _showThumbnailUrlField = false;



  UploadStatus _status = UploadStatus.idle;

  double _uploadProgress = 0.0;

  int _uploadedBytes = 0;

  int _uploadTotalBytes = 0;

  String? _uploadError;

  VideoLessonModel? _createdLesson;



  @override

  void initState() {

    super.initState();

    if (widget.initialBatchId != null) {

      _selectedBatchId = widget.initialBatchId;

    }

    // Clean up temporary files from previous picks to avoid cache storage exhaustion

    FilePicker.clearTemporaryFiles().catchError((_) {});

    WidgetsBinding.instance.addPostFrameCallback((_) {

      if (mounted) {

        final cp = context.read<CourseProvider>();

        if (cp.batches.isEmpty) {

          cp.fetchCatalog();

        }

      }

    });

    _checkLostData();

  }



  @override

  void dispose() {

    _titleController.dispose();

    _chapterController.dispose();

    _filePathController.dispose();

    _thumbnailUrlController.dispose();

    super.dispose();

  }



  Future<void> _pickThumbnail() async {

    try {

      final picker = ImagePicker();

      final XFile? image = await picker.pickImage(

        source: ImageSource.gallery,

        maxWidth: 1280,

        maxHeight: 720,

        imageQuality: 85,

      );

      if (image == null) return;



      final bytes = await image.readAsBytes();

      if (bytes.length > 5 * 1024 * 1024) {

        setState(() {

          _fileLoadError = "Thumbnail image must be smaller than 5 MB.";

        });

        return;

      }

      setState(() {

        _thumbnailBytes = bytes;

        _thumbnailName = image.name;

        _fileLoadError = null;

      });

    } catch (e) {

      setState(() {

        _fileLoadError = "Could not select thumbnail: $e";

      });

    }

  }



  void _useSampleVideo() {

    final sampleBytes = Uint8List.fromList(

      List<int>.generate(10240, (i) => (i * 31) % 256),

    );

    setState(() {

      _fileName = "sample_lecture_${DateTime.now().millisecondsSinceEpoch}.mp4";

      _fileBytes = sampleBytes;

      _videoFilePath = null;

      _fileSizeBytes = sampleBytes.length;

      _filePathController.text = "[In-Memory Test Sample]";

      _fileLoadError = null;

    });

  }



  Future<void> _checkLostData() async {

    try {

      final picker = ImagePicker();

      final LostDataResponse response = await picker.retrieveLostData();

      if (response.isEmpty) return;

      if (response.file != null && response.type == RetrieveType.image) {

        final bytes = await response.file!.readAsBytes();

        setState(() {

          _thumbnailBytes = bytes;

          _thumbnailName = response.file!.name;

        });

      }

    } catch (e) {

      debugPrint("Error recovering lost image data: $e");

    }

  }



  Future<void> _pickFromGallery() async {

    setState(() {

      _fileLoadError = null;

    });

    try {

      // Purge any stale temporary files from previous picks to avoid cache storage exhaustion

      try {

        await FilePicker.clearTemporaryFiles();

      } catch (_) {}



      PlatformFile? pickedFile;

      try {

        pickedFile = await FilePicker.pickFile(type: FileType.video);

      } catch (pickerErr) {

        debugPrint("FilePicker video type error: $pickerErr. Trying custom video extension filter...");

        pickedFile = await FilePicker.pickFile(

          type: FileType.custom,

          allowedExtensions: ['mp4', 'mkv', 'mov', 'webm'],

        );

      }



      if (pickedFile == null) return; // User cancelled



      final len = await pickedFile.length();

      final path = pickedFile.path ?? pickedFile.name;

      _processSelectedVideo(pickedFile.name, path, len ?? 0);

    } catch (e) {

      debugPrint("Video gallery selection error: $e");

      final msg = e.toString().toLowerCase();

      String userMsg = "Could not select video: $e";

      if (msg.contains('permission') || msg.contains('denied')) {

        userMsg = "Storage/Media permission is required to select lecture videos. Please enable permissions in App Settings.";

      } else if (msg.contains('memory') || msg.contains('size') || msg.contains('large')) {

        userMsg = "The selected video could not be loaded due to low system memory or storage. Please ensure your device has sufficient free storage space and retry.";

      }

      setState(() {

        _fileLoadError = userMsg;

      });

    }

  }



  Future<void> _pickFromFiles() async {

    setState(() {

      _fileLoadError = null;

    });

    try {

      // Clear temporary cache before picking

      try {

        await FilePicker.clearTemporaryFiles();

      } catch (_) {}



      PlatformFile? pickedFile;

      try {

        pickedFile = await FilePicker.pickFile(

          type: FileType.custom,

          allowedExtensions: ['mp4', 'mkv', 'mov', 'webm'],

        );

      } catch (_) {

        pickedFile = await FilePicker.pickFile(type: FileType.video);

      }

      if (pickedFile == null) return; // User cancelled



      final len = await pickedFile.length();

      final path = pickedFile.path ?? pickedFile.name;

      _processSelectedVideo(pickedFile.name, path, len ?? 0);

    } catch (e) {

      debugPrint("Video file selection error: $e");

      final msg = e.toString().toLowerCase();

      String userMsg = "Could not select video file: $e";

      if (msg.contains('permission') || msg.contains('denied')) {

        userMsg = "Storage permission is required to select files. Please enable permissions in App Settings.";

      } else if (msg.contains('memory') || msg.contains('size') || msg.contains('large')) {

        userMsg = "The selected video could not be loaded due to low storage or memory. Please free up some device storage and retry.";

      }

      setState(() {

        _fileLoadError = userMsg;

      });

    }

  }



  void _processSelectedVideo(String name, String sourcePath, int sizeBytes, {Uint8List? bytes}) {

    final ext = name.split('.').last.toLowerCase();

    const validExtensions = ['mp4', 'mkv', 'mov', 'webm'];

    if (!validExtensions.contains(ext)) {

      setState(() {

        _fileLoadError = "Unsupported video format (.$ext). Supported: mp4, mkv, mov, webm.";

      });

      return;

    }



    setState(() {

      _fileName = name;

      _videoFilePath = sourcePath.startsWith('[In-Memory') ? null : sourcePath;

      _fileBytes = bytes;

      _fileSizeBytes = sizeBytes;

      _filePathController.text = sourcePath;

      _fileLoadError = null;

    });

  }



  Future<void> _startUpload() async {

    if (!_formKey.currentState!.validate()) return;



    if ((_videoFilePath == null && _fileBytes == null) || _fileName == null) {

      setState(() {

        _fileLoadError = "Please select or load a video file first.";

      });

      return;

    }



    final courseProvider = context.read<CourseProvider>();

    final batches = courseProvider.batches;

    final selectedBatch = batches.firstWhere(

      (b) => b.id == _selectedBatchId,

      orElse: () => batches.first,

    );



    setState(() {

      _status = UploadStatus.uploading;

      _uploadProgress = 0.0;

      _uploadedBytes = 0;

      _uploadTotalBytes = _fileSizeBytes;

      _uploadError = null;

    });



    try {

      final lesson = await courseProvider.startBackgroundLectureUpload(

        batchId: selectedBatch.id,

        batchName: selectedBatch.name,

        courseId: selectedBatch.courseId,

        title: _titleController.text.trim(),

        chapter: _chapterController.text.trim(),

        fileName: _fileName!,

        filePath: _videoFilePath,

        fileBytes: _fileBytes,

        thumbnailName: _thumbnailName,

        thumbnailBytes: _thumbnailBytes,

        thumbnailUrl: _thumbnailUrlController.text.trim(),

        totalBytes: _fileSizeBytes,

      );



      if (!mounted) return;



      final task = courseProvider.activeUploadTask;

      if (task != null && task.status == LectureUploadStatus.success && lesson != null) {

        try {

          FilePicker.clearTemporaryFiles();

        } catch (_) {}

        setState(() {

          _status = UploadStatus.success;

          _uploadProgress = 1.0;

          _createdLesson = lesson;

        });

      } else if (task != null && task.status == LectureUploadStatus.failure) {

        String displayMsg = task.error ?? "An unexpected error occurred during upload.";

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

        setState(() {

          _status = UploadStatus.failure;

          _uploadError = displayMsg;

        });

      } else if (task != null && task.status == LectureUploadStatus.cancelled) {

        setState(() {

          _status = UploadStatus.idle;

          _uploadError = null;

        });

      }

    } catch (e) {

      if (!mounted) return;

      String displayMsg = e.toString();

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

      setState(() {

        _status = UploadStatus.failure;

        _uploadError = displayMsg;

      });

    }

  }



  void _cancelUpload() {

    context.read<CourseProvider>().cancelLectureUpload();

    try {

      FilePicker.clearTemporaryFiles();

    } catch (_) {}

    setState(() {

      _status = UploadStatus.idle;

      _uploadProgress = 0.0;

      _uploadedBytes = 0;

      _uploadError = null;

    });

  }



  void _resetForm() {

    try {

      context.read<CourseProvider>().clearActiveUpload();

    } catch (_) {}

    try {

      FilePicker.clearTemporaryFiles();

    } catch (_) {}

    setState(() {

      _titleController.clear();

      _chapterController.clear();

      _filePathController.clear();

      _thumbnailUrlController.clear();

      _fileName = null;

      _fileBytes = null;

      _videoFilePath = null;

      _fileSizeBytes = 0;

      _fileLoadError = null;

      _status = UploadStatus.idle;

      _uploadProgress = 0.0;

      _uploadedBytes = 0;

      _uploadTotalBytes = 0;

      _uploadError = null;

      _createdLesson = null;

    });

  }



  @override

  Widget build(BuildContext context) {

    final courseProvider = context.watch<CourseProvider>();

    final auth = context.watch<AuthProvider>();

    final user = auth.currentUser;



    // Filter to teacher's assigned batches

    final myBatches = user.role.name == 'teacher'

        ? courseProvider.batches

              .where((b) => courseProvider.myAssignedBatchIds.contains(b.id))

              .toList()

        : courseProvider.batches;



    // Default select first batch if none selected or if previous selection is invalid

    if (_selectedBatchId != null &&

        !myBatches.any((b) => b.id == _selectedBatchId)) {

      _selectedBatchId = myBatches.isNotEmpty ? myBatches.first.id : null;

    } else if (_selectedBatchId == null && myBatches.isNotEmpty) {

      _selectedBatchId = myBatches.first.id;

    }



    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeTask = courseProvider.activeUploadTask;

    final isGlobalUploading = courseProvider.isUploadingLecture;

    final effectiveStatus = (activeTask != null && isGlobalUploading)

        ? (activeTask.status == LectureUploadStatus.inserting ? UploadStatus.inserting : UploadStatus.uploading)

        : (activeTask != null && activeTask.status == LectureUploadStatus.success)

            ? UploadStatus.success

            : (activeTask != null && activeTask.status == LectureUploadStatus.failure)

                ? UploadStatus.failure

                : _status;



    return PopScope(

      canPop: !isGlobalUploading && _status != UploadStatus.uploading && _status != UploadStatus.inserting,

      onPopInvokedWithResult: (didPop, result) async {

        if (didPop) return;

        final shouldLeave = await showDialog<bool>(

          context: context,

          builder: (ctx) => AlertDialog(

            backgroundColor: isDark ? AppColors.darkSurfaceCard : Colors.white,

            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

            title: const Row(

              children: [

                Icon(Icons.cloud_sync, color: AppColors.saffronDark),

                SizedBox(width: 8),

                Text("Upload in Progress", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),

              ],

            ),

            content: const Text(

              "Your video upload will continue running in the background. You can return to view progress or cancel it at any time from the Faculty Dashboard.",

              style: TextStyle(fontSize: 13),

            ),

            actions: [

              TextButton(

                onPressed: () => Navigator.pop(ctx, false),

                child: const Text("Stay on Page"),

              ),

              ElevatedButton(

                style: ElevatedButton.styleFrom(

                  backgroundColor: AppColors.deepInk,

                  foregroundColor: Colors.white,

                ),

                onPressed: () => Navigator.pop(ctx, true),

                child: const Text("Run in Background"),

              ),

            ],

          ),

        );

        if (shouldLeave == true && mounted) {

          if (!context.mounted) return;

          Navigator.of(context).pop();

        }

      },

      child: Scaffold(

      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(

        title: const Text("Upload Lecture Video"),

        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,

        elevation: 0,

        bottom: PreferredSize(

          preferredSize: const Size.fromHeight(1),

          child: Container(color: isDark ? AppColors.darkBorder : AppColors.border, height: 1),

        ),

      ),

      body: SingleChildScrollView(

        padding: const EdgeInsets.all(16),

        child: Form(

          key: _formKey,

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              // Header Card

              ModernCard(

                padding: const EdgeInsets.all(16),

                backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,

                accentSpineColor: AppColors.saffron,

                child: Row(

                  children: [

                    Container(

                      padding: const EdgeInsets.all(12),

                      decoration: BoxDecoration(

                        color: isDark ? AppColors.primary.withValues(alpha: 0.18) : AppColors.saffronMuted,

                        borderRadius: const BorderRadius.all(Radius.circular(8)),

                      ),

                      child: const Icon(

                        Icons.video_library_outlined,

                        color: AppColors.saffronDark,

                        size: 28,

                      ),

                    ),

                    const SizedBox(width: 14),

                    Expanded(

                      child: Column(

                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [

                          Text(

                            "Prerecorded Lecture Upload",

                            style: AppTypography.titleMedium.copyWith(

                              fontWeight: FontWeight.w700,

                              color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,

                            ),

                          ),

                          const SizedBox(height: 4),

                          Text(

                            "⚡ Cloudflare Stream Engine: Videos are transcoded into adaptive HLS (360p-1080p) with zero bandwidth limits.",

                            style: AppTypography.caption.copyWith(

                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,

                            ),

                          ),

                        ],

                      ),

                    ),

                  ],

                ),

              ),

              const SizedBox(height: 16),



              if (effectiveStatus == UploadStatus.success) ...[

                _buildSuccessView(activeTask),

              ] else if (effectiveStatus == UploadStatus.failure) ...[

                _buildFailureView(activeTask),

                const SizedBox(height: 16),

                _buildFormFields(myBatches),

              ] else if (effectiveStatus == UploadStatus.uploading ||

                  effectiveStatus == UploadStatus.inserting) ...[

                _buildProgressView(activeTask),

              ] else ...[

                _buildFormFields(myBatches),

              ],

            ],

          ),

        ),

      ),

    ));

  }



  Widget _buildFormFields(List<BatchModel> myBatches) {

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(

      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        // Batch Selection

        const Text(

          "Select Target Batch *",

          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),

        ),

        const SizedBox(height: 8),

        if (myBatches.isEmpty)

          Container(

            padding: const EdgeInsets.all(12),

            decoration: BoxDecoration(

              color: AppColors.amberBg,

              borderRadius: BorderRadius.circular(8),

              border: Border.all(color: AppColors.amberBorder),

            ),

            child: const Row(

              children: [

                Icon(

                  Icons.warning_amber_rounded,

                  color: AppColors.amber,

                  size: 20,

                ),

                SizedBox(width: 8),

                Expanded(

                  child: Text(

                    "You have no assigned batches. Please contact an admin to assign you to a batch.",

                    style: TextStyle(fontSize: 12, color: AppColors.amber),

                  ),

                ),

              ],

            ),

          )

        else

          DropdownButtonFormField<String>(

            isExpanded: true,

            initialValue: _selectedBatchId,

            dropdownColor: Theme.of(context).brightness == Brightness.dark

                ? AppColors.darkSurface

                : AppColors.surface,

            decoration: InputDecoration(

              filled: true,

              fillColor: Theme.of(context).brightness == Brightness.dark

                  ? AppColors.darkSurface

                  : AppColors.surface,

              border: OutlineInputBorder(

                borderRadius: BorderRadius.circular(8),

                borderSide: BorderSide(

                  color: Theme.of(context).brightness == Brightness.dark

                      ? AppColors.darkBorder

                      : AppColors.border,

                ),

              ),

              enabledBorder: OutlineInputBorder(

                borderRadius: BorderRadius.circular(8),

                borderSide: BorderSide(

                  color: Theme.of(context).brightness == Brightness.dark

                      ? AppColors.darkBorder

                      : AppColors.border,

                ),

              ),

              contentPadding: const EdgeInsets.symmetric(

                horizontal: 14,

                vertical: 12,

              ),

            ),

            items: myBatches.map((b) {

              return DropdownMenuItem(

                value: b.id,

                child: Text(

                  "${b.name} (${b.timing})",

                  overflow: TextOverflow.ellipsis,

                  maxLines: 1,

                  style: AppTypography.bodyMedium.copyWith(

                    color: Theme.of(context).brightness == Brightness.dark

                        ? AppColors.darkTextPrimary

                        : AppColors.deepInk,

                  ),

                ),

              );

            }).toList(),

            onChanged: (val) {

              setState(() {

                _selectedBatchId = val;

              });

            },

            validator: (v) => v == null ? "Please select a batch" : null,

          ),

        const SizedBox(height: 16),



        // Title

        const Text(

          "Lecture Title *",

          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),

        ),

        const SizedBox(height: 8),

        TextFormField(

          key: const Key('lecture_title_field'),

          controller: _titleController,

          decoration: InputDecoration(

            hintText: "e.g., Ancient History - Magadh Empire Overview",

            filled: true,

            fillColor: isDark ? AppColors.darkSurface : AppColors.surface,

            border: OutlineInputBorder(

              borderRadius: BorderRadius.circular(8),

              borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),

            ),

            enabledBorder: OutlineInputBorder(

              borderRadius: BorderRadius.circular(8),

              borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),

            ),

          ),

          validator: (v) =>

              (v == null || v.trim().isEmpty) ? "Title is required" : null,

        ),

        const SizedBox(height: 16),



        // Chapter

        const Text(

          "Chapter / Topic *",

          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),

        ),

        const SizedBox(height: 8),

        TextFormField(

          key: const Key('lecture_chapter_field'),

          controller: _chapterController,

          decoration: InputDecoration(

            hintText: "e.g., Indian History",

            filled: true,

            fillColor: isDark ? AppColors.darkSurface : AppColors.surface,

            border: OutlineInputBorder(

              borderRadius: BorderRadius.circular(8),

              borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),

            ),

            enabledBorder: OutlineInputBorder(

              borderRadius: BorderRadius.circular(8),

              borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),

            ),

          ),

          validator: (v) =>

              (v == null || v.trim().isEmpty) ? "Chapter is required" : null,

        ),

        const SizedBox(height: 20),



        // Video File Selection Section

        const Text(

          "Video Source *",

          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),

        ),

        const SizedBox(height: 8),

        ModernCard(

          padding: const EdgeInsets.all(16),

          backgroundColor: Theme.of(context).brightness == Brightness.dark

              ? AppColors.darkSurface

              : AppColors.surface,

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              if (_fileName == null || (_fileBytes == null && _videoFilePath == null)) ...[

                Row(

                  children: [

                    Expanded(

                      child: InkWell(

                        onTap: _pickFromGallery,

                        borderRadius: BorderRadius.circular(8),

                        child: Container(

                          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),

                          decoration: BoxDecoration(

                            border: Border.all(

                              color: Theme.of(context).brightness == Brightness.dark

                                  ? AppColors.darkBorder

                                  : AppColors.border,

                            ),

                            borderRadius: BorderRadius.circular(8),

                            color: Theme.of(context).brightness == Brightness.dark

                                ? AppColors.darkSurfaceCard

                                : AppColors.warmIvory,

                          ),

                          child: Column(

                            children: [

                              const Icon(

                                Icons.photo_library_outlined,

                                color: AppColors.saffronDark,

                                size: 28,

                              ),

                              const SizedBox(height: 8),

                              Text(

                                "Select from Gallery",

                                textAlign: TextAlign.center,

                                style: AppTypography.titleSmall.copyWith(

                                  fontWeight: FontWeight.w600,

                                  fontSize: 13,

                                ),

                              ),

                              const SizedBox(height: 2),

                              Text(

                                "Camera & Photos",

                                style: AppTypography.caption.copyWith(

                                  color: AppColors.textMuted,

                                  fontSize: 11,

                                ),

                              ),

                            ],

                          ),

                        ),

                      ),

                    ),

                    const SizedBox(width: 12),

                    Expanded(

                      child: InkWell(

                        onTap: _pickFromFiles,

                        borderRadius: BorderRadius.circular(8),

                        child: Container(

                          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),

                          decoration: BoxDecoration(

                            border: Border.all(

                              color: Theme.of(context).brightness == Brightness.dark

                                  ? AppColors.darkBorder

                                  : AppColors.border,

                            ),

                            borderRadius: BorderRadius.circular(8),

                            color: Theme.of(context).brightness == Brightness.dark

                                ? AppColors.darkSurfaceCard

                                : AppColors.warmIvory,

                          ),

                          child: Column(

                            children: [

                              const Icon(

                                Icons.folder_open_outlined,

                                color: AppColors.secondary,

                                size: 28,

                              ),

                              const SizedBox(height: 8),

                              Text(

                                "Select from Files",

                                textAlign: TextAlign.center,

                                style: AppTypography.titleSmall.copyWith(

                                  fontWeight: FontWeight.w600,

                                  fontSize: 13,

                                ),

                              ),

                              const SizedBox(height: 2),

                              Text(

                                "MP4, MKV, MOV, WEBM",

                                style: AppTypography.caption.copyWith(

                                  color: AppColors.textMuted,

                                  fontSize: 11,

                                ),

                              ),

                            ],

                          ),

                        ),

                      ),

                    ),

                  ],

                ),

                const SizedBox(height: 12),

                if (AppConfig.isTestMode)

                  Wrap(

                    crossAxisAlignment: WrapCrossAlignment.center,

                    spacing: 8,

                    runSpacing: 4,

                    children: [

                      const Text(

                        "or for quick testing:",

                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),

                      ),

                      TextButton.icon(

                        onPressed: _useSampleVideo,

                        icon: const Icon(

                          Icons.science_outlined,

                          size: 16,

                          color: AppColors.saffronDark,

                        ),

                        label: const Text(

                          "Use Test Sample (10KB MP4)",

                          style: TextStyle(

                            fontSize: 12,

                            color: AppColors.saffronDark,

                            fontWeight: FontWeight.bold,

                          ),

                        ),

                      ),

                    ],

                  ),

              ] else ...[

                Container(

                  padding: const EdgeInsets.all(12),

                  decoration: BoxDecoration(

                    color: AppColors.emeraldBg,

                    border: Border.all(color: AppColors.emeraldBorder),

                    borderRadius: BorderRadius.circular(8),

                  ),

                  child: Row(

                    children: [

                      Container(

                        padding: const EdgeInsets.all(8),

                        decoration: BoxDecoration(

                          color: AppColors.emerald,

                          borderRadius: BorderRadius.circular(6),

                        ),

                        child: const Icon(

                          Icons.videocam_rounded,

                          color: Colors.white,

                          size: 22,

                        ),

                      ),

                      const SizedBox(width: 12),

                      Expanded(

                        child: Column(

                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [

                            Text(

                              _fileName!,

                              style: AppTypography.titleSmall.copyWith(

                                fontWeight: FontWeight.bold,

                                fontSize: 13,

                              ),

                              maxLines: 1,

                              overflow: TextOverflow.ellipsis,

                            ),

                            const SizedBox(height: 2),

                            Text(

                              _fileSizeBytes >= 1024 * 1024 * 1024

                                  ? "Size: ${(_fileSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB (${(_fileSizeBytes / (1024 * 1024)).toStringAsFixed(0)} MB)"

                                  : "Size: ${(_fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB (${(_fileSizeBytes / 1024).toStringAsFixed(1)} KB)",

                              style: AppTypography.caption.copyWith(

                                color: AppColors.emerald,

                                fontWeight: FontWeight.w600,

                              ),

                            ),

                          ],

                        ),

                      ),

                      IconButton(

                        tooltip: "Remove / Reselect",

                        icon: const Icon(Icons.close, size: 20, color: AppColors.deepInk),

                        onPressed: () {

                          setState(() {

                            _fileName = null;

                            _fileBytes = null;

                            _fileSizeBytes = 0;

                            _filePathController.clear();

                          });

                        },

                      ),

                    ],

                  ),

                ),

                const SizedBox(height: 8),

                Row(

                  mainAxisAlignment: MainAxisAlignment.end,

                  children: [

                    TextButton.icon(

                      onPressed: _pickFromGallery,

                      icon: const Icon(Icons.photo_library_outlined, size: 16),

                      label: const Text("Gallery", style: TextStyle(fontSize: 12)),

                    ),

                    const SizedBox(width: 8),

                    TextButton.icon(

                      onPressed: _pickFromFiles,

                      icon: const Icon(Icons.folder_open_outlined, size: 16),

                      label: const Text("Files", style: TextStyle(fontSize: 12)),

                    ),

                  ],

                ),

              ],

              if (_fileLoadError != null) ...[

                const SizedBox(height: 10),

                Container(

                  padding: const EdgeInsets.all(10),

                  decoration: BoxDecoration(

                    color: AppColors.errorBg,

                    border: Border.all(color: AppColors.errorBorder),

                    borderRadius: BorderRadius.circular(6),

                  ),

                  child: Row(

                    children: [

                      const Icon(Icons.error_outline, color: AppColors.error, size: 16),

                      const SizedBox(width: 8),

                      Expanded(

                        child: Text(

                          _fileLoadError!,

                          style: const TextStyle(color: AppColors.error, fontSize: 12),

                        ),

                      ),

                    ],

                  ),

                ),

              ],

            ],

          ),

        ),

        const SizedBox(height: 16),



        // Lecture Thumbnail Section (Optional)

        ModernCard(

          padding: const EdgeInsets.all(16),

          backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,

          borderColor: isDark ? AppColors.darkBorder : AppColors.border,

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Row(

                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [

                  Expanded(

                    child: Text(

                      "Lecture Thumbnail (Optional)",

                      style: AppTypography.titleSmall.copyWith(

                        fontWeight: FontWeight.w600,

                        fontSize: 13,

                        color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,

                      ),

                      overflow: TextOverflow.ellipsis,

                    ),

                  ),

                  const SizedBox(width: 8),

                  Text(

                    "Max 5 MB",

                    style: AppTypography.caption.copyWith(

                      color: AppColors.textMuted,

                      fontSize: 11,

                    ),

                  ),

                ],

              ),

              const SizedBox(height: 10),

              if (_thumbnailBytes != null)

                Container(

                  padding: const EdgeInsets.all(10),

                  decoration: BoxDecoration(

                    borderRadius: BorderRadius.circular(8),

                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),

                    color: isDark ? AppColors.darkSurface : AppColors.surfaceSubtle,

                  ),

                  child: Row(

                    children: [

                      ClipRRect(

                        borderRadius: BorderRadius.circular(6),

                        child: Image.memory(

                          _thumbnailBytes!,

                          width: 60,

                          height: 45,

                          fit: BoxFit.cover,

                        ),

                      ),

                      const SizedBox(width: 12),

                      Expanded(

                        child: Column(

                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [

                            Text(

                              _thumbnailName ?? "Thumbnail selected",

                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),

                              maxLines: 1,

                              overflow: TextOverflow.ellipsis,

                            ),

                            Text(

                              "${(_thumbnailBytes!.length / 1024).toStringAsFixed(1)} KB",

                              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),

                            ),

                          ],

                        ),

                      ),

                      TextButton(

                        onPressed: _pickThumbnail,

                        child: const Text("Change", style: TextStyle(fontSize: 12)),

                      ),

                      IconButton(

                        icon: const Icon(Icons.close, size: 18),

                        tooltip: "Remove thumbnail",

                        onPressed: () {

                          setState(() {

                            _thumbnailBytes = null;

                            _thumbnailName = null;

                          });

                        },

                      ),

                    ],

                  ),

                )

              else if (_thumbnailUrlController.text.trim().isNotEmpty)

                Container(

                  padding: const EdgeInsets.all(10),

                  decoration: BoxDecoration(

                    borderRadius: BorderRadius.circular(8),

                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),

                    color: isDark ? AppColors.darkSurface : AppColors.surfaceSubtle,

                  ),

                  child: Row(

                    children: [

                      ClipRRect(

                        borderRadius: BorderRadius.circular(6),

                        child: Image.network(

                          _thumbnailUrlController.text.trim(),

                          width: 60,

                          height: 45,

                          fit: BoxFit.cover,

                          errorBuilder: (_, _, _) => Container(

                            width: 60,

                            height: 45,

                            color: isDark ? AppColors.darkSurface : AppColors.surfaceSubtle,

                            child: const Icon(Icons.broken_image_outlined, size: 20),

                          ),

                        ),

                      ),

                      const SizedBox(width: 12),

                      Expanded(

                        child: Column(

                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [

                            Text(

                              _thumbnailUrlController.text.trim().split('/').last.split('?').first,

                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),

                              maxLines: 1,

                              overflow: TextOverflow.ellipsis,

                            ),

                            const Text(

                              "URL Thumbnail linked",

                              style: TextStyle(fontSize: 10, color: AppColors.textMuted),

                            ),

                          ],

                        ),

                      ),

                      IconButton(

                        icon: const Icon(Icons.close, size: 18),

                        tooltip: "Remove thumbnail",

                        onPressed: () {

                          setState(() {

                            _thumbnailUrlController.clear();

                          });

                        },

                      ),

                    ],

                  ),

                )

              else

                SizedBox(

                  width: double.infinity,

                  child: OutlinedButton(

                    key: const Key('pick_thumbnail_button'),

                    style: OutlinedButton.styleFrom(

                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),

                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

                    ),

                    onPressed: _pickThumbnail,

                    child: const Row(

                      mainAxisAlignment: MainAxisAlignment.center,

                      children: [

                        Icon(Icons.add_photo_alternate_outlined, size: 20),

                        SizedBox(width: 8),

                        Flexible(

                          child: Text(

                            "Select Thumbnail (JPG, PNG)",

                            overflow: TextOverflow.ellipsis,

                            maxLines: 1,

                          ),

                        ),

                      ],

                    ),

                  ),

                ),

              const SizedBox(height: 8),

              Row(

                mainAxisAlignment: MainAxisAlignment.end,

                children: [

                  InkWell(

                    onTap: () {

                      setState(() {

                        _showThumbnailUrlField = !_showThumbnailUrlField;

                      });

                    },

                    child: Row(

                      mainAxisSize: MainAxisSize.min,

                      children: [

                        Icon(

                          _showThumbnailUrlField

                              ? Icons.arrow_drop_up_rounded

                              : Icons.link_rounded,

                          size: 16,

                          color: AppColors.textSecondary,

                        ),

                        const SizedBox(width: 4),

                        Text(

                          _showThumbnailUrlField ? "Hide URL input" : "Or enter Thumbnail URL",

                          style: const TextStyle(

                            fontSize: 11.5,

                            color: AppColors.textSecondary,

                            fontWeight: FontWeight.w500,

                          ),

                        ),

                      ],

                    ),

                  ),

                ],

              ),

              if (_showThumbnailUrlField) ...[

                const SizedBox(height: 6),

                TextField(

                  controller: _thumbnailUrlController,

                  decoration: InputDecoration(

                    hintText: "https://.../thumbnail.jpg",

                    labelText: "Lecture Thumbnail URL",

                    isDense: true,

                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),

                    prefixIcon: const Icon(Icons.link, size: 18),

                    suffixIcon: _thumbnailUrlController.text.isNotEmpty

                        ? IconButton(

                            icon: const Icon(Icons.clear, size: 16),

                            onPressed: () {

                              setState(() {

                                _thumbnailUrlController.clear();

                              });

                            },

                          )

                        : null,

                  ),

                  onChanged: (_) => setState(() {}),

                  style: const TextStyle(fontSize: 12.5),

                ),

              ],

            ],

          ),

        ),

        const SizedBox(height: 24),



        // Submit Button

        ModernButton(

          text: "Upload & Add to Curriculum",

          icon: Icons.cloud_upload_outlined,

          variant: ButtonVariant.primary,

          onPressed: myBatches.isEmpty ? null : _startUpload,

        ),

      ],

    );

  }



  String _formatBytes(int bytes) {

    if (bytes >= 1024 * 1024 * 1024) {

      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';

    }

    if (bytes >= 1024 * 1024) {

      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

    }

    return '${(bytes / 1024).toStringAsFixed(1)} KB';

  }



  Widget _buildProgressView([LectureUploadTask? task]) {

    final effectiveProgress = task != null ? task.progress : _uploadProgress;

    final effectiveUploaded = task != null ? task.uploadedBytes : _uploadedBytes;

    final effectiveTotal = task != null ? task.totalBytes : _uploadTotalBytes;

    final isInserting = (task != null && task.status == LectureUploadStatus.inserting) || _status == UploadStatus.inserting;

    final isDark = Theme.of(context).brightness == Brightness.dark;



    return ModernCard(

      padding: const EdgeInsets.all(24),

      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,

      child: Column(

        children: [

          const SizedBox(height: 10),

          const CircularProgressIndicator(color: AppColors.saffronDark),

          const SizedBox(height: 20),

          Text(

            !isInserting

                ? "Streaming Upload to Cloudflare..."

                : "Registering Lesson...",

            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),

          ),

          const SizedBox(height: 8),

          Text(

            !isInserting

                ? "Uploading directly to Cloudflare Stream Engine (Adaptive HLS Transcoding)"

                : "Inserting record into public.lessons...",

            style: const TextStyle(

              fontSize: 12,

              color: AppColors.textSecondary,

            ),

          ),

          const SizedBox(height: 16),

          LinearProgressIndicator(

            value: effectiveProgress,

            color: AppColors.saffronDark,

            backgroundColor: AppColors.saffronMuted,

          ),

          const SizedBox(height: 8),

          Text(

            "${(effectiveProgress * 100).toInt()}% • ${_formatBytes(effectiveUploaded)} / ${_formatBytes(effectiveTotal)}",

            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),

          ),

          const SizedBox(height: 24),

          OutlinedButton.icon(

            key: const Key('cancel_upload_button'),

            icon: const Icon(Icons.cancel_outlined, color: AppColors.error, size: 18),

            label: const Text(

              "Cancel Upload",

              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),

            ),

            style: OutlinedButton.styleFrom(

              side: const BorderSide(color: AppColors.error),

              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),

              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

            ),

            onPressed: _cancelUpload,

          ),

        ],

      ),

    );

  }



  Widget _buildFailureView([LectureUploadTask? task]) {

    final isDark = Theme.of(context).brightness == Brightness.dark;

    String effectiveError = _uploadError ?? task?.error ?? "An unexpected error occurred during upload.";

    if (effectiveError.contains('NoSuchBucket') ||

        effectiveError.contains('Bucket not found') ||

        effectiveError.contains('404')) {

      effectiveError =

          "Storage bucket 'lecture-videos' is not yet provisioned on the Supabase backend. Please review and apply the required Storage migration.";

    }



    return ModernCard(

      padding: const EdgeInsets.all(16),

      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,

      accentSpineColor: AppColors.error,

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          const Row(

            children: [

              Icon(Icons.error_outline, color: AppColors.error, size: 24),

              SizedBox(width: 10),

              Text(

                "Upload Failed",

                style: TextStyle(

                  fontSize: 16,

                  fontWeight: FontWeight.bold,

                  color: AppColors.error,

                ),

              ),

            ],

          ),

          const SizedBox(height: 10),

          Text(

            effectiveError,

            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),

          ),

          const SizedBox(height: 16),

          Row(

            children: [

              ElevatedButton.icon(

                onPressed: _startUpload,

                icon: const Icon(Icons.refresh, size: 18),

                label: const Text("Retry Upload"),

                style: ElevatedButton.styleFrom(

                  backgroundColor: AppColors.deepInk,

                  foregroundColor: Colors.white,

                  elevation: 0,

                  shape: RoundedRectangleBorder(

                    borderRadius: BorderRadius.circular(6),

                  ),

                ),

              ),

              const SizedBox(width: 10),

              OutlinedButton(

                onPressed: _resetForm,

                style: OutlinedButton.styleFrom(

                  side: const BorderSide(color: AppColors.border),

                  shape: RoundedRectangleBorder(

                    borderRadius: BorderRadius.circular(6),

                  ),

                ),

                child: const Text("Cancel"),

              ),

            ],

          ),

        ],

      ),

    );

  }



  Widget _buildSuccessView([LectureUploadTask? task]) {

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final effectiveLesson = task?.createdLesson ?? _createdLesson;



    return ModernCard(

      padding: const EdgeInsets.all(20),

      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,

      accentSpineColor: AppColors.emerald,

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          const Row(

            children: [

              Icon(

                Icons.check_circle_outline,

                color: AppColors.emerald,

                size: 28,

              ),

              SizedBox(width: 10),

              Text(

                "Lecture Uploaded Successfully!",

                style: TextStyle(

                  fontSize: 16,

                  fontWeight: FontWeight.bold,

                  color: AppColors.emerald,

                ),

              ),

            ],

          ),

          const SizedBox(height: 14),



          // Cloudflare Stream processing notice

          Container(

            padding: const EdgeInsets.all(12),

            decoration: BoxDecoration(

              color: isDark ? AppColors.saffron.withValues(alpha: 0.15) : AppColors.saffronMuted,

              borderRadius: BorderRadius.circular(8),

              border: Border.all(

                color: AppColors.saffronDark.withValues(alpha: 0.4),

              ),

            ),

            child: Row(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                const Icon(Icons.info_outline, color: AppColors.saffronDark, size: 20),

                const SizedBox(width: 10),

                Expanded(

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      const Text(

                        "Cloudflare Processing in Progress (~30-60s)",

                        style: TextStyle(

                          fontWeight: FontWeight.bold,

                          fontSize: 13,

                          color: AppColors.saffronDark,

                        ),

                      ),

                      const SizedBox(height: 4),

                      Text(

                        "Your video has been uploaded and registered! Cloudflare is now transcoding it into adaptive bitrate streaming (360p to 1080p). It will appear and be available to play for students in a few seconds.",

                        style: TextStyle(

                          fontSize: 12,

                          color: isDark ? AppColors.darkTextSecondary : AppColors.deepInk,

                        ),

                      ),

                    ],

                  ),

                ),

              ],

            ),

          ),

          const SizedBox(height: 16),



          if (effectiveLesson != null) ...[

            _buildDetailRow("Title", effectiveLesson.title),

            _buildDetailRow("Chapter", effectiveLesson.chapter),

            _buildDetailRow("Storage Path", effectiveLesson.videoUrl),

            _buildDetailRow("Lesson ID", effectiveLesson.id),

          ] else if (task != null) ...[

            _buildDetailRow("Title", task.title),

            _buildDetailRow("Chapter", task.chapter),

            _buildDetailRow("Batch", task.batchName),

          ],

          const SizedBox(height: 20),

          Wrap(

            spacing: 10,

            runSpacing: 8,

            children: [

              ElevatedButton(

                onPressed: _resetForm,

                style: ElevatedButton.styleFrom(

                  backgroundColor: AppColors.deepInk,

                  foregroundColor: Colors.white,

                  shape: RoundedRectangleBorder(

                    borderRadius: BorderRadius.circular(6),

                  ),

                ),

                child: const Text("Upload Another Video"),

              ),

              OutlinedButton(

                onPressed: () {

                  _resetForm();

                  Navigator.of(context).pop();

                },

                style: OutlinedButton.styleFrom(

                  side: const BorderSide(color: AppColors.border),

                  shape: RoundedRectangleBorder(

                    borderRadius: BorderRadius.circular(6),

                  ),

                ),

                child: const Text("Done"),

              ),

            ],

          ),

        ],

      ),

    );

  }



  Widget _buildDetailRow(String label, String value) {

    return Padding(

      padding: const EdgeInsets.only(bottom: 6),

      child: Row(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          SizedBox(

            width: 90,

            child: Text(

              label,

              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),

            ),

          ),

          Expanded(

            child: Text(

              value,

              style: const TextStyle(

                fontSize: 12,

                fontWeight: FontWeight.w600,

                color: AppColors.deepInk,

              ),

              overflow: TextOverflow.ellipsis,

            ),

          ),

        ],

      ),

    );

  }

}

