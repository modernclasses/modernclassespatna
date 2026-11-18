import 'package:flutter/material.dart';

class SlotValidationResult {
  final bool isValid;
  final String message;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final List<String> days;
  final bool isPastEndTime;
  final bool isTooEarly;
  final int minutesRemainingInSlot;
  final String permittedWindowDescription;

  const SlotValidationResult({
    required this.isValid,
    required this.message,
    this.startTime,
    this.endTime,
    this.days = const [],
    this.isPastEndTime = false,
    this.isTooEarly = false,
    this.minutesRemainingInSlot = 0,
    this.permittedWindowDescription = '',
  });
}

/// Helper for parsing, formatting, and validating batch lecture timings.
class BatchTimingHelper {
  BatchTimingHelper._();

  static const List<String> allDaysOfWeek = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// Validates that end time is strictly after start time within a single day.
  /// Returns null if valid, or a descriptive error message if invalid.
  static String? validateTimeRange(TimeOfDay start, TimeOfDay end) {
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    if (endMinutes <= startMinutes) {
      return 'End time must be after start time.';
    }
    return null;
  }

  /// Checks if a candidate timing string duplicates an existing timing slot.
  static bool isDuplicateTiming(String candidate, Iterable<String> existingTimings) {
    final cleanCandidate = candidate.trim().toLowerCase();
    return existingTimings.any((e) => e.trim().toLowerCase() == cleanCandidate);
  }

  /// Checks whether two lecture timing slots overlap in both scheduled days and hours.
  /// For example, "04:00 PM - 06:00 PM (Mon-Sat)" and "04:30 PM - 06:00 PM (Mon-Sat)" overlap.
  static bool doTimingsOverlap(String timingA, String timingB) {
    final cleanA = timingA.trim();
    final cleanB = timingB.trim();
    if (cleanA.isEmpty || cleanB.isEmpty) return false;

    // Fast-path exact match
    if (cleanA.toLowerCase() == cleanB.toLowerCase()) return true;

    final a = parseTiming(cleanA);
    final b = parseTiming(cleanB);

    // 1. Check if they share any active days of the week
    final hasCommonDay = a.days.any((d) => b.days.contains(d));
    if (!hasCommonDay) return false;

    // 2. Check time interval in minutes from midnight
    final aStart = a.start.hour * 60 + a.start.minute;
    var aEnd = a.end.hour * 60 + a.end.minute;
    if (aEnd <= aStart) {
      // Slot crosses midnight
      aEnd += 24 * 60;
    }

    final bStart = b.start.hour * 60 + b.start.minute;
    var bEnd = b.end.hour * 60 + b.end.minute;
    if (bEnd <= bStart) {
      bEnd += 24 * 60;
    }

    // Two intervals [aStart, aEnd) and [bStart, bEnd) overlap iff:
    // max(aStart, bStart) < min(aEnd, bEnd)
    final maxStart = aStart > bStart ? aStart : bStart;
    final minEnd = aEnd < bEnd ? aEnd : bEnd;

    return maxStart < minEnd;
  }

  /// Finds and returns the first overlapping timing slot from [existingTimings],
  /// or null if none overlap.
  static String? findOverlappingTiming(String candidate, Iterable<String> existingTimings) {
    final cleanCandidate = candidate.trim();
    if (cleanCandidate.isEmpty) return null;

    for (final existing in existingTimings) {
      if (existing.trim().isNotEmpty && doTimingsOverlap(cleanCandidate, existing)) {
        return existing;
      }
    }
    return null;
  }

  /// Returns true if [candidate] overlaps with any timing in [existingTimings].
  static bool isOverlappingTiming(String candidate, Iterable<String> existingTimings) {
    return findOverlappingTiming(candidate, existingTimings) != null;
  }

  /// Validates candidate against existing timings for the same course.
  /// Returns null if valid, or a descriptive error message if overlapping.
  static String? validateNoSlotOverlap(String candidate, Iterable<String> existingTimings) {
    final conflict = findOverlappingTiming(candidate, existingTimings);
    if (conflict != null) {
      return 'Timing overlaps with an existing course slot ($conflict). Course slots cannot have overlapping class hours on the same days.';
    }
    return null;
  }

