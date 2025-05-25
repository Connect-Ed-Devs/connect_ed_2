import 'dart:math';

import 'package:connect_ed_2/classes/assessment.dart';
import 'package:connect_ed_2/classes/calendar_item.dart';
import 'package:connect_ed_2/classes/schedule_item.dart';
import 'package:connect_ed_2/classes/menu_section.dart';
import 'package:connect_ed_2/frontend/calendar/calendar_app_bar.dart';
import 'package:connect_ed_2/requests/cache_manager.dart';
import 'package:connect_ed_2/requests/calendar_requests.dart';
import 'package:connect_ed_2/requests/menu_cache_manager.dart';
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
  String? _errorMessage; // Add error message state
  bool _hasDataLoadError = false; // Track if there's a data loading error

  // Time range for the schedule display
  late TimeOfDay _scheduleStartTime;
  late TimeOfDay _scheduleEndTime;

  // Add menu data variables
  Map<DateTime, List<MenuSection>>? _menuData;
  bool _isLoadingMenu = false;
  bool _hasMenuLoadError = false;
  Map<int, bool> _expandedMenuSections = {};

  @override
  void initState() {
    super.initState();

    // Initialize page controller with initial date
    _dayPageController = PageController(initialPage: 500); // Start at middle to allow for past/future swiping

    // Initialize schedule time range with default values to prevent LateInitializationError
    _scheduleStartTime = const TimeOfDay(hour: 8, minute: 0);
    _scheduleEndTime = const TimeOfDay(hour: 17, minute: 0);

    _loadCalendarData();
    _loadMenuData();
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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasDataLoadError = false;
    });

    // Get data from calendar manager with proper error handling
    final cacheStatus = calendarManager.getCacheStatus();

    if (cacheStatus != CacheStatus.expired) {
      try {
        _calendarData = calendarManager.getCachedData();
        if (_calendarData != null) {
          setState(() {
            _isLoading = false;
            _hasDataLoadError = false;
            _updateScheduleTimeRange();
          });
          return;
        }
      } catch (cacheError) {
        // Handle cached data access error
        print('Error accessing cached data: $cacheError');
        // Continue to fetch fresh data instead of failing completely
      }
    }

    // Fetch fresh data if expired, no cached data, or cache access failed
    calendarManager
        .fetchData()
        .then((data) {
          setState(() {
            _calendarData = data;
            _isLoading = false;
            _errorMessage = null;
            _hasDataLoadError = false;
            _updateScheduleTimeRange();
          });
        })
        .catchError((error) {
          setState(() {
            _isLoading = false;
            _errorMessage = _parseErrorMessage(error.toString());
            _hasDataLoadError = true;
            _updateScheduleTimeRange();
          });
          print('Error loading calendar data: $error');
        });
  }

  // Parse error message to make it more user-friendly
  String _parseErrorMessage(String errorMessage) {
    if (errorMessage.contains('network') || errorMessage.contains('Network')) {
      return "Network connection error";
    } else if (errorMessage.contains('timeout') || errorMessage.contains('Timeout')) {
      return "Request timed out";
    } else if (errorMessage.contains('calendar service') || errorMessage.contains('calendar')) {
      return "Calendar service unavailable";
    } else if (errorMessage.contains('Invalid') || errorMessage.contains('invalid')) {
      return "Invalid calendar link";
    } else {
      return "Unable to load calendar data";
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

  // Load menu data from cache manager
  void _loadMenuData() {
    // Try to get data from cache first
    try {
      _menuData = menuManager.getCachedData();
      if (_menuData != null) return;
    } catch (e) {
      print('Error accessing cached menu: $e');
    }

    // If no cached data or error, fetch fresh data
    setState(() {
      _isLoadingMenu = true;
    });

    menuManager
        .fetchData()
        .then((data) {
          setState(() {
            _menuData = data;
            _isLoadingMenu = false;
            _hasMenuLoadError = false;
          });
        })
        .catchError((error) {
          setState(() {
            _isLoadingMenu = false;
            _hasMenuLoadError = true;
          });
        });
  }

  // Get menu for the selected date
  List<MenuSection>? _getMenuForSelectedDate() {
    if (_menuData == null) return null;

    // Create a normalized date key (without time component)
    final normalizedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    return _menuData![normalizedDate];
  }

  void _updateScheduleTimeRange() {
    final scheduleItems = _getScheduleForSelectedDate();

    if (scheduleItems.isEmpty) {
      // Default time range for empty schedule
      setState(() {
        _scheduleStartTime = const TimeOfDay(hour: 8, minute: 0);
        _scheduleEndTime = const TimeOfDay(hour: 17, minute: 0);
      });
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

    // Add padding (1 hour before and after) and update state
    setState(() {
      _scheduleStartTime = TimeOfDay(hour: (earliest.hour).clamp(0, 23), minute: 0);
      _scheduleEndTime = TimeOfDay(hour: (latest.hour + 1).clamp(0, 23), minute: 59);
    });
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

  // Toggle menu section expanded state
  void _toggleMenuSection(int index) {
    setState(() {
      _expandedMenuSections[index] = !(_expandedMenuSections[index] ?? false);
    });
  }

  // Format section titles with proper capitalization
  String _formatSectionTitle(String title) {
    if (title.isEmpty) return '';

    // Split by spaces, capitalize each word, rejoin
    return title
        .split(' ')
        .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : '')
        .join(' ');
  }

  // Properly format food items text
  String _formatFoodItems(String text) {
    // Replace literal "\n" sequences with actual newlines
    String processed = text.replaceAll('\\n', '\n');

    // Trim extra whitespace around lines
    processed = processed.split('\n').map((line) => line.trim()).join('\n');

    return processed;
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

    if (_hasDataLoadError) {
      return Center(
        child: Container(
          height: 250, // Increased height to match container height
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
              SizedBox(height: 16),
              Text(
                "Failed to load schedule",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.error),
              ),
              SizedBox(height: 8),
              Text(
                _errorMessage ?? "Unknown error occurred",
                style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadCalendarData,
                icon: Icon(Icons.refresh, size: 16),
                label: Text("Retry"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (scheduleItems.isEmpty) {
      return Center(
        child: Container(
          height: 150, // Increased from 100 to match container height
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

    // Calculate appropriate height - provide more space for error states
    final scheduleItems = _getScheduleForSelectedDate();
    final double containerHeight;

    if (_isLoading || _hasDataLoadError) {
      containerHeight = 250; // Increased height for error/loading states
    } else if (scheduleItems.isEmpty) {
      containerHeight = 150; // Slightly increased for empty state
    } else {
      containerHeight = totalScheduleHours * HOUR_HEIGHT + 40; // Normal schedule height
    }

    return SliverStickyHeader(
      header: Container(
        padding: const EdgeInsets.only(top: 24, left: 16.0, bottom: 0.0),
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Schedule", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
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
                height: containerHeight, // Dynamic height based on content and state
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

  Widget _buildMenuSection() {
    final menuSections = _getMenuForSelectedDate();

    // If no menu for this day, don't show the section
    if (menuSections == null || menuSections.isEmpty) {
      return SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverStickyHeader(
      header: Container(
        padding: const EdgeInsets.only(left: 16.0, top: 24.0, bottom: 8.0),
        color: Theme.of(context).colorScheme.surface,
        child: Text("Menu", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index >= menuSections.length) return null;

          final menuSection = menuSections[index];
          if (menuSection.isEmpty) return SizedBox.shrink();

          final isExpanded = _expandedMenuSections[index] ?? false;
          final formattedTitle = _formatSectionTitle(menuSection.sectionTitle);

          return Container(
            margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Replace InkWell with GestureDetector and use AnimatedOpacity
                GestureDetector(
                  onTap: () => _toggleMenuSection(index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formattedTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        AnimatedOpacity(
                          opacity: isExpanded ? 1.0 : 0.6,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Direct conditional content instead of animated crossfade
                if (isExpanded)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:
                          menuSection.courses.map((course) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatSectionTitle(course[0]),
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                  SizedBox(height: 2),
                                  Text(_formatFoodItems(course[1]), style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                // Change divider color to tertiary and reduce height
                Divider(
                  height: 1, // Reduced height
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ],
            ),
          );
        }, childCount: menuSections.length),
      ),
    );
  }

  Widget _buildAssessmentsSection() {
    final assessments = _getAssessmentsForSelectedDate();

    // Return null if there are no assessments and no loading/error state
    if (assessments.isEmpty && !_isLoading && !_hasDataLoadError) {
      return SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverStickyHeader(
      header: Container(
        padding: const EdgeInsets.only(left: 16.0),
        color: Theme.of(context).colorScheme.surface,
        child: Row(
          children: [
            Text("Assessments", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
            if (_hasDataLoadError) ...[
              SizedBox(width: 8),
              Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 20),
            ],
          ],
        ),
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
              else if (_hasDataLoadError)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                        SizedBox(height: 16),
                        Text(
                          "Failed to load assessments",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          _errorMessage ?? "Unknown error occurred",
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadCalendarData,
                          icon: Icon(Icons.refresh, size: 16),
                          label: Text("Retry"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (assessments.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                        ),
                        SizedBox(height: 16),
                        Text(
                          "No assessments for this day",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
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
    final bool hasAssessments = assessments.isNotEmpty || _isLoading || _hasDataLoadError;
    final hasMenu = _getMenuForSelectedDate()?.isNotEmpty ?? false;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          // Force refresh data and wait for completion
          setState(() {
            _isLoading = true;
            _isLoadingMenu = true;
            _errorMessage = null;
            _hasDataLoadError = false;
          });

          try {
            // Refresh calendar data
            final newCalendarData = await calendarManager.fetchData();
            // Refresh menu data
            final newMenuData = await menuManager.fetchData();

            setState(() {
              _calendarData = newCalendarData;
              _menuData = newMenuData;
              _isLoading = false;
              _isLoadingMenu = false;
              _errorMessage = null;
              _hasDataLoadError = false;
              _updateScheduleTimeRange();
            });
          } catch (error) {
            setState(() {
              _isLoading = false;
              _isLoadingMenu = false;
              _errorMessage = _parseErrorMessage(error.toString());
              _hasDataLoadError = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to refresh: ${_parseErrorMessage(error.toString())}'),
                backgroundColor: Theme.of(context).colorScheme.error,
                action: SnackBarAction(
                  label: 'Retry',
                  textColor: Theme.of(context).colorScheme.onError,
                  onPressed: () {
                    _loadCalendarData();
                    _loadMenuData();
                  },
                ),
              ),
            );
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

            // Menu section (only if available for selected date)
            _buildMenuSection(),

            // Only include assessments section if there are assessments
            if (hasAssessments) _buildAssessmentsSection(),

            // Add expandable space to ensure app bar can fully collapse
            SliverFillRemaining(
              hasScrollBody: false,
              fillOverscroll: true,
              child: Container(height: MediaQuery.of(context).size.height * 0.6, color: Colors.transparent),
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
