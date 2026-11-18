import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class ConfirmDeleteLectureDialog extends StatefulWidget {
  final String lectureTitle;
  final String? batchName;
  final String textFieldKey;
  final String confirmButtonKey;

  const ConfirmDeleteLectureDialog({
    super.key,
    required this.lectureTitle,
    this.batchName,
    this.textFieldKey = 'confirm_delete_text_field',
    this.confirmButtonKey = 'confirm_delete_lecture_btn',
  });

  @override
  State<ConfirmDeleteLectureDialog> createState() =>
      _ConfirmDeleteLectureDialogState();
}

class _ConfirmDeleteLectureDialogState
    extends State<ConfirmDeleteLectureDialog> {
  late final TextEditingController _controller;
  bool _isMatch = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
          SizedBox(width: 8),
          Text(
            'Delete Lecture?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to permanently delete "${widget.lectureTitle}"?',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            if (widget.batchName != null && widget.batchName!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Batch: ${widget.batchName}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.2),
                ),
              ),
              child: const Text(
                'Warning: The video stream/recording, thumbnail file, and student progress records will be permanently removed. This action cannot be reversed.',
                style: TextStyle(fontSize: 12, color: AppColors.error),
              ),
            ),
            const SizedBox(height: 14),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                children: const [
                  TextSpan(text: 'To confirm deletion, type '),
                  TextSpan(
                    text: 'confirm',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
                  ),
                  TextSpan(text: ' below:'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: Key(widget.textFieldKey),
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: 'Type "confirm"',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : Colors.grey.shade400,
                  fontSize: 13,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: _isMatch
                        ? AppColors.error
                        : (isDark ? Colors.white24 : Colors.grey.shade400),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: AppColors.error,
                    width: 2,
                  ),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _isMatch = val.trim().toLowerCase() == 'confirm';
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: Key(widget.confirmButtonKey),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            disabledBackgroundColor:
                isDark ? Colors.white12 : Colors.grey.shade300,
            disabledForegroundColor:
                isDark ? Colors.white38 : Colors.grey.shade600,
          ),
          onPressed: _isMatch ? () => Navigator.of(context).pop(true) : null,
          child: const Text(
            'Delete Lecture',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
