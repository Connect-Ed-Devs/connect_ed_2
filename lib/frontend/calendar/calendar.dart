import 'dart:math';

import 'package:connect_ed_2/classes/calendar_item.dart';
import 'package:connect_ed_2/classes/schedule_item.dart';
import 'package:connect_ed_2/frontend/calendar/calendar_app_bar.dart';
import 'package:connect_ed_2/requests/cache_manager.dart';
import 'package:connect_ed_2/requests/calendar_requests.dart';
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

  // Data variables
  Map<DateTime, CalendarItem>? _calendarData;
  Future<Map<DateTime, CalendarItem>>? _calendarDataFuture;
  bool _isLoading = true;

  // Time range for the schedule display
  late TimeOfDay _scheduleStartTime;
  late TimeOfDay _scheduleEndTime;

  @override
  void initState() {
    super.initState();
    _loadCalendarData();
  }

  void _loadCalendarData() {
    // Check cache status and load data accordingly
    final cacheStatus = calendarManager.getCacheStatus();
    switch (cacheStatus) {
      case CacheStatus.fresh:
        // Use cached data directly
        setState(() {
          _calendarData = calendarManager.getCachedData();
          _isLoading = false;
          _updateScheduleTimeRange();
        });
        break;

      case CacheStatus.stale:
        // Show cached data immediately, but also fetch fresh data
        setState(() {
          _calendarData = calendarManager.getCachedData();
          _isLoading = false;
          _updateScheduleTimeRange();

          // Fetch updated data in background
          _calendarDataFuture = calendarManager.fetchData() as Future<Map<DateTime, CalendarItem>>;
          _calendarDataFuture!
              .then((newData) {
                setState(() {
                  _calendarData = newData;
                  _updateScheduleTimeRange();
                });
              })
              .catchError((error) {
                // If error occurs, we keep using cached data
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Could not update calendar data: ${error.toString()}')));
              });
        });
        break;

      case CacheStatus.expired:
        // Use FutureBuilder to show loading state
        setState(() {
          _isLoading = true;
          _calendarDataFuture = calendarManager.fetchData() as Future<Map<DateTime, CalendarItem>>;
          _calendarDataFuture!
              .then((data) {
                setState(() {
                  _calendarData = data;
                  _isLoading = false;
                  _updateScheduleTimeRange();
                });
              })
              .catchError((error) {
                setState(() {
                  _isLoading = false;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Failed to load calendar data: ${error.toString()}')));
                });
              });
        });
        break;
    }
  }

  // Get schedule items for the selected date
  List<ScheduleItem> _getScheduleForSelectedDate() {
    if (_calendarData == null) return [];

    // Create a normalized date key (without time component)
    final normalizedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    if (_calendarData!.containsKey(normalizedDate)) {
      return _calendarData![normalizedDate]!.schedule;
    }
    return [];
  }

  void _updateScheduleTimeRange() {
    final scheduleItems = _getScheduleForSelectedDate();

    if (scheduleItems.isEmpty) {
      // Default time range for empty schedule
      _scheduleStartTime = const TimeOfDay(hour: 8, minute: 0);
      _scheduleEndTime = const TimeOfDay(hour: 17, minute: 0);
      return;
    }

    // Find earliest start time and latest end time
    TimeOfDay earliest = const TimeOfDay(hour: 23, minute: 59);
    TimeOfDay latest = const TimeOfDay(hour: 0, minute: 0);

    for (final item in scheduleItems) {
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
    _scheduleStartTime = TimeOfDay(hour: (earliest.hour).clamp(0, 23), minute: 0);
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
      // Update schedule time range based on the new selected date
      _updateScheduleTimeRange();
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
          padding: const EdgeInsets.only(bottom: 40.0),
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
    final scheduleItems = _getScheduleForSelectedDate();

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (scheduleItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 48.0),
          child: Text(
            "No schedule for this day",
            style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Time slots as the background
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: _buildTimeSlots()),

        // Schedule items overlayed on time slots
        ...scheduleItems.map((item) => _buildScheduleItemWidget(item)).toList(),
      ],
    );
  }

  // Build individual schedule item widget
  Widget _buildScheduleItemWidget(ScheduleItem item) {
    // Calculate position and size
    final startMinutes = item.startTime.hour * 60 + item.startTime.minute;
    final scheduleStartMinutes = _scheduleStartTime.hour * 60;

    // Constants for layout
    const double HOUR_HEIGHT = 57; // Height of each hour in the schedule

    // Calculate top position with offset adjustment
    final double topPosition = (startMinutes - scheduleStartMinutes) * (HOUR_HEIGHT / 60.0) + 7.5;

    // Calculate height based on duration, with a larger minimum height
    final double height = max(item.durationMinutes * (HOUR_HEIGHT / 60.0), 24.0);

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

  Widget _buildScheduleSection() {
    // Use a smaller fixed height for loading or empty states
    final scheduleItems = _getScheduleForSelectedDate();

    // Use a default height of 100 pixels for empty states or loading
    double totalScheduleHeight = 100.0;

    // Only calculate full height when we have schedule items
    if (!_isLoading && scheduleItems.isNotEmpty) {
      final int totalScheduleHours = _scheduleEndTime.hour - _scheduleStartTime.hour + 1;
      totalScheduleHeight = totalScheduleHours * 57.0; // Match your HOUR_HEIGHT constant
    }

    return SliverStickyHeader(
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

              // Show the schedule with appropriate height
              SizedBox(height: totalScheduleHeight, width: double.infinity, child: _buildScheduleItems()),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          // Force refresh data
          setState(() {
            _isLoading = true;
            _calendarDataFuture = calendarManager.fetchData() as Future<Map<DateTime, CalendarItem>>;
          });

          try {
            final newData = await _calendarDataFuture!;
            setState(() {
              _calendarData = newData;
              _isLoading = false;
              _updateScheduleTimeRange();
            });
          } catch (e) {
            setState(() {
              _isLoading = false;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Failed to refresh data: ${e.toString()}')));
            });
          }
        },
        child: CustomScrollView(
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

            // Schedule section
            _buildScheduleSection(),

            // Add extra space at the bottom to ensure enough scrollable area
            SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).size.height * 0.2)),
          ],
        ),
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
