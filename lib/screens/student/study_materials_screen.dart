import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../models/study_material_model.dart';
import '../../providers/study_material_provider.dart';
import 'document_reader_screen.dart';

class StudyMaterialsScreen extends StatelessWidget {
  const StudyMaterialsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final materialProvider = context.watch<StudyMaterialProvider>();
    final materials = materialProvider.filteredMaterials;
    final subjects = materialProvider.subjects;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Study Material & Notes"),
      ),
      body: Column(
        children: [
          // Subject Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppTheme.surface,
            child: SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: subjects.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final sub = subjects[index];
                  final isSelected = sub == materialProvider.selectedSubject;

                  return InkWell(
                    onTap: () => materialProvider.setSelectedSubject(sub),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primary : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppTheme.primary : AppTheme.border,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        sub,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.black : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const Divider(height: 1, color: AppTheme.border),

          // Security banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppTheme.primary.withValues(alpha: 0.08),
            child: const Row(
              children: [
                Icon(Icons.lock_outline, size: 14, color: AppTheme.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "All notes & PDFs are secured for in-app viewing (Downloads restricted).",
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),

          // Material Cards List
          Expanded(
            child: materials.isEmpty
                ? const Center(
                    child: Text(
                      "No study materials in this category.",
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: materials.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final mat = materials[index];
                      return ModernCard(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => DocumentReaderScreen(material: mat),
                            ),
                          );
                        },
                        padding: const EdgeInsets.all(16),
                        backgroundColor: AppTheme.surface,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _getMaterialColor(mat.type).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getMaterialIcon(mat.type),
                                size: 26,
                                color: _getMaterialColor(mat.type),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CustomBadge(text: mat.subject, variant: BadgeVariant.primary),
                                      const Spacer(),
                                      Text(
                                        "${mat.pageCount} Pages • ${mat.fileSize}",
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    mat.title,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Chapter: ${mat.chapter} • ${mat.uploaderName}",
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Text(
                                        "Uploaded on ${Formatters.formatDate(mat.uploadedAt)}",
                                        style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                      ),
                                      const Spacer(),
                                      const Text(
                                        "Read Securely →",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  IconData _getMaterialIcon(StudyDocType type) {
    switch (type) {
      case StudyDocType.pdf:
        return Icons.picture_as_pdf;
      case StudyDocType.presentation:
        return Icons.slideshow;
      case StudyDocType.document:
        return Icons.article;
      case StudyDocType.image:
        return Icons.image;
    }
  }

  Color _getMaterialColor(StudyDocType type) {
    switch (type) {
      case StudyDocType.pdf:
        return AppTheme.error;
      case StudyDocType.presentation:
        return AppTheme.warning;
      case StudyDocType.document:
        return AppTheme.secondaryLight;
      case StudyDocType.image:
        return AppTheme.purple;
    }
  }
}
