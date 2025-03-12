import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'calendar.dart'; // Import to access CalendarHeightProvider and CalendarMonthProvider

class CalendarWidget extends StatefulWidget {
  const CalendarWidget({super.key});

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  // Track which week to display based on selected date
  late int _currentWeekIndex;

  // Generate calendar grid for the provided month
  List<List<DateTime>> _generateCalendarDays(DateTime month) {
    final List<List<DateTime>> result = [];

    // First day of the month
    final DateTime firstDay = DateTime(month.year, month.month, 1);

    // First day of the calendar grid (may be from the previous month)
    // Adjust to start from Sunday (weekday 7 or 0)
    int firstDayOffset = firstDay.weekday % 7;
    final DateTime firstCalendarDay = firstDay.subtract(Duration(days: firstDayOffset));

    // Generate 6 weeks to be safe (covers all month layouts)
    for (int week = 0; week < 6; week++) {
      final List<DateTime> weekDays = [];
      for (int day = 0; day < 7; day++) {
        final DateTime date = firstCalendarDay.add(Duration(days: week * 7 + day));
        weekDays.add(date);
      }
      result.add(weekDays);

      // Stop if we've gone past the end of the month and completed the week
      if (weekDays.last.month != month.month && weekDays.last.weekday == DateTime.sunday) {
        break;
      }
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

    // Get height information from provider
    final heightInfo = CalendarHeightProvider.of(context);

    // Default values if provider isn't available
    bool showFullCalendar = true;
    double currentHeight = 300; // Default full height

    // Use provider values if available
    if (heightInfo != null) {
      showFullCalendar = heightInfo.scrollProgress < 0.8; // Switch layouts when 80% scrolled
      currentHeight = heightInfo.currentHeight; // Use actual height from sliver
    }

    // Calculate single week height for proper sizing
    const double singleWeekHeight = 48.0; // Height of one week row including padding
    const double headerHeight = 36.0; // Height of day header row + spacing

    return Container(
      color: Theme.of(context).colorScheme.surface,
      height: currentHeight, // Explicitly set container height to match sliver height
      child: ClipRect(
        child: OverflowBox(
          minHeight: headerHeight + singleWeekHeight, // Minimum height shows one week + header
          maxHeight: 400, // Max height for full calendar
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Day of week headers - always visible
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

                // Conditionally show full calendar or just current week based on scroll progress
                if (showFullCalendar)
                  AnimatedOpacity(
                    opacity: heightInfo != null ? 1.0 - heightInfo.scrollProgress : 1.0,
                    duration: const Duration(milliseconds: 100),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children:
                          days.asMap().entries.map((entry) {
                            int weekIndex = entry.key;
                            List<DateTime> week = entry.value;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children:
                                    week.map((date) {
                                      final bool isCurrentMonth = date.month == currentMonth.month;
                                      final bool isSelected =
                                          date.year == selectedDate.year &&
                                          date.month == selectedDate.month &&
                                          date.day == selectedDate.day;

                                      return Expanded(
                                        child: GestureDetector(
                                          onTap: () => onDateSelected(date),
                                          child: Container(
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color:
                                                  isSelected
                                                      ? Theme.of(context).colorScheme.primary
                                                      : Colors.transparent,
                                              shape: BoxShape.circle,
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              date.day.toString(),
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                color:
                                                    isSelected
                                                        ? Colors.white
                                                        : isCurrentMonth
                                                        ? Theme.of(context).colorScheme.onSurface
                                                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                              ),
                            );
                          }).toList(),
                    ),
                  )
                else
                  AnimatedOpacity(
                    opacity: heightInfo != null ? heightInfo.scrollProgress : 1.0,
                    duration: const Duration(milliseconds: 100),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children:
                          days[_currentWeekIndex].map((date) {
                            final bool isCurrentMonth = date.month == currentMonth.month;
                            final bool isSelected =
                                date.year == selectedDate.year &&
                                date.month == selectedDate.month &&
                                date.day == selectedDate.day;

                            return Expanded(
                              child: GestureDetector(
                                onTap: () => onDateSelected(date),
                                child: Container(
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    date.day.toString(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color:
                                          isSelected
                                              ? Colors.white
                                              : isCurrentMonth
                                              ? Theme.of(context).colorScheme.onSurface
                                              : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
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
        ),
      ),
    );
  }
}
