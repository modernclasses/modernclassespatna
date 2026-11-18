import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/batch_timing_helper.dart';

/// Interactive Day & Hour Calendar Picker for Batch Schedules.
/// Allows picking lecture days and start/end hours with live preview.
class BatchTimingPickerDialog extends StatefulWidget {
  final String initialTiming;
  final Iterable<String> existingTimings;

  const BatchTimingPickerDialog({
    super.key,
    required this.initialTiming,
    this.existingTimings = const [],
  });

  static Future<String?> show(
    BuildContext context, {
    required String initialTiming,
    Iterable<String> existingTimings = const [],
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => BatchTimingPickerDialog(
        initialTiming: initialTiming,
        existingTimings: existingTimings,
      ),
    );
  }

  @override
  State<BatchTimingPickerDialog> createState() =>
      _BatchTimingPickerDialogState();
}

class _BatchTimingPickerDialogState extends State<BatchTimingPickerDialog> {
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late List<String> _selectedDays;

  @override
  void initState() {
    super.initState();
    final parsed = BatchTimingHelper.parseTiming(widget.initialTiming);
    _startTime = parsed.start;
    _endTime = parsed.end;
    _selectedDays = List.from(parsed.days);
  }

  void _applyPreset(String preset) {
    setState(() {
      switch (preset) {
        case 'Mon-Sat':
          _selectedDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
          break;
        case 'Mon-Fri':
          _selectedDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
          break;
        case 'Daily':
          _selectedDays = List.from(BatchTimingHelper.allDaysOfWeek);
          break;
        case 'Weekend':
          _selectedDays = ['Sat', 'Sun'];
          break;
      }
    });
  }

  void _toggleDay(String day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        if (_selectedDays.length > 1) {
          _selectedDays.remove(day);
        }
      } else {
        _selectedDays.add(day);
        // Keep in order
        _selectedDays.sort(
          (a, b) => BatchTimingHelper.allDaysOfWeek
              .indexOf(a)
              .compareTo(BatchTimingHelper.allDaysOfWeek.indexOf(b)),
        );
      }
    });
  }

  Future<void> _pickStartTime() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: AppTheme.primary,
                    surface: AppColors.darkSurfaceCard,
                    onSurface: AppColors.darkTextPrimary,
                  )
                : ColorScheme.light(
                    primary: AppTheme.primary,
                    surface: AppColors.surfaceCard,
                    onSurface: AppColors.deepInk,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: AppTheme.primary,
                    surface: AppColors.darkSurfaceCard,
                    onSurface: AppColors.darkTextPrimary,
                  )
                : ColorScheme.light(
                    primary: AppTheme.primary,
                    surface: AppColors.surfaceCard,
                    onSurface: AppColors.deepInk,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  String get _formattedTiming => BatchTimingHelper.buildTimingString(
    startTime: _startTime,
    endTime: _endTime,
    days: _selectedDays,
  );

  String? get _timeRangeError =>
      BatchTimingHelper.validateTimeRange(_startTime, _endTime);

  String? get _overlapConflict =>
      BatchTimingHelper.findOverlappingTiming(_formattedTiming, widget.existingTimings);

  int get _durationMinutes {
    final startM = _startTime.hour * 60 + _startTime.minute;
    final endM = _endTime.hour * 60 + _endTime.minute;
    return endM - startM;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final durationHours = (_durationMinutes / 60)
        .toStringAsFixed(1)
        .replaceAll('.0', '');

    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkSurfaceCard : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      title: Row(
        children: [
          Icon(Icons.calendar_month, color: isDark ? AppColors.primaryLight : AppTheme.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Schedule (Hours & Days)",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.primary.withValues(alpha: 0.2) : AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.primary.withValues(alpha: 0.5) : AppTheme.primary.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Configured Slot Preview:",
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppColors.darkTextMuted : AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formattedTiming,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.primaryLight : AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            if (_overlapConflict != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Overlaps with existing course slot:\n$_overlapConflict",
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Hours Section
            Text(
              "1. Select Class Hours",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickStartTime,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Start Time",
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? AppColors.darkTextSecondary : AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 16,
                                color: isDark ? AppColors.primaryLight : AppTheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  BatchTimingHelper.formatTimeOfDay(_startTime),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: isDark ? AppColors.darkTextMuted : AppTheme.textMuted,
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: _pickEndTime,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "End Time",
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? AppColors.darkTextSecondary : AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.alarm_on,
                                size: 16,
                                color: isDark ? AppColors.primaryLight : AppTheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  BatchTimingHelper.formatTimeOfDay(_endTime),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.darkTextPrimary : AppColors.deepInk,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_timeRangeError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 2),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 14, color: AppColors.error),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _timeRangeError!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 2),
                child: Text(
                  "Lecture duration: $durationHours hrs ($_durationMinutes mins)",
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppColors.darkTextMuted : AppTheme.textMuted,
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Days Section
            Text(
              "2. Select Class Days",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            // Quick Presets
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPresetChip("Mon-Sat", isDark),
                  const SizedBox(width: 6),
                  _buildPresetChip("Mon-Fri", isDark),
                  const SizedBox(width: 6),
                  _buildPresetChip("Daily", isDark),
                  const SizedBox(width: 6),
                  _buildPresetChip("Weekend", isDark),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Day circles
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: BatchTimingHelper.allDaysOfWeek.map((day) {
                  final isSelected = _selectedDays.contains(day);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: InkWell(
                      onTap: () => _toggleDay(day),
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primary
                              : (isDark ? AppColors.darkSurface : AppTheme.surface),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primary
                                : (isDark ? AppColors.darkBorder : AppTheme.border),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Text(
                          day.substring(0, 1),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.black
                                : (isDark ? AppColors.darkTextSecondary : AppTheme.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: (_timeRangeError == null && _overlapConflict == null)
                ? AppTheme.primary
                : Colors.grey,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: (_timeRangeError != null || _overlapConflict != null)
              ? null
              : () => Navigator.pop(context, _formattedTiming),
          child: const Text(
            "Apply Schedule",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildPresetChip(String label, bool isDark) {
    final isSelected = BatchTimingHelper.formatDays(_selectedDays) == label;
    return InkWell(
      onTap: () => _applyPreset(label),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.primary.withValues(alpha: 0.25) : AppTheme.primary.withValues(alpha: 0.2))
              : (isDark ? AppColors.darkSurface : AppTheme.surface),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary
                : (isDark ? AppColors.darkBorder : AppTheme.border),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? (isDark ? AppColors.primaryLight : AppTheme.primary)
                : (isDark ? AppColors.darkTextSecondary : AppTheme.textSecondary),
          ),
        ),
      ),
    );
  }
}
