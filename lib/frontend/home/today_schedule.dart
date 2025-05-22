import 'dart:ui';
import 'dart:math'; // Added for max function in dialog

import 'package:connect_ed_2/classes/calendar_item.dart';
import 'package:connect_ed_2/classes/schedule_item.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TodayScheduleDialog extends StatefulWidget {
  final Map<DateTime, CalendarItem>? calendarData;
  final DateTime dateToShow;

  const TodayScheduleDialog({Key? key, required this.calendarData, required this.dateToShow}) : super(key: key);

  @override
  State<TodayScheduleDialog> createState() => _TodayScheduleDialogState();
}

class _TodayScheduleDialogState extends State<TodayScheduleDialog> {
  List<ScheduleItem> _scheduleItems = [];
  late TimeOfDay _scheduleStartTime;
  late TimeOfDay _scheduleEndTime;
  final DateFormat _dayFormatter = DateFormat('EEE, MMM d');

  static const double HOUR_HEIGHT = 57.0;

  @override
  void initState() {
    super.initState();
    _prepareScheduleData();
  }

  void _prepareScheduleData() {
    _scheduleItems = _getScheduleForDate(widget.dateToShow);
    _updateScheduleTimeRange();
  }

  List<ScheduleItem> _getScheduleForDate(DateTime date) {
    if (widget.calendarData == null) return [];
    final normalizedDate = DateTime(date.year, date.month, date.day);
    if (widget.calendarData!.containsKey(normalizedDate)) {
      var items = List<ScheduleItem>.from(widget.calendarData![normalizedDate]!.schedule);
      items.sort((a, b) {
        final aMinutes = a.startTime.hour * 60 + a.startTime.minute;
        final bMinutes = b.startTime.hour * 60 + b.startTime.minute;
        return aMinutes.compareTo(bMinutes);
      });
      return items;
    }
    return [];
  }

  void _updateScheduleTimeRange() {
    if (_scheduleItems.isEmpty) {
      _scheduleStartTime = const TimeOfDay(hour: 8, minute: 0);
      _scheduleEndTime = const TimeOfDay(hour: 17, minute: 0);
      return;
    }

    TimeOfDay earliest = const TimeOfDay(hour: 23, minute: 59);
    TimeOfDay latest = const TimeOfDay(hour: 0, minute: 0);

    for (final item in _scheduleItems) {
      if (item.startTime.hour < earliest.hour ||
          (item.startTime.hour == earliest.hour && item.startTime.minute < earliest.minute)) {
        earliest = item.startTime;
      }
      if (item.endTime.hour > latest.hour ||
          (item.endTime.hour == latest.hour && item.endTime.minute > latest.minute)) {
        latest = item.endTime;
      }
    }
    _scheduleStartTime = TimeOfDay(hour: (earliest.hour).clamp(0, 23), minute: 0);
    _scheduleEndTime = TimeOfDay(hour: (latest.hour + 1).clamp(0, 23), minute: 59);

    // Ensure end time is at least one hour after start time if they are too close
    if (_scheduleStartTime.hour == _scheduleEndTime.hour && _scheduleStartTime.minute >= _scheduleEndTime.minute) {
      _scheduleEndTime = TimeOfDay(hour: (_scheduleStartTime.hour + 1).clamp(0, 23), minute: _scheduleStartTime.minute);
    }
    if (_scheduleStartTime.hour > _scheduleEndTime.hour) {
      // Should not happen with current logic, but as a safeguard
      _scheduleEndTime = TimeOfDay(hour: _scheduleStartTime.hour, minute: 59); // Make it end of start hour
    }
  }