  /// Format TimeOfDay to "hh:mm a" (e.g. 08:00 AM)
  static String formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  /// Format days list to friendly string e.g. "Mon-Sat", "Mon-Fri", "Daily", or "Mon, Wed, Fri"
  static String formatDays(List<String> days) {
    if (days.isEmpty) return 'Mon-Sat';
    if (days.length == 7) return 'Daily';
    if (days.length == 6 && !days.contains('Sun')) return 'Mon-Sat';
    if (days.length == 5 && !days.contains('Sat') && !days.contains('Sun')) {
      return 'Mon-Fri';
    }
    if (days.length == 2 && days.contains('Sat') && days.contains('Sun')) {
      return 'Weekend';
    }
    return days.join(', ');
  }

  /// Combine times and days into standard batch timing string
  /// e.g. "08:00 AM - 10:00 AM (Mon-Sat)"
  static String buildTimingString({
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required List<String> days,
  }) {
    final startStr = formatTimeOfDay(startTime);
    final endStr = formatTimeOfDay(endTime);
    final daysStr = formatDays(days);
    return '$startStr - $endStr ($daysStr)';
  }

  /// Parse a time string like "08:00 AM" into TimeOfDay
  static TimeOfDay? parseTimeString(String raw) {
    try {
      final clean = raw.trim().toUpperCase();
      final isPm = clean.contains('PM');
      final isAm = clean.contains('AM');
      final parts = clean
          .replaceAll('AM', '')
          .replaceAll('PM', '')
          .trim()
          .split(':');
      if (parts.length != 2) return null;

      var hour = int.parse(parts[0].trim());
      final minute = int.parse(parts[1].trim());

      if (isPm && hour < 12) hour += 12;
      if (isAm && hour == 12) hour = 0;

      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }

  /// Parse days from timing string (e.g. "Mon-Sat", "Mon, Wed, Fri", "Daily")
  static List<String> parseDaysFromTiming(String timing) {
    if (timing.contains('Daily') || timing.contains('Mon-Sun')) {
      return List.from(allDaysOfWeek);
    }
    if (timing.contains('Mon-Sat')) {
      return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    }
    if (timing.contains('Mon-Fri')) {
      return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    }
    if (timing.contains('Weekend') || timing.contains('Sat-Sun')) {
      return ['Sat', 'Sun'];
    }

    final matched = <String>[];
    for (final day in allDaysOfWeek) {
      if (timing.contains(day)) matched.add(day);
    }
    return matched.isNotEmpty
        ? matched
        : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  }

  /// Parse entire timing string into components
  static ({TimeOfDay start, TimeOfDay end, List<String> days}) parseTiming(
    String raw,
  ) {
    final defaultStart = const TimeOfDay(hour: 8, minute: 0);
    final defaultEnd = const TimeOfDay(hour: 10, minute: 0);
    final defaultDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    if (raw.isEmpty) {
      return (start: defaultStart, end: defaultEnd, days: defaultDays);
    }

    try {
      final parts = raw.split('-');
      if (parts.length >= 2) {
        final startRaw = parts[0].trim();
        final endWithDays = parts[1].trim();

        final start = parseTimeString(startRaw) ?? defaultStart;
        var end = defaultEnd;

        // End part might have "(Mon-Sat)" attached
        if (endWithDays.contains('(')) {
          final endRaw = endWithDays
              .substring(0, endWithDays.indexOf('('))
              .trim();
          end = parseTimeString(endRaw) ?? defaultEnd;
        } else {
          end = parseTimeString(endWithDays) ?? defaultEnd;
        }

        final days = parseDaysFromTiming(raw);
        return (start: start, end: end, days: days);
      }
    } catch (_) {}

    return (start: defaultStart, end: defaultEnd, days: defaultDays);
  }

  /// Returns current time in Asia/Kolkata (IST = UTC + 5h30m)
  static DateTime getNowInKolkata([DateTime? source]) {
    final base = (source ?? DateTime.now()).toUtc();
    return base.add(const Duration(hours: 5, minutes: 30));
  }

  /// Checks if current time is within teacher's admin-assigned slot.
  /// Enforces strict Asia/Kolkata timezone schedule compliance:
  /// - Early setup buffer: default 15 minutes before slot start.
  /// - Post-end grace: default 0 minutes (strictly blocks starting after slot end).
  static SlotValidationResult validateCurrentTimeSlot(
    String timing, {
    int earlyBufferMinutes = 15,
    int postEndGraceMinutes = 0,
    DateTime? customNow,
  }) {
    if (timing.trim().isEmpty) {
      return const SlotValidationResult(
        isValid: true,
        message: 'No slot restrictions configured for this batch.',
      );
    }

    final parsed = parseTiming(timing);
    final nowIst = getNowInKolkata(customNow);

    // 1. Check Day of Week in Asia/Kolkata
    final currentDayName = allDaysOfWeek[(nowIst.weekday - 1) % 7];
    if (!parsed.days.contains(currentDayName)) {
      return SlotValidationResult(
        isValid: false,
        message:
            'This batch is scheduled for ${formatDays(parsed.days)}. Today is $currentDayName (IST / Asia/Kolkata).',
        startTime: parsed.start,
        endTime: parsed.end,
        days: parsed.days,
        permittedWindowDescription:
            '${formatDays(parsed.days)} • ${formatTimeOfDay(parsed.start)} - ${formatTimeOfDay(parsed.end)} IST',
      );
    }

    // 2. Compute minutes for start, end, and current time in IST
    final startMinutes = parsed.start.hour * 60 + parsed.start.minute;
    var endMinutes = parsed.end.hour * 60 + parsed.end.minute;
    var currentMinutes = nowIst.hour * 60 + nowIst.minute;

    // Handle overnight schedules crossing midnight (e.g. 10:00 PM - 02:00 AM)
    if (endMinutes < startMinutes) {
      endMinutes += 24 * 60;
      if (currentMinutes < startMinutes) {
        currentMinutes += 24 * 60;
      }
    }

    final permittedWindow =
        '${formatTimeOfDay(parsed.start)} - ${formatTimeOfDay(parsed.end)} IST (Asia/Kolkata)';

    // Strict end check: cannot start AFTER scheduled slot end (+ postEndGraceMinutes)
    if (currentMinutes > endMinutes + postEndGraceMinutes) {
      final elapsedSinceEnd = currentMinutes - endMinutes;
      return SlotValidationResult(
        isValid: false,
        isPastEndTime: true,
        message:
            'Class slot ended at ${formatTimeOfDay(parsed.end)} IST ($elapsedSinceEnd minutes ago). Starting a new broadcast after the scheduled slot has ended is not permitted.',
        startTime: parsed.start,
        endTime: parsed.end,
        days: parsed.days,
        minutesRemainingInSlot: 0,
        permittedWindowDescription: permittedWindow,
      );
    }

    // Early start check: only allow within earlyBufferMinutes
    if (currentMinutes < startMinutes - earlyBufferMinutes) {
      final diff = startMinutes - currentMinutes;
      final earlyAllowedHour = (startMinutes - earlyBufferMinutes) ~/ 60;
      final earlyAllowedMinute = (startMinutes - earlyBufferMinutes) % 60;
      final earlyAllowedTime = TimeOfDay(
        hour: earlyAllowedHour % 24,
        minute: earlyAllowedMinute,
      );

      return SlotValidationResult(
        isValid: false,
        isTooEarly: true,
        message:
            'Class slot begins at ${formatTimeOfDay(parsed.start)} IST (in $diff minutes). Setup permitted starting at ${formatTimeOfDay(earlyAllowedTime)} IST.',
        startTime: parsed.start,
        endTime: parsed.end,
        days: parsed.days,
        minutesRemainingInSlot: endMinutes - currentMinutes,
        permittedWindowDescription: permittedWindow,
      );
    }

    final remaining = endMinutes - currentMinutes;
    return SlotValidationResult(
      isValid: true,
      message: 'Active slot verified: $permittedWindow',
      startTime: parsed.start,
      endTime: parsed.end,
      days: parsed.days,
      minutesRemainingInSlot: remaining,
      permittedWindowDescription: permittedWindow,
    );
  }

  /// Validates an optional RTMPS/RTMP streaming URL.
  /// Returns null if empty/null (optional) or valid, or a descriptive error message if invalid.
  static String? validateRtmpsUrl(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'Enter a valid RTMPS URL (e.g. rtmps://live.cloudflare.com/live)';
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'rtmps' && scheme != 'rtmp') {
      return 'RTMPS URL must start with rtmps:// or rtmp://';
    }
    return null;
  }
}
