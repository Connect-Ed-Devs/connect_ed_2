import 'package:flutter/material.dart';
import 'calendar.dart'; // Import to access CalendarHeightProvider and CalendarMonthProvider

class CalendarWidget extends StatefulWidget {
  final bool isInAppBar;
  final bool forceWeekView;

  const CalendarWidget({super.key, this.isInAppBar = false, this.forceWeekView = false});

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> with TickerProviderStateMixin {
  // Track which week to display based on selected date
  late int _currentWeekIndex;

  // Add controller for the animation
  final Map<DateTime, AnimationController> _controllers = {};

  // Constants for layout

  static const double HORIZONTAL_PADDING = 16.0;

  @override
  void dispose() {
    // Clean up all animation controllers
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Helper method to get or create animation controller for a date
  AnimationController _getController(DateTime date) {
    if (!_controllers.containsKey(date)) {
      _controllers[date] = AnimationController(duration: const Duration(milliseconds: 250), vsync: this);
    }
    return _controllers[date]!;
  }

  // Helper method to trigger the animation
  void _triggerAnimation(DateTime date) {
    final controller = _getController(date);
    controller.forward().then((_) => controller.reverse());
  }

  // Generate calendar grid for the provided month
  List<List<DateTime>> _generateCalendarDays(DateTime month) {
    final List<List<DateTime>> result = [];

    // First day of the month
    final DateTime firstDay = DateTime(month.year, month.month, 1);
    // Last day of the month
    final DateTime lastDay = DateTime(month.year, month.month + 1, 0);

    // First day of the calendar grid (may be from the previous month)
    int firstDayOffset = firstDay.weekday % 7;
    final DateTime firstCalendarDay = firstDay.subtract(Duration(days: firstDayOffset));

    // Calculate how many weeks we need
    int lastDayOffset = lastDay.weekday % 7;
    int daysToShow = firstDayOffset + lastDay.day + (6 - lastDayOffset);
    int weeksNeeded = (daysToShow / 7).ceil();

    // Generate only the needed weeks
    for (int week = 0; week < weeksNeeded; week++) {
      final List<DateTime> weekDays = [];
      for (int day = 0; day < 7; day++) {
        final DateTime date = firstCalendarDay.add(Duration(days: week * 7 + day));
        weekDays.add(date);
      }
      result.add(weekDays);
    }

    return result;
  }

  // Find the week index for the selected date
  int _getWeekIndex(List<List<DateTime>> days, DateTime selectedDate) {
    for (int i = 0; i < days.length; i++) {
      for (final DateTime day in days[i]) {
        if (day.year == selectedDate.year && day.month == selectedDate.month && day.day == selectedDate.day) {
          return i;
        }
      }
    }
    return 0; // Default to first week if not found
  }

  @override
  Widget build(BuildContext context) {
    // Get month info from provider
    final monthInfo = CalendarMonthProvider.of(context);

    // Default to current date if provider not available
    DateTime currentMonth = DateTime.now();
    DateTime selectedDate = DateTime.now();
    Function(DateTime) onDateSelected = (_) {};

    // Use provider values if available
    if (monthInfo != null) {
      currentMonth = monthInfo.currentMonth;
      selectedDate = monthInfo.selectedDate;
      onDateSelected = monthInfo.onDateSelected;
    }

    // Generate calendar days based on current month
    List<List<DateTime>> days = _generateCalendarDays(currentMonth);

    // Determine which week contains the selected date
    _currentWeekIndex = _getWeekIndex(days, selectedDate);

    // Determine if we show full calendar or just the week
    bool showFullCalendar = !widget.forceWeekView && !widget.isInAppBar;

    // Date container builder function
    Widget buildDateContainer(DateTime date, bool isSelected, bool isCurrentMonth) {
      final controller = _getController(date);

      return FadeTransition(
        opacity: Tween<double>(
          begin: 1.0,
          end: 0.5,
        ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut)),
        child: GestureDetector(
          onTap: () {
            _triggerAnimation(date);
            onDateSelected(date);
          },
          child: Container(
            height: widget.isInAppBar ? 24 : 32, // Smaller in app bar
            decoration: BoxDecoration(
              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              date.day.toString(),
              style: TextStyle(
                fontSize: 14, // Smaller text in app bar
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color:
                    isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : isCurrentMonth
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: EdgeInsets.symmetric(horizontal: widget.isInAppBar ? 0 : HORIZONTAL_PADDING),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.isInAppBar || !widget.forceWeekView)
            // Day of week headers - not needed in collapsed app bar
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children:
                    const ["S", "M", "T", "W", "T", "F", "S"]
                        .map(
                          (day) => Expanded(
                            child: Text(
                              day,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),

          // Calendar content - either full calendar or just current week
          if (showFullCalendar)
            Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  days.asMap().entries.map((entry) {
                    int weekIndex = entry.key;
                    List<DateTime> week = entry.value;
                    bool isLastWeek = weekIndex == days.length - 1;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children:
                              week.map((date) {
                                final bool isCurrentMonth = date.month == currentMonth.month;
                                final bool isSelected =
                                    date.year == selectedDate.year &&
                                    date.month == selectedDate.month &&
                                    date.day == selectedDate.day;

                                return Expanded(child: buildDateContainer(date, isSelected, isCurrentMonth));
                              }).toList(),
                        ),
                        if (!isLastWeek)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Divider(height: 1, color: Theme.of(context).dividerColor.withAlpha(50)),
                          ),
                      ],
                    );
                  }).toList(),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children:
                  days[_currentWeekIndex].map((date) {
                    final bool isCurrentMonth = date.month == currentMonth.month;
                    final bool isSelected =
                        date.year == selectedDate.year &&
                        date.month == selectedDate.month &&
                        date.day == selectedDate.day;

                    return Expanded(child: buildDateContainer(date, isSelected, isCurrentMonth));
                  }).toList(),
            ),
        ],
      ),
    );
  }
}