  List<Widget> _buildTimeSlots() {
    List<Widget> slots = [];
    if (_scheduleStartTime.hour > _scheduleEndTime.hour &&
        !(_scheduleStartTime.hour == 23 && _scheduleEndTime.hour == 0))
      return slots;

    for (int hour = _scheduleStartTime.hour; hour <= _scheduleEndTime.hour; hour++) {
      final String timeString;
      if (hour == 0 || hour == 12) {
        timeString = '12';
      } else if (hour < 12) {
        timeString = '$hour';
      } else {
        timeString = '${hour - 12}';
      }

      final String period;
      if (hour == 0 || (hour < 12)) {
        period = 'AM';
      } else if (hour == 12) {
        period = 'PM';
      } else if (hour == 24) {
        // Should not happen with current logic but good for robustness
        period = 'AM';
      } else {
        period = 'PM';
      }

      slots.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 40.0), // Matches calendar.dart
          child: Flex(
            direction: Axis.horizontal,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 1,
                fit: FlexFit.tight,
                child: Text(
                  timeString,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(127)),
                ),
              ),
              Flexible(
                flex: 2,
                fit: FlexFit.tight,
                child: Text(
                  period,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(127)),
                ),
              ),
              Flexible(flex: 15, child: Divider(color: Theme.of(context).colorScheme.onSurface.withAlpha(50))),
            ],
          ),
        ),
      );
    }
    return slots;
  }

  Widget _buildScheduleItemWidget(ScheduleItem item) {
    final startMinutes = item.startTime.hour * 60 + item.startTime.minute;
    final scheduleStartMinutes = _scheduleStartTime.hour * 60 + _scheduleStartTime.minute;

    final double topPosition = ((startMinutes - scheduleStartMinutes) * (HOUR_HEIGHT / 60.0)) + 7.5;
    final double height = max(item.durationMinutes * (HOUR_HEIGHT / 60.0), 24.0);

    return Positioned(
      top: topPosition,
      left: 0,
      right: 0,
      child: Flex(
        direction: Axis.horizontal,
        children: [
          const Flexible(child: SizedBox(), flex: 3, fit: FlexFit.tight),
          Flexible(
            flex: 15,
            fit: FlexFit.tight,
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withAlpha(220),
                border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(item.timeRange, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onPrimary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogScheduleView() {
    if (_scheduleItems.isEmpty) {
      return Container(
        // No change to empty view, it's small enough
        height: 100,
        alignment: Alignment.center,
        child: Text(
          "No schedule for today",
          style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
        ),
      );
    }

    final int totalScheduleHours = max(1, _scheduleEndTime.hour - _scheduleStartTime.hour + 1);
    // This is the total height required by the stack content.
    final double calculatedStackHeight = totalScheduleHours * HOUR_HEIGHT + 40;
    List<Widget> timeSlots = _buildTimeSlots();

    // Wrap the potentially tall content in a SingleChildScrollView.
    // This allows the content to scroll if calculatedStackHeight is larger than
    // the height allocated by the SizedBox in AlertDialog.content.
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16), // Added horizontal padding
        width: double.infinity,
        height: calculatedStackHeight, // The actual height of the scrollable content
        child: Stack(
          fit: StackFit.loose,
          clipBehavior: Clip.none, // Keep as none, scrolling handles visibility
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: timeSlots),
            ..._scheduleItems.map((item) => _buildScheduleItemWidget(item)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return AlertDialog(
      title: Text(
        _dayFormatter.format(widget.dateToShow),
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
      ), // This acts as the persistent header
      titlePadding: EdgeInsets.all(16), // Control padding around the title
      insetPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0), // Control padding around the dialog
      contentPadding: EdgeInsets.zero, // Remove default padding to control it with SizedBox
      content: SizedBox(
        // Width will be constrained by AlertDialog's insetPadding and its default behavior to expand.
        // We only explicitly set the height for the content area.
        width: double.maxFinite, // Instructs SizedBox to be as wide as parent allows
        height: screenHeight * 0.5, // Set desired max height for the content area
        child: _buildDialogScheduleView(), // This now returns a scrollable view
      ),
      actions: [TextButton(child: const Text("Close"), onPressed: () => Navigator.of(context).pop())],
      // AlertDialog's own scrollable property can be true if title + content + actions
      // together might overflow the screen. For now, we focus on content scrolling.
      // scrollable: true,
    );
  }
}
