enum StudyDocType { pdf, presentation, document, image }

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
}
