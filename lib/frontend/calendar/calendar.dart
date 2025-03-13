import 'dart:math';

import 'package:connect_ed_2/classes/schedule_item.dart';
import 'package:connect_ed_2/frontend/calendar/calendar_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:intl/intl.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> with TickerProviderStateMixin {
  // Controller to help manage scrolling
  final ScrollController _scrollController = ScrollController();

  // Track current month and selected date
  DateTime _currentMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();

  // Month formatter
  final DateFormat _monthFormatter = DateFormat('MMMM');
  final DateFormat _dateFormatter = DateFormat('MMMM dd, yyyy');

  // Mock schedule data
  late List<ScheduleItem> _scheduleItems;

  // Time range for the schedule display
  late TimeOfDay _scheduleStartTime;
  late TimeOfDay _scheduleEndTime;

  @override
  void initState() {
    super.initState();
    _initializeScheduleData();
  }

  void _initializeScheduleData() {
    // Create a mock schedule
    _scheduleItems = [
      ScheduleItem(
        title: 'Introduction to Computer Science',
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 10, minute: 30),
        location: 'Room 101',
        instructor: 'Dr. Smith',
        color: Colors.blue.shade100,
      ),
      ScheduleItem(
        title: 'Lunch Break',
        startTime: const TimeOfDay(hour: 11, minute: 0),
        endTime: const TimeOfDay(hour: 12, minute: 0),
        color: Colors.grey.shade200,
      ),
      ScheduleItem(
        title: 'Advanced Mathematics',
        startTime: const TimeOfDay(hour: 13, minute: 0),
        endTime: const TimeOfDay(hour: 14, minute: 30),
        location: 'Room 203',
        instructor: 'Prof. Johnson',
        color: Colors.green.shade100,
      ),
      ScheduleItem(
        title: 'Study Group: Physics',
        startTime: const TimeOfDay(hour: 15, minute: 0),
        endTime: const TimeOfDay(hour: 16, minute: 0),
        location: 'Library',
        color: Colors.orange.shade100,
      ),
    ];

    // Determine schedule display range (with padding)
    _determineScheduleTimeRange();
  }

  void _determineScheduleTimeRange() {
    // Find earliest start time and latest end time
    TimeOfDay earliest = const TimeOfDay(hour: 23, minute: 59);
    TimeOfDay latest = const TimeOfDay(hour: 0, minute: 0);

    for (final item in _scheduleItems) {
      // Compare and update earliest
      if (item.startTime.hour < earliest.hour ||
          (item.startTime.hour == earliest.hour && item.startTime.minute < earliest.minute)) {
        earliest = item.startTime;
      }

      // Compare and update latest
      if (item.endTime.hour > latest.hour ||
          (item.endTime.hour == latest.hour && item.endTime.minute > latest.minute)) {
        latest = item.endTime;
      }
    }

    // Add padding (1 hour before and after)
    _scheduleStartTime = TimeOfDay(hour: (earliest.hour - 1).clamp(0, 23), minute: 0);
    _scheduleEndTime = TimeOfDay(hour: (latest.hour + 1).clamp(0, 23), minute: 59);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Navigate to previous month
  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);

      // Keep the same day if possible, otherwise set to last day of month
      int lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
      int newDay = _selectedDate.day > lastDayOfMonth ? lastDayOfMonth : _selectedDate.day;
      _selectedDate = DateTime(_currentMonth.year, _currentMonth.month, newDay);
    });
  }

  // Navigate to next month
  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);

      // Keep the same day if possible, otherwise set to last day of month
      int lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
      int newDay = _selectedDate.day > lastDayOfMonth ? lastDayOfMonth : _selectedDate.day;
      _selectedDate = DateTime(_currentMonth.year, _currentMonth.month, newDay);
    });
  }

  // Update the selected date (called from calendar widget)
  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
      // If the date is from a different month, update the current month
      if (_selectedDate.month != _currentMonth.month) {
        _currentMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
      }
    });
  }

  // Build the time slots for the schedule
  List<Widget> _buildTimeSlots() {
    List<Widget> slots = [];

    // Generate time slots from start to end time
    for (int hour = _scheduleStartTime.hour; hour <= _scheduleEndTime.hour; hour++) {
      final timeString = hour <= 12 ? (hour == 0 ? '12' : '$hour') : '${hour - 12}';
      final period = hour < 12 ? 'AM' : 'PM';

      slots.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 32.0),
          child: Flex(
            direction: Axis.horizontal,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 1,
                child: Text(
                  timeString,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(127)),
                ),
                fit: FlexFit.tight,
              ),
              Flexible(
                flex: 2,
                child: Text(
                  period,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withAlpha(127)),
                ),
                fit: FlexFit.tight,
              ),
              Flexible(flex: 15, child: Divider(color: Theme.of(context).colorScheme.onSurface.withAlpha(50))),
            ],
          ),
        ),
      );
    }

    return slots;
  }

  // Build the schedule items
  Widget _buildScheduleItems() {
    return Stack(
      children: [
        // Time slots as the background
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: _buildTimeSlots()),

        // Schedule items overlayed on time slots
        ..._scheduleItems.map((item) => _buildScheduleItemWidget(item)).toList(),
      ],
    );
  }

  // Build individual schedule item widget
  Widget _buildScheduleItemWidget(ScheduleItem item) {
    // Calculate position and size
    final startMinutes = item.startTime.hour * 60 + item.startTime.minute;
    final scheduleStartMinutes = _scheduleStartTime.hour * 60;

    // Constants for layout
    const double HOUR_HEIGHT = 49; // Height of each hour in the schedule

    // Calculate top position with offset adjustment
    final double topPosition = (startMinutes - scheduleStartMinutes) * (HOUR_HEIGHT / 60.0) + 7.5;

    // Calculate height based on duration, with a larger minimum height
    final double height = max(item.durationMinutes * (HOUR_HEIGHT / 60.0), 36.0);

    return Positioned(
      top: topPosition,
      left: 0, // Align with the start of divider lines
      right: 0,
      child: Flex(
        direction: Axis.horizontal,
        children: [
          Flexible(child: SizedBox(), flex: 3, fit: FlexFit.tight),
          Flexible(
            flex: 15,
            fit: FlexFit.tight,
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary.withAlpha(190),
                border: Border.all(color: Theme.of(context).colorScheme.secondary, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(item.timeRange, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate the total schedule height
    final int totalScheduleHours = _scheduleEndTime.hour - _scheduleStartTime.hour + 1;
    final double totalScheduleHeight = totalScheduleHours * 49.0; // Match your HOUR_HEIGHT constant

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Use the specialized calendar app bar
          CECalendarAppBar(
            title: _monthFormatter.format(_currentMonth),
            collapsedTitle: _dateFormatter.format(_selectedDate),
            currentMonth: _currentMonth,
            selectedDate: _selectedDate,
            onDateSelected: _onDateSelected,
            onPreviousMonth: _previousMonth,
            onNextMonth: _nextMonth,
            scrollController: _scrollController,
          ),

          SliverStickyHeader(
            header: Container(
              padding: const EdgeInsets.only(top: 30, left: 16.0),
              color: Theme.of(context).colorScheme.surface,
              child: const Text("Schedule", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
            ),
            sliver: SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // Just show the schedule directly - let the main CustomScrollView handle scrolling
                    SizedBox(height: totalScheduleHeight, width: double.infinity, child: _buildScheduleItems()),
                  ],
                ),
              ),
            ),
          ),
          // Content below calendar

          // Add extra space at the bottom to ensure enough scrollable area
          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).size.height * 0.2)),
        ],
      ),
    );
  }
}

// Create a CalendarMonthProvider to pass currentMonth and selectedDate to CalendarWidget
class CalendarMonthProvider extends InheritedWidget {
  final DateTime currentMonth;
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;

  const CalendarMonthProvider({
    Key? key,
    required this.currentMonth,
    required this.selectedDate,
    required this.onDateSelected,
    required Widget child,
  }) : super(key: key, child: child);

  static CalendarMonthProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CalendarMonthProvider>();
  }

  @override
  bool updateShouldNotify(CalendarMonthProvider oldWidget) {
    return currentMonth != oldWidget.currentMonth || selectedDate != oldWidget.selectedDate;
  }
}

// Custom icon button with opacity animation instead of splash
class OpacityIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;
  final double size;

  const OpacityIconButton({Key? key, required this.icon, required this.onPressed, this.color, this.size = 24.0})
    : super(key: key);

  @override
  State<OpacityIconButton> createState() => _OpacityIconButtonState();
}

class _OpacityIconButtonState extends State<OpacityIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 50),
          opacity: _isPressed ? 0.4 : 1.0,
          child: Icon(widget.icon, color: widget.color ?? Theme.of(context).iconTheme.color, size: widget.size),
        ),
      ),
    );
  }
}
