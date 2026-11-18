import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_colors.dart';
import '../theme/app_typography.dart';

class ImageUploadPickerWidget extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final String? helperText;
  final Future<String> Function(String fileName, Uint8List fileBytes)? onUpload;
  final bool enabled;
  final bool isCompact;
  final bool require16by9;
  final bool strict1920x1080;

  const ImageUploadPickerWidget({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.helperText,
    this.onUpload,
    this.enabled = true,
    this.isCompact = false,
    this.require16by9 = true,
    this.strict1920x1080 = false,
  });

  @override
  State<ImageUploadPickerWidget> createState() => _ImageUploadPickerWidgetState();
}

class _ImageUploadPickerWidgetState extends State<ImageUploadPickerWidget> {
  Uint8List? _selectedBytes;
  String? _selectedFileName;
  int? _imageWidth;
  int? _imageHeight;
  bool _isUploading = false;
  String? _errorMessage;
  bool _showUrlField = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onUrlChanged);
    if (widget.controller.text.trim().isNotEmpty) {
      _showUrlField = true;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onUrlChanged);
    super.dispose();
  }

  void _onUrlChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _pickAndUploadImage() async {
    if (!widget.enabled || _isUploading) return;

    setState(() {
      _errorMessage = null;
    });

    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        setState(() {
          _errorMessage =
              "Image file must be smaller than 5 MB (${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB).";
        });
        return;
      }

      int? width;
      int? height;
      if (widget.require16by9 || widget.strict1920x1080) {
        try {
          final decoded = await decodeImageFromList(bytes);
          width = decoded.width;
          height = decoded.height;
          final double ratio = width / height;

          if (widget.strict1920x1080) {
            if (width != 1920 || height != 1080) {
              setState(() {
                _errorMessage =
                    "Exact dimensions required: 1920×1080 px. Detected: $width×$height px.";
              });
              return;
            }
          } else if (widget.require16by9) {
            // Check for 16:9 widescreen ratio (1.7778 with tolerance 0.06: 1.72 to 1.84)
            final bool is16by9 = (ratio - (16.0 / 9.0)).abs() <= 0.06;
            if (!is16by9) {
              setState(() {
                _errorMessage =
                    "Invalid aspect ratio: ${(ratio).toStringAsFixed(2)}:1 ($width×$height px). Only 16:9 widescreen thumbnails (1920×1080 px) are accepted.";
              });
              return;
            }
            if (width < 1280 || height < 720) {
              setState(() {
                _errorMessage =
                    "Resolution too low: $width×$height px. Thumbnails must be 1920×1080 px (or at least 1280×720 px 16:9).";
              });
              return;
            }
          }
        } catch (decodeErr) {
          debugPrint("Note: Could not decode image dimensions: $decodeErr");
        }
      }

      setState(() {
        _selectedBytes = bytes;
        _selectedFileName = image.name;
        _imageWidth = width;
        _imageHeight = height;
        _isUploading = true;
      });

      if (widget.onUpload != null) {
        try {
          final uploadedUrl = await widget.onUpload!(image.name, bytes);
          if (mounted) {
            widget.controller.text = uploadedUrl;
            _errorMessage = null;
          }
        } catch (uploadErr) {
          if (mounted) {
            _errorMessage =
                "Upload failed: $uploadErr. Image preview is kept locally.";
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to select image: $e";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _clearImage() {
    setState(() {
      _selectedBytes = null;
      _selectedFileName = null;
      _imageWidth = null;
      _imageHeight = null;
      _errorMessage = null;
      widget.controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUrl = widget.controller.text.trim();
    final hasImage = _selectedBytes != null || currentUrl.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
          ),
          padding: EdgeInsets.all(widget.isCompact ? 8 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Row
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 2,
                children: [
                  Text(
                    widget.labelText,
                    style: AppTypography.subtitle2.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: widget.isCompact ? 12.5 : 13.5,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                    ),
                  ),
                  if (widget.helperText != null)
                    Text(
                      widget.helperText!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Preview & Main Action Area
              if (hasImage) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                    ),
                  ),
                  child: isNarrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: SizedBox(
                                    width: 50,
                                    height: 38,
                                    child: _buildPreviewImage(currentUrl, isDark),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildDetailsColumn(currentUrl, isDark),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: _buildActionButtons(),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: SizedBox(
                                width: 64,
                                height: 46,
                                child: _buildPreviewImage(currentUrl, isDark),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildDetailsColumn(currentUrl, isDark),
                            ),
                            ..._buildActionButtons(),
                          ],
                        ),
                ),
              ] else ...[
                // Empty State: Direct Upload Button & URL prompt
                InkWell(
                  onTap: widget.enabled && !_isUploading ? _pickAndUploadImage : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.border,
                      ),
                      color: isDark
                          ? AppColors.darkSurface.withValues(alpha: 0.5)
                          : AppColors.surfaceSubtle,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 24,
                          color: AppColors.primaryDark,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Upload Image from Device",
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Required: 16:9 Widescreen (1920×1080 px)",
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: 6),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.error, fontSize: 11),
                ),
              ],

              // Toggle for Direct URL Entry
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _showUrlField = !_showUrlField;
                    });
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showUrlField
                              ? Icons.arrow_drop_up_rounded
                              : Icons.link_rounded,
                          size: 15,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _showUrlField
                                ? "Hide URL input"
                                : (isNarrow ? "Enter Image URL" : "Or enter Image URL"),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // URL Text Field (When Expanded)
              if (_showUrlField) ...[
                const SizedBox(height: 6),
                TextField(
                  controller: widget.controller,
                  enabled: widget.enabled && !_isUploading,
                  scrollPadding: const EdgeInsets.only(bottom: 80),
                  decoration: InputDecoration(
                    hintText: widget.hintText ?? "https://example.com/image.png",
                    labelText: "Image URL",
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    prefixIcon: const Icon(Icons.link, size: 16),
                    suffixIcon: widget.controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () {
                              widget.controller.clear();
                            },
                          )
                        : null,
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailsColumn(String currentUrl, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _selectedFileName ??
              (currentUrl.isNotEmpty
                  ? (currentUrl.split('/').last.split('?').first)
                  : "Selected Image"),
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              _isUploading
                  ? "Uploading to storage..."
                  : (_selectedBytes != null
                      ? "${(_selectedBytes!.length / 1024).toStringAsFixed(1)} KB"
                      : "URL linked"),
              style: TextStyle(
                fontSize: 10,
                color: _isUploading ? AppColors.primary : AppColors.textMuted,
              ),
            ),
            if (_imageWidth != null && _imageHeight != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.4), width: 0.5),
                ),
                child: Text(
                  "16:9 ($_imageWidth×$_imageHeight px)",
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildActionButtons() {
    if (_isUploading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ];
    }

    return [
      TextButton(
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          minimumSize: const Size(0, 30),
        ),
        onPressed: widget.enabled ? _pickAndUploadImage : null,
        child: const Text("Change", style: TextStyle(fontSize: 11)),
      ),
      IconButton(
        icon: const Icon(Icons.close, size: 16),
        tooltip: "Remove",
        constraints: const BoxConstraints(),
        padding: const EdgeInsets.all(4),
        visualDensity: VisualDensity.compact,
        onPressed: widget.enabled ? _clearImage : null,
      ),
    ];
  }

  Widget _buildPreviewImage(String currentUrl, bool isDark) {
    if (_selectedBytes != null) {
      return Image.memory(
        _selectedBytes!,
        fit: BoxFit.cover,
      );
    }

    if (currentUrl.isNotEmpty) {
      return Image.network(
        currentUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: isDark ? AppColors.darkSurface : AppColors.surfaceSubtle,
          alignment: Alignment.center,
          child: const Icon(
            Icons.broken_image_outlined,
            size: 20,
            color: AppColors.textMuted,
          ),
        ),
      );
    }

    return Container(
      color: isDark ? AppColors.darkSurface : AppColors.surfaceSubtle,
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        size: 20,
        color: AppColors.textMuted,
      ),
    );
  }
}
