import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/custom_badge.dart';
import '../../core/widgets/modern_card.dart';
import '../../models/study_material_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/study_material_provider.dart';
import 'document_reader_screen.dart';

class StudyMaterialsScreen extends StatelessWidget {
  const StudyMaterialsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final materialProvider = context.watch<StudyMaterialProvider>();
    final materials = materialProvider.filteredMaterials;
    final subjects = materialProvider.subjects;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool canManage = false;
    try {
      final auth = context.watch<AuthProvider>();
      canManage = auth.isTeacher || auth.isAdmin;
    } catch (_) {}

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Study Material & Notes"),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      ),
      body: Column(
        children: [
          // Subject Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.surface,
              border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border)),
            ),
            child: SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: subjects.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final sub = subjects[index];
                  final isSelected = sub == materialProvider.selectedSubject;

                  return InkWell(
                    onTap: () => materialProvider.setSelectedSubject(sub),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? AppColors.primary : AppColors.deepInk)
                            : (isDark ? AppColors.darkSurfaceCard : AppColors.surfaceSubtle),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected
                              ? (isDark ? AppColors.primary : AppColors.deepInk)
                              : (isDark ? AppColors.darkBorder : AppColors.border),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        sub,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isSelected
                              ? (isDark ? Colors.black : Colors.white)
                              : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Security banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark ? AppColors.primary.withValues(alpha: 0.15) : AppColors.saffronMuted,
            child: Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 14,
                  color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "All notes & PDFs are secured with dynamic DRM watermark for enrolled in-app reading.",
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Material Cards List
          Expanded(
            child: materials.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        "No study materials in this category.",
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
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
                              builder: (_) =>
                                  DocumentReaderScreen(material: mat),
                            ),
                          );
                        },
                        accentSpineColor: _getMaterialColor(mat.type),
                        padding: const EdgeInsets.all(14),
                        backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
                        borderColor: isDark ? AppColors.darkBorder : AppColors.border,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _getMaterialColor(
                                  mat.type,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getMaterialIcon(mat.type),
                                size: 24,
                                color: _getMaterialColor(mat.type),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CustomBadge(
                                        text: mat.subject,
                                        variant: BadgeVariant.primary,
                                        fontSize: 9.5,
                                      ),
                                      const Spacer(),
                                      Text(
                                        "${mat.pageCount} Pages • ${mat.fileSize}",
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    mat.title,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    "Chapter: ${mat.chapter} • Faculty: ${mat.uploaderName}",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text(
                                        "Published on ${Formatters.formatDate(mat.uploadedAt)}",
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (canManage) ...[
                                        IconButton(
                                          key: Key('delete_material_${mat.id}'),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: AppColors.error,
                                            size: 18,
                                          ),
                                          tooltip: "Delete Material",
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () =>
                                              _confirmDeleteMaterial(context, mat),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Text(
                                        "Read In-App →",
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
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

  Future<void> _confirmDeleteMaterial(
    BuildContext context,
    StudyMaterialModel mat,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor:
            isDark ? AppColors.darkSurfaceCard : AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
            SizedBox(width: 8),
            Text('Delete Study Material?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete "${mat.title}"?',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            const Text(
              'Warning: The uploaded PDF document and reference records will be permanently removed. This action cannot be reversed.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Delete Material'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await context
            .read<StudyMaterialProvider>()
            .deleteMaterial(mat.id, fileUrl: mat.fileUrl);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Material "${mat.title}" deleted successfully.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete material: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  IconData _getMaterialIcon(StudyDocType type) {
    switch (type) {
      case StudyDocType.pdf:
        return Icons.picture_as_pdf_outlined;
      case StudyDocType.presentation:
        return Icons.slideshow_outlined;
      case StudyDocType.document:
        return Icons.article_outlined;
      case StudyDocType.image:
        return Icons.image_outlined;
    }
  }

  Color _getMaterialColor(StudyDocType type) {
    switch (type) {
      case StudyDocType.pdf:
        return AppColors.error;
      case StudyDocType.presentation:
        return AppColors.warning;
      case StudyDocType.document:
        return AppColors.secondary;
      case StudyDocType.image:
        return AppColors.purple;
    }
  }
}
