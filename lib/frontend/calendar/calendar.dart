import 'package:connect_ed_2/frontend/calendar/calendar_app_bar.dart';
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

  @override
  Widget build(BuildContext context) {
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

          // Content below calendar
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Schedule", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
                  SizedBox(height: 16),
                  Column(
                    children: [
                      Flex(
                        direction: Axis.horizontal,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(flex: 1, child: Text("8"), fit: FlexFit.tight),
                          Flexible(flex: 2, child: Text("AM"), fit: FlexFit.tight),
                          Flexible(
                            flex: 15,
                            child: Divider(color: Theme.of(context).colorScheme.onSurface.withAlpha(50)),
                          ),
                        ],
                      ),
                      SizedBox(height: 32),
                      Flex(
                        direction: Axis.horizontal,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(flex: 1, child: Text("9"), fit: FlexFit.tight),
                          Flexible(flex: 2, child: Text("AM"), fit: FlexFit.tight),
                          Flexible(
                            flex: 15,
                            child: Divider(color: Theme.of(context).colorScheme.onSurface.withAlpha(50)),
                          ),
                        ],
                      ),
                      SizedBox(height: 32),
                      Flex(
                        direction: Axis.horizontal,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(flex: 1, child: Text("10"), fit: FlexFit.tight),
                          Flexible(flex: 2, child: Text("AM"), fit: FlexFit.tight),
                          Flexible(
                            flex: 15,
                            child: Divider(color: Theme.of(context).colorScheme.onSurface.withAlpha(50)),
                          ),
                        ],
                      ),
                      SizedBox(height: 32),
                      Flex(
                        direction: Axis.horizontal,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(flex: 1, child: Text("11"), fit: FlexFit.tight),
                          Flexible(flex: 2, child: Text("AM"), fit: FlexFit.tight),
                          Flexible(
                            flex: 15,
                            child: Divider(color: Theme.of(context).colorScheme.onSurface.withAlpha(50)),
                          ),
                        ],
                      ),
                      SizedBox(height: 32),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Add extra space at the bottom to ensure enough scrollable area
          SliverToBoxAdapter(
            child: SizedBox(
              // This height ensures there's always enough content to scroll
              height: MediaQuery.of(context).size.height * 0.7,
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
