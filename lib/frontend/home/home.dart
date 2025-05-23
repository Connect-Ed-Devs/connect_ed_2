import 'dart:ui';
import 'dart:math'; // Added for max function in dialog

import 'package:connect_ed_2/classes/assessment.dart';
import 'package:connect_ed_2/classes/calendar_item.dart';
import 'package:connect_ed_2/classes/game.dart';
import 'package:connect_ed_2/classes/schedule_item.dart';
import 'package:connect_ed_2/frontend/home/today_schedule.dart';
import 'package:connect_ed_2/frontend/settings/settings.dart';
import 'package:connect_ed_2/frontend/setup/app_bar.dart';
import 'package:connect_ed_2/frontend/setup/opacity_button.dart';
import 'package:connect_ed_2/frontend/sports/game_widgets.dart';
import 'package:connect_ed_2/requests/cache_manager.dart';
import 'package:connect_ed_2/requests/calendar_requests.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  // Animation controller for the gradient
  late AnimationController _animationController;

  // Add calendar data variables
  Map<DateTime, CalendarItem>? _calendarData;
  ScheduleItem? _nextScheduleItem;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // Initialize the animation controller with a very slow rotation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15), // 2 minutes for very subtle movement
    )..repeat(reverse: true); // Add reverse for smooth back-and-forth

    // Load calendar data when the widget initializes
    _loadCalendarData();
  }

  // Load calendar data from the cache manager
  void _loadCalendarData() {
    setState(() {
      _isLoading = true;
    });

    // Get data from calendar manager
    final cacheStatus = calendarManager.getCacheStatus();

    if (cacheStatus != CacheStatus.expired) {
      _calendarData = calendarManager.getCachedData();
      setState(() {
        _nextScheduleItem = _getNextScheduleItem(_calendarData!);
        _isLoading = false;
      });
    } else {
      // Fetch fresh data if expired
      calendarManager
          .fetchData()
          .then((data) {
            setState(() {
              _calendarData = data;
              _nextScheduleItem = _getNextScheduleItem(data);
              _isLoading = false;
            });
          })
          .catchError((error) {
            setState(() {
              _isLoading = false;
            });
          });
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
      if (date.isAfter(normalizedNow.subtract(const Duration(days: 1))) && date.isBefore(nextWeek)) {
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

    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return "Today";
    } else if (date.year == tomorrow.year && date.month == tomorrow.month && date.day == tomorrow.day) {
      return "Tomorrow";
    } else {
      // Format as "Mon, Jan 15"
      return DateFormat('E, MMM d').format(date);
    }
  }

  // Find the next schedule item
  ScheduleItem? _getNextScheduleItem(Map<DateTime, CalendarItem> calendarData) {
    print("--- _getNextScheduleItem called ---");
    if (calendarData.isEmpty) {
      print("Calendar data is empty.");
      return null;
    }

    final now = DateTime.now();
    final currentTime = TimeOfDay.fromDateTime(now);
    print("Current DateTime: $now, Current TimeOfDay: $currentTime");

    // First check today's schedule
    final today = DateTime(now.year, now.month, now.day);
    print("Checking for today's schedule: $today");

    if (calendarData.containsKey(today)) {
      print("Found schedule for today.");
      final todaySchedule = List<ScheduleItem>.from(calendarData[today]!.schedule);

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
          final itemStartMinutes = item.startTime.hour * 60 + item.startTime.minute;
          final currentMinutes = currentTime.hour * 60 + currentTime.minute;

          print(
            "  Comparing Today: ${item.title} (${item.startTime}) -> ${itemStartMinutes} min > ${currentMinutes} min (current)?",
          );

          if (itemStartMinutes > currentMinutes) {
            print("    -> YES. Next class today: ${item.title} at ${item.startTime}");
            return item; // This is the next class today
          } else {
            print("    -> NO. Class has passed or is ongoing.");
          }
        }
        print("No suitable next class found for today after checking all items.");
      }
    } else {
      print("No schedule data found for today.");
    }

    // If no class found today, check tomorrow
    return ScheduleItem(
      title: "No Class",
      startTime: TimeOfDay(hour: 0, minute: 0),
      endTime: TimeOfDay(hour: 0, minute: 0),
    );
  }

  void _showTodayScheduleDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return TodayScheduleDialog(calendarData: _calendarData, dateToShow: DateTime.now());
      },
    );
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
          });

          try {
            final newData = await calendarManager.fetchData();
            setState(() {
              _calendarData = newData;
              _nextScheduleItem = _getNextScheduleItem(newData);
              _isLoading = false;
            });
          } catch (error) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Failed to refresh data: ${error.toString()}')));
          }
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              automaticallyImplyLeading: false,
              pinned: true,
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: const SizedBox.shrink(), // Clear default title
              flexibleSpace: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  // Calculate scroll progress
                  double progress = 1.0;
                  double height = constraints.maxHeight;
                  final double collapsedHeight = MediaQuery.of(context).padding.top + 35; // Increased by 9 pts

                  if (height > collapsedHeight) {
                    final double maxHeight = 145.0; // Increased by 9 pts
                    progress = (maxHeight - height) / (maxHeight - collapsedHeight);
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
                              beginY = -1.0 + ((value - 0.25) * 8.0); // -1.0 to 1.0
                            } else if (value < 0.75) {
                              // Bottom edge: right to left
                              beginX = 1.0 - ((value - 0.5) * 8.0); // 1.0 to -1.0
                              beginY = 1.0;
                            } else {
                              // Left edge: bottom to top
                              beginX = -1.0;
                              beginY = 1.0 - ((value - 0.75) * 8.0); // 1.0 to -1.0
                            }

                            // Second point moves in opposite direction
                            if (value < 0.25) {
                              // Bottom edge: right to left
                              endX = 1.0 - (value * 8.0); // 1.0 to -1.0
                              endY = 1.0;
                            } else if (value < 0.5) {
                              // Left edge: bottom to top
                              endX = -1.0;
                              endY = 1.0 - ((value - 0.25) * 8.0); // 1.0 to -1.0
                            } else if (value < 0.75) {
                              // Top edge: left to right
                              endX = -1.0 + ((value - 0.5) * 8.0); // -1.0 to 1.0
                              endY = -1.0;
                            } else {
                              // Right edge: top to bottom
                              endX = 1.0;
                              endY = -1.0 + ((value - 0.75) * 8.0); // -1.0 to 1.0
                            }

                            // Check if we're in light mode or dark mode
                            final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
                              height: 155,
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      IconButton(onPressed: () {}, icon: Icon(Icons.flatware, color: Colors.white)),
                                      IconButton(
                                        onPressed: () {
                                          // Open settings page
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (context) => SettingsPage()),
                                          );
                                        },
                                        icon: Icon(Icons.settings_outlined, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                  Spacer(),
                                  InkWell(
                                    onTap: _showTodayScheduleDialog,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 32),
                                      child: Flex(
                                        direction: Axis.horizontal,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                SizedBox(height: 16),
                                                Text(
                                                  "Up Next",
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                Text(
                                                  _nextScheduleItem?.title ?? "No upcoming classes",
                                                  style: TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (_nextScheduleItem != null && _nextScheduleItem!.title != "No Class")
                                            Column(
                                              children: [
                                                Text(
                                                  _nextScheduleItem!
                                                      .formatTime(_nextScheduleItem!.startTime)
                                                      .split(" ")[0],
                                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                                ),
                                                Text(
                                                  "|",
                                                  style: TextStyle(color: Colors.white),
                                                ),
                                                Text(
                                                  _nextScheduleItem!
                                                      .formatTime(_nextScheduleItem!.endTime)
                                                      .split(" ")[0],
                                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
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
                            child: Text(
                              "Up Next: ${_nextScheduleItem?.title ?? 'No upcoming classes'}",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              expandedHeight: 155.0, // Increased by 9 pts
              toolbarHeight: 35, // Increased by 9 pts
            ),

            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.only(top: 32),
                padding: EdgeInsets.symmetric(horizontal: 16),

                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text("Recent Games", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500))],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                height: 190,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 5,
                  itemBuilder: (context, index) {
                    // Define 5 unique games
                    final List<Game> games = [
                      Game(
                        homeTeam: "Eagles",
                        homeabbr: "EAG",
                        homeLogo: "assets/team_a_logo.png",
                        awayTeam: "Tigers",
                        awayabbr: "TIG",
                        awayLogo: "assets/team_b_logo.png",
                        date: DateTime.now().add(Duration(days: 2)),
                        time: "6:30 PM",
                        homeScore: "24",
                        awayScore: "21",
                        sportsID: 1,
                        sportsName: "Football",
                        term: "Fall 2023",
                        leagueCode: "NCAA",
                      ),
                      Game(
                        homeTeam: "Warriors",
                        homeabbr: "WAR",
                        homeLogo: "assets/team_a_logo.png",
                        awayTeam: "Bulls",
                        awayabbr: "BUL",
                        awayLogo: "assets/team_b_logo.png",
                        date: DateTime.now().add(Duration(days: 5)),
                        time: "7:00 PM",
                        homeScore: "85",
                        awayScore: "79",
                        sportsID: 2,
                        sportsName: "Basketball",
                        term: "Fall 2023",
                        leagueCode: "NCAA",
                      ),
                      Game(
                        homeTeam: "Lions",
                        homeabbr: "LIO",
                        homeLogo: "assets/team_a_logo.png",
                        awayTeam: "Cobras",
                        awayabbr: "COB",
                        awayLogo: "assets/team_b_logo.png",
                        date: DateTime.now().add(Duration(days: 1)),
                        time: "5:00 PM",
                        homeScore: "2",
                        awayScore: "1",
                        sportsID: 3,
                        sportsName: "Soccer",
                        term: "Fall 2023",
                        leagueCode: "NCAA",
                      ),
                      Game(
                        homeTeam: "Sharks",
                        homeabbr: "SHK",
                        homeLogo: "assets/team_a_logo.png",
                        awayTeam: "Wolves",
                        awayabbr: "WLV",
                        awayLogo: "assets/team_b_logo.png",
                        date: DateTime.now().add(Duration(days: 3)),
                        time: "4:15 PM",
                        homeScore: "3",
                        awayScore: "0",
                        sportsID: 4,
                        sportsName: "Volleyball",
                        term: "Fall 2023",
                        leagueCode: "NCAA",
                      ),
                      Game(
                        homeTeam: "Ravens",
                        homeabbr: "RAV",
                        homeLogo: "assets/team_a_logo.png",
                        awayTeam: "Panthers",
                        awayabbr: "PAN",
                        awayLogo: "assets/team_b_logo.png",
                        date: DateTime.now().add(Duration(days: 7)),
                        time: "2:00 PM",
                        homeScore: "5",
                        awayScore: "3",
                        sportsID: 5,
                        sportsName: "Baseball",
                        term: "Fall 2023",
                        leagueCode: "NCAA",
                      ),
                    ];

                    return Padding(
                      padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                      child: GameWidget(game: games[index]),
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
                  children: [Text("Upcoming Assessments", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500))],
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
                            child: CircularProgressIndicator(),
                          ),
                        )
                        : upcomingAssessments.isEmpty
                        ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24.0),
                            child: Text(
                              "No upcoming assessments this week",
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                              ),
                            ),
                          ),
                        )
                        : ListView.separated(
                          physics: NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          padding: EdgeInsets.only(top: 16, bottom: 24),
                          itemCount: upcomingAssessments.length,
                          separatorBuilder:
                              (context, index) => Divider(height: 1, color: Theme.of(context).colorScheme.tertiary),
                          itemBuilder: (context, index) {
                            final assessment = upcomingAssessments[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Date indicator

                                  // Assessment details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(assessment.title, style: TextStyle(fontWeight: FontWeight.w500)),
                                        SizedBox(height: 2),
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
                                  Container(
                                    child: Text(
                                      _formatAssessmentDate(assessment.date),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Theme.of(context).colorScheme.primary,
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
            SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 24)),
          ],
        ),
      ),
    );
  }
}

// Dialog widget for displaying today's schedule
