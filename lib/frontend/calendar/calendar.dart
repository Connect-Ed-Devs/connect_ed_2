import 'dart:math';

import 'package:connect_ed_2/classes/assessment.dart';
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

  // Page controller for horizontal day swiping
  late PageController _dayPageController;

  // Track current month and selected date
  DateTime _currentMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();

  // Month formatter
  final DateFormat _monthFormatter = DateFormat('MMMM');
  final DateFormat _dateFormatter = DateFormat('MMMM dd, yyyy');
  final DateFormat _dayFormatter = DateFormat('EEE, MMM d'); // For day display

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

    // Initialize page controller with initial date
    _dayPageController = PageController(initialPage: 500); // Start at middle to allow for past/future swiping

    _loadCalendarData();
  }

  // Calculate page index from a date
  int _getPageIndexFromDate(DateTime date) {
    // Calculate the difference in days between the date and today
    return 500 + date.difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)).inDays;
  }

  // Calculate date from page index
  DateTime _getDateFromPageIndex(int index) {
    // Page 500 is today, each page is +/- 1 day
    return DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).add(Duration(days: index - 500));
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

  // Get assessments for the selected date
  List<Assessment> _getAssessmentsForSelectedDate() {
    if (_calendarData == null) return [];

    // Create a normalized date key (without time component)
    final normalizedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    if (_calendarData!.containsKey(normalizedDate)) {
      return _calendarData![normalizedDate]!.assessments;
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
    _dayPageController.dispose();
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

  void _updateSelectedDateFromPage(int pageIndex) {
    final newDate = _getDateFromPageIndex(pageIndex);

    // Only update if the date actually changed
    if (newDate.year != _selectedDate.year ||
        newDate.month != _selectedDate.month ||
        newDate.day != _selectedDate.day) {
      setState(() {
        _selectedDate = newDate;

        // If the date is from a different month, update the current month
        if (_selectedDate.month != _currentMonth.month) {
          _currentMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
        }

        // Update schedule time range based on the new selected date
        _updateScheduleTimeRange();
      });
    }
  }

  // Update the selected date (called from calendar widget)
  void _onDateSelected(DateTime date) {
    // If date is different, update it
    if (date.year != _selectedDate.year || date.month != _selectedDate.month || date.day != _selectedDate.day) {
      // Update the state first
      setState(() {
        _selectedDate = date;
        // If the date is from a different month, update the current month
        if (_selectedDate.month != _currentMonth.month) {
          _currentMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
        }
        // Update schedule time range based on the new selected date
        _updateScheduleTimeRange();
      });

      // Use correct page index and JUMP to it instead of animating
      final pageIndex = _getPageIndexFromDate(date);

      // Use jumpToPage instead of animateToPage to avoid sliding transition
      _dayPageController.jumpToPage(pageIndex);
    }
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
      // Smaller, more compact "No schedule" message
      return Center(
        child: Container(
          height: 100, // Fixed smaller height
          alignment: Alignment.center,
          child: Text(
            "No schedule for this day",
            style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
          ),
        ),
      );
    }

    // Fixed height approach without clipping
    const double HOUR_HEIGHT = 57.0;
    final int totalScheduleHours = _scheduleEndTime.hour - _scheduleStartTime.hour + 1;

    // Get all time slots first
    List<Widget> timeSlots = _buildTimeSlots();

    return ListView(
      padding: EdgeInsets.zero, // Remove default padding from ListView
      // Make sure the ListView doesn't scroll - parent controls scrolling
      physics: NeverScrollableScrollPhysics(),
      children: [
        // Use a container with relative positioning for schedule layout
        Container(
          width: double.infinity,
          // Set the height to a value that can fit all time slots
          height: totalScheduleHours * HOUR_HEIGHT + 40, // Add extra padding
          child: Stack(
            fit: StackFit.loose, // Don't constrain children tightly
            clipBehavior: Clip.none, // Don't clip any overflows
            children: [
              // Place time slots in a regular column
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: timeSlots),

              // Add each schedule item with Positioned
              ...scheduleItems.map((item) => _buildScheduleItemWidget(item)),
            ],
          ),
        ),
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
                color: Theme.of(context).colorScheme.primary.withAlpha(240),
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
    const double HOUR_HEIGHT = 57.0;
    final int totalScheduleHours = _scheduleEndTime.hour - _scheduleStartTime.hour + 1;

    // Calculate appropriate height - smaller for empty schedule
    final scheduleItems = _getScheduleForSelectedDate();
    final double containerHeight =
        scheduleItems.isEmpty
            ? 100 // Smaller height for empty schedule
            : totalScheduleHours * HOUR_HEIGHT + 40;

    return SliverStickyHeader(
      header: Container(
        padding: const EdgeInsets.only(top: 24, left: 16.0, bottom: 0.0), // Explicitly set bottom padding to 0.0
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Ensure column takes minimum vertical space
          children: [
            const Text("Schedule", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),

            // Simple non-animated date display
            Padding(
              padding: const EdgeInsets.only(top: 4.0, bottom: 16.0),
              child: Text(
                _dayFormatter.format(_selectedDate),
                style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface.withAlpha(180)),
              ),
            ),
          ],
        ),
      ),
      sliver: SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 0.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: containerHeight, // Dynamic height based on content
                width: double.infinity,
                child: PageView.builder(
                  physics: const PageScrollPhysics(),
                  controller: _dayPageController,
                  onPageChanged: _updateSelectedDateFromPage,
                  itemBuilder: (context, index) {
                    final currentDate = _selectedDate;
                    _selectedDate = _getDateFromPageIndex(index);
                    final widget = _buildScheduleItems();
                    _selectedDate = currentDate;
                    return widget;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssessmentsSection() {
    final assessments = _getAssessmentsForSelectedDate();

    // Return null if there are no assessments - this will cause the section not to be displayed
    if (assessments.isEmpty && !_isLoading) {
      return SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverStickyHeader(
      header: Container(
        padding: const EdgeInsets.only(left: 16.0),
        color: Theme.of(context).colorScheme.surface,
        child: const Text("Assessments", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
      ),
      sliver: SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8), // Reduced spacing here

              if (_isLoading)
                const Center(
                  child: Padding(padding: EdgeInsets.symmetric(vertical: 24.0), child: CircularProgressIndicator()),
                )
              else
                ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: assessments.length,
                  padding: EdgeInsets.zero, // Remove any padding
                  separatorBuilder:
                      (context, index) => Divider(height: 1, color: Theme.of(context).colorScheme.tertiary),
                  itemBuilder: (context, index) {
                    final assessment = assessments[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0), // Reduced padding
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(assessment.title, style: const TextStyle(fontWeight: FontWeight.w500)),
                                Text(
                                  assessment.className,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assessments = _getAssessmentsForSelectedDate();
    final bool hasAssessments = assessments.isNotEmpty || _isLoading;

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

            // Only include assessments section if there are assessments
            if (hasAssessments) _buildAssessmentsSection(),

            // Add expandable space to ensure app bar can fully collapse
            SliverFillRemaining(
              hasScrollBody: false,
              fillOverscroll: true,
              child: Container(
                // This ensures there's enough content to scroll
                // so the app bar can fully collapse
                height: MediaQuery.of(context).size.height * 0.6,
                color: Colors.transparent,
              ),
            ),
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
