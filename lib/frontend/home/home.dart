import 'dart:ui';
import 'package:connect_ed_2/classes/assessment.dart';
import 'package:connect_ed_2/classes/calendar_item.dart';
import 'package:connect_ed_2/classes/game.dart';
import 'package:connect_ed_2/classes/menu_section.dart';
import 'package:connect_ed_2/classes/schedule_item.dart';
import 'package:connect_ed_2/frontend/home/today_schedule.dart';
import 'package:connect_ed_2/frontend/setup/opacity_button.dart';
import 'package:connect_ed_2/frontend/sports/game_widgets.dart';
import 'package:connect_ed_2/main.dart';
import 'package:connect_ed_2/requests/cache_manager.dart';
import 'package:connect_ed_2/requests/calendar_requests.dart';
import 'package:connect_ed_2/requests/games_cache_manager.dart';
import 'package:connect_ed_2/requests/menu_cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Add game data variables
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
  Future<void> _loadCalendarData() async {
    // Always load cached data first to display immediately (never show loading/error)
    try {
      final cachedString = prefs.getString('calendar_data');
      if (cachedString != null && cachedString.isNotEmpty) {
        final cachedData = calendarManager.decodeData(cachedString);
        if (cachedData != null && cachedData.isNotEmpty) {
          setState(() {
            _calendarData = cachedData;
            _nextScheduleItem = _getNextScheduleItem(cachedData);
          });
        }
      }
    } catch (e) {
      print('Error loading cached calendar data: $e');
    }

    // Silently try to fetch fresh data in the background to update the cache
    try {
      final freshData = await calendarManager.fetchData();
      setState(() {
        _calendarData = freshData;
        _nextScheduleItem = _getNextScheduleItem(freshData);
      });
    } catch (error) {
      // Silently fail - keep showing cached data
      print('Could not fetch fresh data (using cached): $error');
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
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Schedule',
      barrierColor: Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return TodayScheduleDialog(
          calendarData: _calendarData,
          dateToShow: DateTime.now(),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        // Fade animation
        final fadeAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));

        // Scale animation - subtle zoom in effect
        final scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );

        // Blur animation
        final blurAnimation = Tween<double>(
          begin: 0.0,
          end: 10.0,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));

        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blurAnimation.value,
            sigmaY: blurAnimation.value,
          ),
          child: FadeTransition(
            opacity: fadeAnimation,
            child: ScaleTransition(scale: scaleAnimation, child: child),
          ),
        );
      },
    );
  }

  void _showTodayMenuDialog() async {
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
      if (mounted) Navigator.of(context).pop();

      // Check if today's menu exists
      List<MenuSection>? todayMenu = menuData?[today];

      if (todayMenu == null || todayMenu.isEmpty) {
        _showNoMenuDialog();
      } else {
        _navigateToMenuPage(todayMenu);
      }
    } catch (e) {
      // Close loading dialog
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      _showMenuErrorDialog(e.toString());
    }
  }

  void _navigateToMenuPage(List<MenuSection> menuSections) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder:
            (context, animation, secondaryAnimation) =>
                MenuDialog(menuSections: menuSections),
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Curved animations for smooth effect
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
            reverseCurve: Curves.easeInOutCubic,
          );

          // Scale animation - expands from small to full screen
          final scaleAnimation = Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(curvedAnimation);

          // Fade animation for smooth appearance
          final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: Interval(0.0, 0.5, curve: Curves.easeOut),
            ),
          );

          // Slide animation - subtle upward movement
          final slideAnimation = Tween<Offset>(
            begin: const Offset(0, 0.1),
            end: Offset.zero,
          ).animate(curvedAnimation);

          return FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(
              position: slideAnimation,
              child: ScaleTransition(scale: scaleAnimation, child: child),
            ),
          );
        },
      ),
    );
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

  // Load games data from the cache manager
  Future<void> _loadGamesData() async {
    // Always load cached data first to display immediately (never show loading/error)
    try {
      final cachedString = prefs.getString('games_data');
      if (cachedString != null && cachedString.isNotEmpty) {
        final cachedGames = gamesManager.decodeData(cachedString);
        if (cachedGames != null && cachedGames.isNotEmpty) {
          List<Game> playedGames =
              cachedGames.values
                  .where(
                    (game) => game.homeScore != '-' && game.awayScore != '-',
                  )
                  .toList();
          playedGames.sort((a, b) => b.date.compareTo(a.date));

          setState(() {
            _recentGames = playedGames.take(5).toList();
          });
        }
      }
    } catch (e) {
      print('Error loading cached games: $e');
    }

    // Silently try to fetch fresh data in the background to update the cache
    try {
      final freshGames = await gamesManager.fetchData();
      List<Game> playedGames =
          freshGames.values
              .where((game) => game.homeScore != '-' && game.awayScore != '-')
              .toList();
      playedGames.sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        _recentGames = playedGames.take(5).toList();
      });
    } catch (error) {
      // Silently fail - keep showing cached data
      print('Could not fetch fresh games (using cached): $error');
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
          // Simply reload all data - loading happens silently with cached data shown
          await _loadCalendarData();
          await _loadGamesData();
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
                    final double maxHeight = 175.0;
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

                            // Gradient colors for the app bar
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
                              height: 170,
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      OpacityIconButton(
                                        onPressed:
                                            _showTodayMenuDialog, // Connect to menu dialog
                                        icon: Icons.restaurant,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                                  Spacer(),
                                  InkWell(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      _showTodayScheduleDialog();
                                    },
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
                                                Text(
                                                  'Up Next',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                Text(
                                                  _nextScheduleItem?.title ??
                                                      'No upcoming classes',
                                                  // Real campus names are long
                                                  // ("AP English Language &\nComposition"). Unbounded, they
                                                  // wrap to a second line that
                                                  // runs past the bottom of the
                                                  // fixed-height header and
                                                  // trips a RenderFlex overflow.
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (_nextScheduleItem != null &&
                                              _nextScheduleItem!.title !=
                                                  'No Class' &&
                                              _nextScheduleItem!.title !=
                                                  'Schedule unavailable')
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
                          // NOTE: this used to be a `Flexible` inside a
                          // `Center`. `Flexible` only makes sense directly
                          // inside a Flex, so it threw a ParentDataWidget
                          // assertion on every frame. `Positioned` already
                          // bounds the width, so plain padding is enough for
                          // the ellipsis to kick in.
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(
                                "Up Next: ${_nextScheduleItem?.title ?? 'No upcoming classes'}",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              expandedHeight: 175.0,
              toolbarHeight: 35,
            ),

            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.only(top: 32),
                padding: EdgeInsets.symmetric(horizontal: 16),

                child: Text(
                  'Recent Games',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 190,
                child:
                    _recentGames.isEmpty
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
                child: Text(
                  'Upcoming Assessments',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
                ),
              ),
            ),

            // Display assessments list
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child:
                    upcomingAssessments.isEmpty
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
                                  Text(
                                    _formatAssessmentDate(assessment.date),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color:
                                          Theme.of(context).colorScheme.primary,
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
