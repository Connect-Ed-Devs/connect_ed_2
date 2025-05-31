import 'dart:ui';
import 'dart:math'; // Added for max function in dialog

import 'package:connect_ed_2/classes/assessment.dart';
import 'package:connect_ed_2/classes/calendar_item.dart';
import 'package:connect_ed_2/classes/game.dart';
import 'package:connect_ed_2/classes/menu_section.dart';
import 'package:connect_ed_2/classes/schedule_item.dart';
import 'package:connect_ed_2/frontend/home/today_schedule.dart';
import 'package:connect_ed_2/frontend/settings/settings.dart';
import 'package:connect_ed_2/frontend/setup/app_bar.dart';
import 'package:connect_ed_2/frontend/setup/opacity_button.dart';
import 'package:connect_ed_2/frontend/sports/game_widgets.dart';
import 'package:connect_ed_2/requests/cache_manager.dart';
import 'package:connect_ed_2/requests/calendar_requests.dart';
import 'package:connect_ed_2/requests/games_cache_manager.dart';
import 'package:connect_ed_2/requests/menu_cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'menu_dialog.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  // Animation controller for the gradient
  late AnimationController _animationController;

  // Add calendar data variables
  Map<DateTime, CalendarItem>? _calendarData;
  ScheduleItem? _nextScheduleItem;
  bool _isLoading = false;
  String? _errorMessage; // Add error message state
  bool _hasDataLoadError = false; // Track if there's a data loading error

  // Add state variable for menu data
  bool _isLoadingMenu = false;
  bool _hasMenuLoadError = false;
  String? _menuErrorMessage;

  // Add game data variables
  bool _isLoadingGames = true;
  bool _hasGamesError = false;
  String? _gamesErrorMessage;
  List<Game> _recentGames = [];

  @override
  void initState() {
    super.initState();

    // Initialize the animation controller with a very slow rotation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);

    // Load calendar data when the widget initializes
    _loadCalendarData();

    // Load games data
    _loadGamesData();
  }

  // Load calendar data from the cache manager
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
            _nextScheduleItem = _getNextScheduleItem(_calendarData!);
            _isLoading = false;
            _hasDataLoadError = false;
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
            _nextScheduleItem = _getNextScheduleItem(data);
            _isLoading = false;
            _errorMessage = null;
            _hasDataLoadError = false;
          });
        })
        .catchError((error) {
          setState(() {
            _isLoading = false;
            _errorMessage = _parseErrorMessage(error.toString());
            _hasDataLoadError = true;
            // Set fallback data for UI
            _nextScheduleItem = ScheduleItem(
              title: 'Schedule unavailable',
              startTime: TimeOfDay(hour: 0, minute: 0),
              endTime: TimeOfDay(hour: 0, minute: 0),
            );
          });
          print('Error loading calendar data: $error');
        });
  }

  // Parse error message to make it more user-friendly
  String _parseErrorMessage(String errorMessage) {
    if (errorMessage.contains('network') || errorMessage.contains('Network')) {
      return 'Network connection error';
    } else if (errorMessage.contains('timeout') ||
        errorMessage.contains('Timeout')) {
      return 'Request timed out';
    } else if (errorMessage.contains('calendar service') ||
        errorMessage.contains('calendar')) {
      return 'Calendar service unavailable';
    } else if (errorMessage.contains('Invalid') ||
        errorMessage.contains('invalid')) {
      return 'Invalid calendar link';
    } else {
      return 'Unable to load calendar data';
    }
  }

  // Get upcoming assessments for the next 7 days
  List<Assessment> _getUpcomingAssessments() {
    if (_calendarData == null) return [];

    List<Assessment> upcomingAssessments = [];
    final now = DateTime.now();
    final nextWeek = now.add(const Duration(days: 7));

    // Normalize current date to midnight for proper comparison
    final normalizedNow = DateTime(now.year, now.month, now.day);

    _calendarData!.forEach((date, calendarItem) {
      // Check if date is between now and next 7 days
      if (date.isAfter(normalizedNow.subtract(const Duration(days: 1))) &&
          date.isBefore(nextWeek)) {
        upcomingAssessments.addAll(calendarItem.assessments);
      }
    });

    // Sort by date
    upcomingAssessments.sort((a, b) => a.date.compareTo(b.date));

    return upcomingAssessments;
  }

  // Format assessment date to readable string
  String _formatAssessmentDate(DateTime date) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    } else if (date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day) {
      return 'Tomorrow';
    } else {
      // Format as "Mon, Jan 15"
      return DateFormat('E, MMM d').format(date);
    }
  }

  // Find the next schedule item
  ScheduleItem? _getNextScheduleItem(Map<DateTime, CalendarItem> calendarData) {
    print('--- _getNextScheduleItem called ---');
    if (calendarData.isEmpty) {
      print('Calendar data is empty.');
      return null;
    }

    final now = DateTime.now();
    final currentTime = TimeOfDay.fromDateTime(now);
    print('Current DateTime: $now, Current TimeOfDay: $currentTime');

    // First check today's schedule
    final today = DateTime(now.year, now.month, now.day);
    print("Checking for today's schedule: $today");

    if (calendarData.containsKey(today)) {
      print('Found schedule for today.');
      final todaySchedule = List<ScheduleItem>.from(
        calendarData[today]!.schedule,
      );

      if (todaySchedule.isEmpty) {
        print("Today's schedule is empty.");
      } else {
        print(
          "Today's schedule items (before sort): ${todaySchedule.map((e) => '${e.title} @ ${e.startTime}').toList()}",
        );
        // Sort by start time
        todaySchedule.sort((a, b) {
          final aMinutes = a.startTime.hour * 60 + a.startTime.minute;
          final bMinutes = b.startTime.hour * 60 + b.startTime.minute;
          return aMinutes.compareTo(bMinutes);
        });
        print(
          "Today's schedule items (after sort): ${todaySchedule.map((e) => '${e.title} @ ${e.startTime}').toList()}",
        );

        // Find the next class today
        for (final item in todaySchedule) {
          final itemStartMinutes =
              item.startTime.hour * 60 + item.startTime.minute;
          final currentMinutes = currentTime.hour * 60 + currentTime.minute;

          print(
            '  Comparing Today: ${item.title} (${item.startTime}) -> $itemStartMinutes min > $currentMinutes min (current)?',
          );

          if (itemStartMinutes > currentMinutes) {
            print(
              '    -> YES. Next class today: ${item.title} at ${item.startTime}',
            );
            return item; // This is the next class today
          } else {
            print('    -> NO. Class has passed or is ongoing.');
          }
        }
        print(
          'No suitable next class found for today after checking all items.',
        );
      }
    } else {
      print('No schedule data found for today.');
    }

    // If no class found today, check tomorrow
    return ScheduleItem(
      title: 'No Class',
      startTime: TimeOfDay(hour: 0, minute: 0),
      endTime: TimeOfDay(hour: 0, minute: 0),
    );
  }

  void _showTodayScheduleDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return TodayScheduleDialog(
          calendarData: _calendarData,
          dateToShow: DateTime.now(),
        );
      },
    );
  }

  void _showTodayMenuDialog() async {
    setState(() {
      _isLoadingMenu = true;
      _hasMenuLoadError = false;
      _menuErrorMessage = null;
    });

    // Show loading dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Text("Today's Menu"),
                SizedBox(width: 12),
                SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ),
            content: Text('Loading menu items...'),
          ),
    );

    try {
      // Get today's date without time
      final today = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );

      // Try to get data from cache first
      Map<DateTime, List<MenuSection>>? menuData;
      try {
        menuData = menuManager.getCachedData();
      } catch (e) {
        print('Error accessing cached menu: $e');
      }

      // If no cached data or error, try to fetch fresh data
      menuData ??= await menuManager.fetchData();

      // Close loading dialog
      Navigator.of(context).pop();

      // Check if today's menu exists
      List<MenuSection>? todayMenu = menuData?[today];

      if (todayMenu == null || todayMenu.isEmpty) {
        _showNoMenuDialog();
      } else {
        _showMenuContentDialog(todayMenu);
      }

      setState(() {
        _isLoadingMenu = false;
      });
    } catch (e) {
      // Close loading dialog
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      setState(() {
        _isLoadingMenu = false;
        _hasMenuLoadError = true;
        _menuErrorMessage = 'Failed to load the menu: ${e.toString()}';
      });

      _showMenuErrorDialog(e.toString());
    }
  }

  void _showNoMenuDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('No Menu Available'),
            content: Text("There's no menu available for today."),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('CLOSE'),
              ),
            ],
          ),
    );
  }

  void _showMenuErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Menu Error'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Failed to load the menu.'),
                SizedBox(height: 8),
                Text(
                  errorMessage,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('CLOSE'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showTodayMenuDialog(); // Retry loading
                },
                child: Text('RETRY'),
              ),
            ],
          ),
    );
  }

  void _showMenuContentDialog(List<MenuSection> menuSections) {
    showDialog(
      context: context,
      builder: (context) => MenuDialog(menuSections: menuSections),
    );
  }

  // Load games data from the cache manager
  Future<void> _loadGamesData() async {
    setState(() {
      _isLoadingGames = true;
      _hasGamesError = false;
      _gamesErrorMessage = null;
    });

    try {
      // Get cached data first
      Map<String, Game>? cachedGames;
      try {
        cachedGames = gamesManager.getCachedData();
      } catch (e) {
        print('Error accessing cached games: $e');
      }

      // If no cached data, fetch fresh
      cachedGames ??= await gamesManager.fetchData();

      // Process games data - get recent games with scores
      if (cachedGames != null) {
        final now = DateTime.now();

        // Get played games (games with scores)
        List<Game> playedGames =
            cachedGames.values
                .where((game) => game.homeScore != '-' && game.awayScore != '-')
                .toList();

        // Sort by date descending (most recent first)
        playedGames.sort((a, b) => b.date.compareTo(a.date));

        setState(() {
          // Take the 5 most recent games
          _recentGames = playedGames.take(5).toList();
          _isLoadingGames = false;
        });
      }
    } catch (error) {
      setState(() {
        _isLoadingGames = false;
        _hasGamesError = true;
        _gamesErrorMessage = error.toString();
      });
      print('Error loading games: $error');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get upcoming assessments
    final upcomingAssessments = _getUpcomingAssessments();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          // Force refresh data and wait for completion
          setState(() {
            _isLoading = true;
            _isLoadingMenu = true; // Also set menu loading state
            _errorMessage = null;
            _hasDataLoadError = false;
            _hasMenuLoadError = false; // Reset menu error state
          });

          try {
            // Create both fetches in parallel
            final calendarFuture = calendarManager.fetchData();
            final menuFuture = menuManager.fetchData(); // Add menu data refresh

            // Wait for both to complete
            final results = await Future.wait([calendarFuture, menuFuture]);

            // Process results
            final newCalendarData = results[0] as Map<DateTime, CalendarItem>;
            // Menu data is handled automatically by the cache manager

            setState(() {
              _calendarData = newCalendarData;
              _nextScheduleItem = _getNextScheduleItem(newCalendarData);
              _isLoading = false;
              _isLoadingMenu = false; // Update menu loading state
              _errorMessage = null;
              _hasDataLoadError = false;
              _hasMenuLoadError = false;
            });

            // Also refresh games data
            _loadGamesData();
          } catch (error) {
            setState(() {
              _isLoading = false;
              _isLoadingMenu = false; // Update menu loading state
              _errorMessage = _parseErrorMessage(error.toString());
              _hasDataLoadError = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to refresh: ${_parseErrorMessage(error.toString())}',
                ),
                backgroundColor: Theme.of(context).colorScheme.error,
                action: SnackBarAction(
                  label: 'Retry',
                  textColor: Theme.of(context).colorScheme.onError,
                  onPressed: () {
                    _loadCalendarData();
                    _loadGamesData();
                    // Also retry menu data
                    try {
                      menuManager.fetchData();
                    } catch (e) {
                      print('Error refreshing menu data: $e');
                    }
                  },
                ),
              ),
            );
          }
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              automaticallyImplyLeading: false,
              pinned: true,
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: const SizedBox.shrink(),
              flexibleSpace: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  // Calculate scroll progress
                  double progress = 1.0;
                  double height = constraints.maxHeight;
                  final double collapsedHeight =
                      MediaQuery.of(context).padding.top + 35;

                  if (height > collapsedHeight) {
                    final double maxHeight = 145.0;
                    progress =
                        (maxHeight - height) / (maxHeight - collapsedHeight);
                  }

                  // Clamp progress between 0.0 and 1.0
                  progress = progress.clamp(0.0, 1.0);

                  // Calculate opacities for transition
                  final expandedTitleOpacity = (1.0 - progress).clamp(0.0, 1.0);
                  final collapsedTitleOpacity = progress.clamp(0.0, 1.0);

                  return Stack(
                    children: [
                      // Animated linear gradient with moving anchors
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            // Calculate moving positions for gradient anchors
                            final double value = _animationController.value;

                            // Create rectangle motion pattern (moving along edges)
                            // This creates a path that follows the perimeter of the rectangle
                            double beginX, beginY, endX, endY;

                            // First point moves around perimeter
                            if (value < 0.25) {
                              // Top edge: left to right
                              beginX = -1.0 + (value * 8.0); // -1.0 to 1.0
                              beginY = -1.0;
                            } else if (value < 0.5) {
                              // Right edge: top to bottom
                              beginX = 1.0;
                              beginY =
                                  -1.0 + ((value - 0.25) * 8.0); // -1.0 to 1.0
                            } else if (value < 0.75) {
                              // Bottom edge: right to left
                              beginX =
                                  1.0 - ((value - 0.5) * 8.0); // 1.0 to -1.0
                              beginY = 1.0;
                            } else {
                              // Left edge: bottom to top
                              beginX = -1.0;
                              beginY =
                                  1.0 - ((value - 0.75) * 8.0); // 1.0 to -1.0
                            }

                            // Second point moves in opposite direction
                            if (value < 0.25) {
                              // Bottom edge: right to left
                              endX = 1.0 - (value * 8.0); // 1.0 to -1.0
                              endY = 1.0;
                            } else if (value < 0.5) {
                              // Left edge: bottom to top
                              endX = -1.0;
                              endY =
                                  1.0 - ((value - 0.25) * 8.0); // 1.0 to -1.0
                            } else if (value < 0.75) {
                              // Top edge: left to right
                              endX =
                                  -1.0 + ((value - 0.5) * 8.0); // -1.0 to 1.0
                              endY = -1.0;
                            } else {
                              // Right edge: top to bottom
                              endX = 1.0;
                              endY =
                                  -1.0 + ((value - 0.75) * 8.0); // -1.0 to 1.0
                            }

                            // Check if we're in light mode or dark mode
                            final isDarkMode =
                                Theme.of(context).brightness == Brightness.dark;

                            // Select appropriate gradient colors based on theme mode
                            final List<Color> gradientColors = [
                              Color.fromARGB(255, 160, 207, 235),
                              Color.fromARGB(255, 0, 66, 112),
                            ];

                            return Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(beginX, beginY),
                                  end: Alignment(endX, endY),
                                  colors: gradientColors,
                                ),
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(16.0),
                                  bottomRight: Radius.circular(16.0),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Blurred overlay for collapsed state

                      // Expanded title (fades out when scrolling)
                      Positioned(
                        bottom: 16,
                        left: 8,
                        right: 8,
                        child: ClipRect(
                          child: Opacity(
                            opacity: expandedTitleOpacity,
                            child: SizedBox(
                              height: 150,
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      OpacityIconButton(
                                        onPressed:
                                            _showTodayMenuDialog, // Connect to menu dialog
                                        icon: Icons.flatware,
                                        color: Colors.white,
                                      ),
                                      OpacityIconButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) => SettingsPage(),
                                            ),
                                          );
                                        },
                                        icon: Icons.settings_outlined,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                  Spacer(),
                                  InkWell(
                                    onTap:
                                        !_hasDataLoadError
                                            ? _showTodayScheduleDialog
                                            : null,
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        left: 8.0,
                                        right: 8.0,
                                        top: 32,
                                      ),
                                      child: Flex(
                                        direction: Axis.horizontal,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                SizedBox(height: 16),
                                                Row(
                                                  children: [
                                                    Text(
                                                      _hasDataLoadError
                                                          ? 'Data Error'
                                                          : 'Up Next',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    if (_hasDataLoadError) ...[
                                                      SizedBox(width: 8),
                                                      Icon(
                                                        Icons.error_outline,
                                                        color: Colors.white,
                                                        size: 16,
                                                      ),
                                                    ],
                                                    if (_isLoading) ...[
                                                      SizedBox(width: 8),
                                                      SizedBox(
                                                        width: 16,
                                                        height: 16,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          valueColor:
                                                              AlwaysStoppedAnimation<
                                                                Color
                                                              >(Colors.white),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                Text(
                                                  _hasDataLoadError
                                                      ? (_errorMessage ??
                                                          'Failed to load schedule')
                                                      : (_nextScheduleItem
                                                              ?.title ??
                                                          'No upcoming classes'),
                                                  style: TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                if (_hasDataLoadError)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 4.0,
                                                        ),
                                                    child: Text(
                                                      'Pull down to retry',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.white
                                                            .withValues(
                                                              alpha: 0.8,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          if (_nextScheduleItem != null &&
                                              _nextScheduleItem!.title !=
                                                  'No Class' &&
                                              _nextScheduleItem!.title !=
                                                  'Schedule unavailable' &&
                                              !_hasDataLoadError)
                                            Column(
                                              children: [
                                                Text(
                                                  _nextScheduleItem!
                                                      .formatTime(
                                                        _nextScheduleItem!
                                                            .startTime,
                                                      )
                                                      .split(' ')[0],
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                Text(
                                                  '|',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                Text(
                                                  _nextScheduleItem!
                                                      .formatTime(
                                                        _nextScheduleItem!
                                                            .endTime,
                                                      )
                                                      .split(' ')[0],
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Collapsed title (appears when scrolled)
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 4,
                        left: 0,
                        right: 0,
                        child: AnimatedOpacity(
                          opacity: collapsedTitleOpacity,
                          duration: const Duration(milliseconds: 100),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_hasDataLoadError) ...[
                                  Icon(
                                    Icons.error_outline,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: 8),
                                ],
                                Flexible(
                                  child: Text(
                                    _hasDataLoadError
                                        ? (_errorMessage ??
                                            'Schedule unavailable')
                                        : "Up Next: ${_nextScheduleItem?.title ?? 'No upcoming classes'}",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              expandedHeight: 155.0,
              toolbarHeight: 35,
            ),

            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.only(top: 32),
                padding: EdgeInsets.symmetric(horizontal: 16),

                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Recent Games',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_hasGamesError) ...[
                          SizedBox(width: 8),
                          Icon(
                            Icons.error_outline,
                            color: Theme.of(context).colorScheme.error,
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 190,
                child:
                    _isLoadingGames
                        ? Center(child: CircularProgressIndicator())
                        : _hasGamesError
                        ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Could not load games',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                              TextButton(
                                onPressed: _loadGamesData,
                                child: Text('Retry'),
                              ),
                            ],
                          ),
                        )
                        : _recentGames.isEmpty
                        ? Center(
                          child: Text(
                            'No recent games found',
                            style: TextStyle(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        )
                        : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _recentGames.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                right: 16,
                                top: 8,
                                bottom: 8,
                              ),
                              child: GameWidget(game: _recentGames[index]),
                            );
                          },
                        ),
              ),
            ),

            // List all the upcoming assessments within the next 7 days
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.only(top: 32),
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Upcoming Assessments',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_hasDataLoadError) ...[
                          SizedBox(width: 8),
                          Icon(
                            Icons.error_outline,
                            color: Theme.of(context).colorScheme.error,
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Display assessments list
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child:
                    _isLoading
                        ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24.0),
                            child: Column(
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text(
                                  'Loading assessments...',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        : _hasDataLoadError
                        ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24.0),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Failed to load assessments',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  _errorMessage ?? 'Unknown error occurred',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _loadCalendarData,
                                  icon: Icon(Icons.refresh, size: 16),
                                  label: Text('Retry'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primary,
                                    foregroundColor:
                                        Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        : upcomingAssessments.isEmpty
                        ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24.0),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.assignment_outlined,
                                  size: 48,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.3),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No upcoming assessments',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Check back later or refresh to see new assessments',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                        : ListView.separated(
                          physics: NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          padding: EdgeInsets.only(top: 16, bottom: 24),
                          itemCount: upcomingAssessments.length,
                          separatorBuilder:
                              (context, index) => Divider(
                                height: 1,
                                color: Theme.of(context).colorScheme.tertiary,
                              ),
                          itemBuilder: (context, index) {
                            final assessment = upcomingAssessments[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12.0,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          assessment.title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          assessment.className,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 180),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    child: Text(
                                      _formatAssessmentDate(assessment.date),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
              ),
            ),

            // Add space at the bottom
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).viewPadding.bottom + 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Dialog widget for displaying today's schedule
