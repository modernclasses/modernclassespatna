import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_constants.dart';
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
  bool _isLoading = true;
  String? _errorMessage;
  String? _localPdfPath;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _swipeHorizontal = false;
  PDFViewController? _pdfViewController;

  @override
  void initState() {
    super.initState();
    _totalPages = widget.material.pageCount > 0 ? widget.material.pageCount : 1;
    _loadPdfDocument();
  }

  Future<void> _loadPdfDocument() async {
    final fileUrl = widget.material.fileUrl.trim();
    if (fileUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
          _localPdfPath = null;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tempDir = await getTemporaryDirectory();
      // Create a deterministic sanitized filename based on material id and file path
      final cleanName = fileUrl
          .split('/')
          .last
          .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final fileName = 'mat_${widget.material.id.isNotEmpty ? widget.material.id : "doc"}_$cleanName';
      final file = File('${tempDir.path}/$fileName');

      // Use cached copy if available and non-empty
      if (await file.exists() && await file.length() > 0) {
        if (mounted) {
          setState(() {
            _localPdfPath = file.path;
            _isLoading = false;
          });
        }
        return;
      }

      Uint8List bytes;
      if (fileUrl.startsWith('http://') || fileUrl.startsWith('https://')) {
        final res = await http.get(Uri.parse(fileUrl));
        if (res.statusCode == 200) {
          bytes = res.bodyBytes;
        } else {
          throw Exception('Failed to download document (HTTP ${res.statusCode})');
        }
      } else {
        // Fetch from Supabase storage
        if (!AppConfig.isSupabaseConfigured) {
          throw Exception('Database storage is not configured.');
        }
        final client = Supabase.instance.client;

        try {
          bytes = await client.storage
              .from(AppConstants.bucketStudyMaterials)
              .download(fileUrl);
        } catch (_) {
          // Fallback to signed URL if direct binary download requires one
          final signedUrl = await client.storage
              .from(AppConstants.bucketStudyMaterials)
              .createSignedUrl(fileUrl, 3600);
          final res = await http.get(Uri.parse(signedUrl));
          if (res.statusCode == 200) {
            bytes = res.bodyBytes;
          } else {
            throw Exception('Could not fetch document file from cloud storage.');
          }
        }
      }

      await file.writeAsBytes(bytes, flush: true);

      if (mounted) {
        setState(() {
          _localPdfPath = file.path;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _showJumpToPageDialog() {
    final controller = TextEditingController(text: '${_currentPage + 1}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Jump to Page', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Page Number (1 - $_totalPages)',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final target = int.tryParse(controller.text.trim());
              if (target != null && target >= 1 && target <= _totalPages) {
                Navigator.pop(ctx);
                _pdfViewController?.setPage(target - 1);
              }
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }

  void _showDocumentDetails(BuildContext context) {
    final mat = widget.material;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.picture_as_pdf, color: AppTheme.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mat.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${mat.subject} • Chapter: ${mat.chapter}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildDetailRow(Icons.person_outline, 'Faculty', mat.uploaderName),
              _buildDetailRow(Icons.pages_outlined, 'Total Pages', '$_totalPages Pages'),
              _buildDetailRow(Icons.data_usage_outlined, 'File Size', mat.fileSize),
              _buildDetailRow(Icons.security, 'Protection', 'Protected Reader • Watermarked'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 18, color: AppTheme.primary),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Licensed for personal educational study only at Modern Classes Patna. Direct downloads and unauthorized distribution are disabled.',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final mat = widget.material;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool canRunNativePdf = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: isDark ? AppColors.darkSurface : AppTheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mat.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              "${mat.subject} • ${mat.chapter}",
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _swipeHorizontal ? "Vertical Scroll Mode" : "Booklet Page-Flip Mode",
            icon: Icon(
              _swipeHorizontal ? Icons.view_headline_rounded : Icons.view_carousel_rounded,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _swipeHorizontal = !_swipeHorizontal;
              });
            },
          ),
          IconButton(
            tooltip: "Document Information",
            icon: const Icon(Icons.info_outline_rounded, size: 20),
            onPressed: () => _showDocumentDetails(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          // Content Layer
          if (_isLoading)
            _buildLoadingState(isDark)
          else if (_errorMessage != null)
            _buildErrorState(isDark)
          else if (_localPdfPath != null && canRunNativePdf)
            _buildPdfView()
          else
            _buildFallbackOverview(isDark),

          // Security Watermark Layer
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.045,
                child: Transform.rotate(
                  angle: -0.4,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "MODERN CLASSES PATNA",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "STUDENT: ${auth.currentUser.name} (${auth.currentUser.phone})",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom Floating Page Navigation Capsule
          if (!_isLoading && _errorMessage == null && _totalPages > 0)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E232A).withValues(alpha: 0.95)
                        : Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded, size: 22),
                        tooltip: "Previous Page",
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        onPressed: _currentPage > 0
                            ? () {
                                _pdfViewController?.setPage(_currentPage - 1);
                              }
                            : null,
                      ),
                      InkWell(
                        onTap: _showJumpToPageDialog,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Page ${_currentPage + 1} of $_totalPages",
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.unfold_more_rounded,
                                size: 14,
                                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded, size: 22),
                        tooltip: "Next Page",
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        onPressed: _currentPage < _totalPages - 1
                            ? () {
                                _pdfViewController?.setPage(_currentPage + 1);
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

  Widget _buildPdfView() {
    return PDFView(
      filePath: _localPdfPath,
      enableSwipe: true,
      swipeHorizontal: _swipeHorizontal,
      autoSpacing: true,
      pageFling: true,
      pageSnap: true,
      fitPolicy: FitPolicy.BOTH,
      preventLinkNavigation: false,
      onRender: (pages) {
        if (mounted && pages != null && pages > 0) {
          setState(() {
            _totalPages = pages;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _errorMessage = error.toString();
          });
        }
      },
      onViewCreated: (PDFViewController controller) {
        _pdfViewController = controller;
      },
      onPageChanged: (int? page, int? total) {
        if (mounted && page != null) {
          setState(() {
            _currentPage = page;
            if (total != null && total > 0) {
              _totalPages = total;
            }
          });
        }
      },
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceCard : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Loading Secure Study Material...",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Downloading encrypted PDF from Modern Classes Patna Vault",
            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 36, color: AppColors.error),
            ),
            const SizedBox(height: 16),
            Text(
              "Unable to Open Document",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? "The PDF file could not be loaded or network connection timed out.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadPdfDocument,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text("Retry Download"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackOverview(bool isDark) {
    final mat = widget.material;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceCard : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        mat.subject,
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      "${mat.pageCount} Pages • ${mat.fileSize}",
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  mat.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Chapter: ${mat.chapter} • Faculty: ${mat.uploaderName}",
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Topics Overview
          if (mat.previewPages.isNotEmpty) ...[
            Text(
              "Key Topics & Notes Outline",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            for (int i = 0; i < mat.previewPages.length; i++)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceCard : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        mat.previewPages[i],
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
