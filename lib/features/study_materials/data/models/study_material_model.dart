enum StudyDocType { pdf, presentation, document, image }

/// Study Material Entity for Digital Handouts and Chapter Notes.
class StudyMaterialModel {
  final String id;
  final String courseId;
  final String batchId;
  final String title;
  final String subject;
  final String chapter;
  final StudyDocType type;
  final int pageCount;
  final String fileSize;
  final String fileUrl;
  final List<String>
  previewPages; // Sample slide/page text/images for previewing
  final DateTime uploadedAt;
  final String uploaderName;
  final bool isSecureWatermarked; // In-app secure non-downloadable viewer

  StudyMaterialModel({
    required this.id,
    required this.courseId,
    required this.batchId,
    required this.title,
    required this.subject,
    required this.chapter,
    required this.type,
    required this.pageCount,
    required this.fileSize,
    required this.fileUrl,
    required this.previewPages,
    required this.uploadedAt,
    required this.uploaderName,
    this.isSecureWatermarked = true,
  });

  factory StudyMaterialModel.fromMap(Map<String, dynamic> map) {
    StudyDocType parsedType = StudyDocType.pdf;
    final typeStr = (map['file_type'] ?? map['type'])?.toString().toLowerCase();
    switch (typeStr) {
      case 'presentation':
        parsedType = StudyDocType.presentation;
        break;
      case 'document':
        parsedType = StudyDocType.document;
        break;
      case 'image':
        parsedType = StudyDocType.image;
        break;
      default:
        parsedType = StudyDocType.pdf;
    }

    final int sizeBytes = (map['file_size_bytes'] as num?)?.toInt() ?? 0;
    String formattedSize = map['file_size']?.toString() ?? '';
    if (formattedSize.isEmpty) {
      if (sizeBytes > 0) {
        formattedSize = '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      } else {
        formattedSize = '1.5 MB';
      }
    }

    return StudyMaterialModel(
      id: map['id']?.toString() ?? '',
      courseId: map['course_id']?.toString() ?? '',
      batchId: map['batch_id']?.toString() ?? '',
      title: map['title'] ?? 'Study Notes',
      subject: map['subject'] ?? 'General Studies',
      chapter: map['chapter'] ?? 'Chapter Notes',
      type: parsedType,
      pageCount: (map['page_count'] as num?)?.toInt() ?? 12,
      fileSize: formattedSize,
      fileUrl: map['file_url'] ?? '',
      previewPages: map['preview_pages'] != null
          ? List<String>.from(map['preview_pages'])
          : const [],
      uploadedAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : (map['uploaded_at'] != null
                ? DateTime.tryParse(map['uploaded_at'].toString()) ??
                      DateTime.now()
                : DateTime.now()),
      uploaderName: map['uploader_name'] ?? 'Faculty Member',
      isSecureWatermarked: map['is_secure_watermarked'] ?? true,
    );
  }

  /// Insertion map targeting public.study_materials schema
  Map<String, dynamic> toInsertMap({String? uploadedBy}) {
    final map = <String, dynamic>{
      'course_id': courseId,
      'title': title,
      'subject': subject,
      'file_url': fileUrl,
      'file_type': type.name.toUpperCase(),
      'file_size_bytes': _parseSizeBytes(fileSize),
    };
    if (batchId.isNotEmpty) {
      map['batch_id'] = batchId;
    }
    if (uploadedBy != null && uploadedBy.isNotEmpty) {
      map['uploaded_by'] = uploadedBy;
    }
    if (RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id)) {
      map['id'] = id;
    }
    return map;
  }

  static int _parseSizeBytes(String sizeStr) {
    try {
      final parts = sizeStr.trim().split(' ');
      if (parts.isNotEmpty) {
        final numVal = double.tryParse(parts[0]) ?? 1.0;
        final unit = parts.length > 1 ? parts[1].toUpperCase() : 'MB';
        if (unit.contains('KB')) return (numVal * 1024).round();
        if (unit.contains('MB')) return (numVal * 1024 * 1024).round();
        if (unit.contains('GB')) return (numVal * 1024 * 1024 * 1024).round();
      }
    } catch (_) {}
    return 1024 * 1024;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'course_id': courseId,
      'batch_id': batchId,
      'title': title,
      'subject': subject,
      'chapter': chapter,
      'type': type.name,
      'page_count': pageCount,
      'file_size': fileSize,
      'file_url': fileUrl,
      'preview_pages': previewPages,
      'uploaded_at': uploadedAt.toIso8601String(),
      'uploader_name': uploaderName,
      'is_secure_watermarked': isSecureWatermarked,
    };
  }
}
