import 'package:connect_ed_2/frontend/calendar/calendar.dart';
import 'package:connect_ed_2/frontend/setup/opacity_button.dart';
import 'package:flutter/material.dart';
import 'package:connect_ed_2/frontend/calendar/calendar_widget.dart';

class CECalendarAppBar extends StatelessWidget {
  final String title;
  final String collapsedTitle;
  final DateTime currentMonth;
  final DateTime selectedDate;
  final Function(DateTime) onDateSelected;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ScrollController scrollController;

  const CECalendarAppBar({
    Key? key,
    required this.title,
    required this.collapsedTitle,
    required this.currentMonth,
    required this.selectedDate,
    required this.onDateSelected,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.scrollController,
  }) : super(key: key);

  // Calculate the height needed based on the number of weeks in the month
  double _calculateCalendarHeight(DateTime month) {
    // First day of the month
    final DateTime firstDay = DateTime(month.year, month.month, 1);
    // Last day of the month
    final DateTime lastDay = DateTime(month.year, month.month + 1, 0);

    // Calculate how many weeks we need
    int firstDayOffset = firstDay.weekday % 7;
    int lastDayOffset = lastDay.weekday % 7;
    int daysToShow = firstDayOffset + lastDay.day + (6 - lastDayOffset);
    int weekCount = (daysToShow / 7).ceil();

    // Constants for layout
    const double TITLE_HEIGHT = 44; // Height for title and month navigation
    const double SINGLE_WEEK_HEIGHT = 36.0;
    const double WEEK_DAY_HEADER_HEIGHT = 12.0;
    const double DIVIDER_HEIGHT = 7.0;
    const double PADDING = 0.0;

    // Calculate total divider height (one less than week count)
    double dividerTotalHeight = (weekCount - 1) * DIVIDER_HEIGHT;

    // Total height calculation
    return TITLE_HEIGHT + WEEK_DAY_HEADER_HEIGHT + (SINGLE_WEEK_HEIGHT * weekCount) + dividerTotalHeight + PADDING;
  }

  @override
  Widget build(BuildContext context) {
    // Calculate the dynamic height based on current month
    final double calendarHeight = _calculateCalendarHeight(currentMonth);
    final double expandedHeight = calendarHeight + 64; // Add padding for app bar elements

    return SliverAppBar(
      expandedHeight: expandedHeight,
      toolbarHeight: 64, // Height for collapsed app bar
      pinned: true,
      elevation: 0,
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: const SizedBox.shrink(),
      leading: null,
      flexibleSpace: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Calculate scroll progress
          double progress = 0.0;
          double height = constraints.maxHeight;

          // Get the collapsed and expanded heights
          final double collapsedHeight = MediaQuery.of(context).padding.top + 64;
          final double maxHeight = expandedHeight + MediaQuery.of(context).padding.top;

          // Calculate progress as percentage between expanded and collapsed
          if (height < maxHeight) {
            progress = (maxHeight - height) / (maxHeight - collapsedHeight);
            progress = progress.clamp(0.0, 1.0);
          }

          // Calculate y-offsets for parallax effect
          final double calendarParallaxOffset = -150 * progress; // Calendar moves up faster
          final double titleParallaxOffset = -25 * progress; // Title moves up slightly

          return Stack(
            children: [
              // Background for entire app bar including status bar
              Positioned(
                top: 0, // Start from very top (including status bar)
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(color: Theme.of(context).colorScheme.surface),
              ),

              // Full calendar - with parallax scroll effect
              Positioned(
                top: MediaQuery.of(context).padding.top + 96 + calendarParallaxOffset, // Moves up as user scrolls
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: (1.0 - progress * 1.3).clamp(0.0, 1.0), // Fade out as it scrolls up
                  child: _buildFullCalendar(),
                ),
              ),

              // Month title and navigation (when expanded) - moves up slightly with scroll
              Positioned(
                top: MediaQuery.of(context).padding.top + 10 + titleParallaxOffset, // Slight upward movement
                left: 16,
                right: 16,
                child: Container(
                  color: Theme.of(context).colorScheme.surface, // Background to prevent calendar showing through
                  padding: const EdgeInsets.only(bottom: 8), // Add some padding at the bottom
                  child: Opacity(
                    opacity: (1.0 - progress * 1.5).clamp(0.0, 1.0), // Fade out faster
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w600)),
                        Row(
                          children: [
                            OpacityIconButton(icon: Icons.arrow_back_ios, onPressed: onPreviousMonth),
                            OpacityIconButton(icon: Icons.arrow_forward_ios, onPressed: onNextMonth),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Collapsed bar with date and week view (fades in)
              Positioned(
                top: MediaQuery.of(context).padding.top,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: progress,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Date text (month + day)
                      Container(
                        color: Theme.of(context).colorScheme.surface, // Background color to prevent overlap
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(collapsedTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      ),

                      // Week view - stabilizes in position
                      Container(
                        height: 30,
                        margin: EdgeInsets.only(top: 8), // Fixed margin
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildWeekView(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Padding(padding: const EdgeInsets.all(8.0), child: Icon(icon, size: 20)),
    );
  }

  Widget _buildFullCalendar() {
    return CalendarMonthProvider(
      currentMonth: currentMonth,
      selectedDate: selectedDate,
      onDateSelected: onDateSelected,
      child: const CalendarWidget(isInAppBar: false),
    );
  }

  Widget _buildWeekView() {
    return CalendarMonthProvider(
      currentMonth: currentMonth,
      selectedDate: selectedDate,
      onDateSelected: onDateSelected,
      child: const CalendarWidget(isInAppBar: true, forceWeekView: true),
    );
  }
}
