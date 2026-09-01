import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/study_material_model.dart';
import '../../providers/auth_provider.dart';

class DocumentReaderScreen extends StatefulWidget {
  final StudyMaterialModel material;

  const DocumentReaderScreen({super.key, required this.material});

  @override
  State<DocumentReaderScreen> createState() => _DocumentReaderScreenState();
}

class _DocumentReaderScreenState extends State<DocumentReaderScreen> {
  int _currentPage = 1;
  double _zoomLevel = 1.0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final mat = widget.material;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mat.title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              "${mat.subject} • Page $_currentPage of ${mat.pageCount}",
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out, size: 20),
            onPressed: () {
              setState(() {
                if (_zoomLevel > 0.8) _zoomLevel -= 0.1;
              });
            },
          ),
          Center(
            child: Text(
              "${(_zoomLevel * 100).toInt()}%",
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in, size: 20),
            onPressed: () {
              setState(() {
                if (_zoomLevel < 1.6) _zoomLevel += 0.1;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Document Page Content Area
          Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 2.5,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Transform.scale(
                  scale: _zoomLevel,
                  child: Container(
                    width: 600,
                    constraints: const BoxConstraints(minHeight: 800),
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderLight),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Watermark Overlay across page (Security)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: 0.05,
                              child: Transform.rotate(
                                angle: -0.5,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        "MODERN CLASSES PATNA",
                                        style: TextStyle(
                                          fontSize: 34,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Licensed to: ${auth.currentUser.name} (${auth.currentUser.phone})",
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Document Content
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Document Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "MODERN CLASSES PATNA",
                                      style: TextStyle(
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      "Director: Madhurendra Kumar Yadav",
                                      style: TextStyle(
                                        color: AppTheme.textSecondary.withValues(alpha: 0.7),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceLight,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: Text(
                                    "SECURE NOTE",
                                    style: TextStyle(
                                      color: AppTheme.primaryLight,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(color: AppTheme.border),
                            const SizedBox(height: 16),

                            // Chapter Title
                            Text(
                              mat.chapter,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.secondaryLight,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              mat.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Page Content preview
                            if (mat.previewPages.isNotEmpty) ...[
                              for (int i = 0; i < mat.previewPages.length; i++) ...[
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.bookmark, size: 14, color: AppTheme.primary),
                                          const SizedBox(width: 6),
                                          Text(
                                            "Point #${i + 1}",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: AppTheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        mat.previewPages[i],
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.6,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],

                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.shield_outlined, size: 16, color: AppTheme.primary),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Protected educational content by Modern Classes Patna. External download & screen capture disabled for copyright compliance.",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Non-downloadable Security Notice Pill
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.borderLight),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_rounded, size: 14),
                      onPressed: _currentPage > 1
                          ? () {
                              setState(() {
                                _currentPage--;
                              });
                            }
                          : null,
                    ),
                    Text(
                      "Page $_currentPage / ${mat.pageCount}",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onPressed: _currentPage < mat.pageCount
                          ? () {
                              setState(() {
                                _currentPage++;
                              });
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
