import 'package:flutter/material.dart';

class ScheduleItem {
  final String title;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final Color? color;
  final String? location;
  final String? instructor;

  const ScheduleItem({
    required this.title,
    required this.startTime,
    required this.endTime,
    this.color,
    this.location,
    this.instructor,
  });

  // Calculate duration in minutes
  int get durationMinutes {
    int startMinutes = startTime.hour * 60 + startTime.minute;
    int endMinutes = endTime.hour * 60 + endTime.minute;

    return endMinutes - startMinutes;
  }

  // Format time as string (e.g., "9:30 AM")
  String formatTime(TimeOfDay time) {
    final hours = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minutes = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';

    return '$hours:$minutes $period';
  }

  // Get formatted time range
  String get timeRange {
    return '${formatTime(startTime)} - ${formatTime(endTime)}';
  }
}
