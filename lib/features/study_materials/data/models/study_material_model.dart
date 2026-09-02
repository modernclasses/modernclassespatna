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
  final List<String> previewPages; // Sample slide/page text/images for previewing
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
    switch (map['type']?.toString().toLowerCase()) {
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

    return StudyMaterialModel(
      id: map['id']?.toString() ?? '',
      courseId: map['course_id']?.toString() ?? '',
      batchId: map['batch_id']?.toString() ?? '',
      title: map['title'] ?? 'Study Notes',
      subject: map['subject'] ?? 'General Studies',
      chapter: map['chapter'] ?? 'Chapter Notes',
      type: parsedType,
      pageCount: (map['page_count'] as num?)?.toInt() ?? 12,
      fileSize: map['file_size'] ?? '2.4 MB',
      fileUrl: map['file_url'] ?? '',
      previewPages: map['preview_pages'] != null
          ? List<String>.from(map['preview_pages'])
          : const [],
      uploadedAt: map['uploaded_at'] != null
          ? DateTime.tryParse(map['uploaded_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      uploaderName: map['uploader_name'] ?? 'Faculty Member',
      isSecureWatermarked: map['is_secure_watermarked'] ?? true,
    );
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
