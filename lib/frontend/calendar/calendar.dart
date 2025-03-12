import 'dart:math';
import 'package:connect_ed_2/frontend/calendar/calendar_widget.dart';
import 'package:connect_ed_2/frontend/setup/app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  // Add method to calculate calendar height
  double _getCalendarHeight(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    final firstDayOffset = firstDay.weekday % 7;
    final lastDayOffset = lastDay.weekday % 7;

    final daysToShow = firstDayOffset + lastDay.day + (6 - lastDayOffset);
    final weekCount = (daysToShow / 7).ceil();

    const double SINGLE_WEEK_HEIGHT = 40.0; // Match updated widget constant
    const double HEADER_HEIGHT = 32.0; // Match updated widget constant
    const double TOTAL_VERTICAL_PADDING = 0.0; // Increased padding

    return HEADER_HEIGHT + (SINGLE_WEEK_HEIGHT * weekCount) + TOTAL_VERTICAL_PADDING;
  }

  @override
  Widget build(BuildContext context) {
    // Calculate the maximum height needed for the current month
    final double maxCalendarHeight = _getCalendarHeight(_currentMonth);

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // App bar with month title and navigation
          CEAppBar(
            title: _monthFormatter.format(_currentMonth),
            trailingAction: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Custom opacity buttons for month navigation
                OpacityIconButton(icon: Icons.arrow_back_ios, onPressed: _previousMonth),
                OpacityIconButton(icon: Icons.arrow_forward_ios, onPressed: _nextMonth),
              ],
            ),
            // When collapsed, show month + day
            collapsedTitle: _dateFormatter.format(_selectedDate),
          ),

          SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Update the SliverPersistentHeader with dynamic maxHeight
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverHeaderDelegate(
              minHeight: 64,
              maxHeight: maxCalendarHeight,
              child: CalendarMonthProvider(
                currentMonth: _currentMonth,
                selectedDate: _selectedDate,
                onDateSelected: _onDateSelected,
                child: const CalendarWidget(),
              ),
            ),
          ),

          // Content below calendar
          SliverToBoxAdapter(
            child: Container(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Events for ${_dateFormatter.format(_selectedDate)}",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  // Example events
                  for (int i = 0; i < 10; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Container(
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1)),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("Event $i", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text(
                                    "Event details for ${_dateFormatter.format(_selectedDate)}",
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
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

class _SliverHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SliverHeaderDelegate({required this.minHeight, required this.maxHeight, required this.child});
  final double minHeight;
  final double maxHeight;
  final Widget child;

  @override
  double get minExtent => minHeight;
  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Calculate actual height and scroll progress
    final double height = maxExtent - shrinkOffset.clamp(0.0, maxExtent - minExtent);
    final double scrollProgress = shrinkOffset / (maxExtent - minExtent);

    // Enforce strict bounds with SizedBox
    return SizedBox(
      height: height,
      child: CalendarHeightProvider(
        currentHeight: height,
        maxHeight: maxHeight,
        scrollProgress: scrollProgress.clamp(0.0, 1.0),
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverHeaderDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight || minHeight != oldDelegate.minHeight || child != oldDelegate.child;
  }
}

class CalendarHeightProvider extends InheritedWidget {
  final double currentHeight;
  final double maxHeight;
  final double scrollProgress; // 0.0 = expanded, 1.0 = collapsed

  const CalendarHeightProvider({
    Key? key,
    required this.currentHeight,
    required this.maxHeight,
    required this.scrollProgress,
    required Widget child,
  }) : super(key: key, child: child);

  static CalendarHeightProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CalendarHeightProvider>();
  }

  @override
  bool updateShouldNotify(CalendarHeightProvider oldWidget) {
    return currentHeight != oldWidget.currentHeight ||
        maxHeight != oldWidget.maxHeight ||
        scrollProgress != oldWidget.scrollProgress;
  }
}
