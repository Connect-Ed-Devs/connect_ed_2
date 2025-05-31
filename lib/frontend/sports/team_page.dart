import 'package:connect_ed_2/classes/standings_list.dart';
import 'package:connect_ed_2/classes/team.dart';
import 'package:connect_ed_2/frontend/setup/app_bar.dart';
import 'package:connect_ed_2/frontend/setup/segmented_button.dart';
import 'package:connect_ed_2/classes/game.dart'; // Added for Game
import 'package:connect_ed_2/frontend/sports/game_widgets.dart'; // Added for GameWidget
import 'package:connect_ed_2/classes/standings_item.dart'; // Added for StandingsItem
import 'package:connect_ed_2/frontend/sports/standings.dart'; // Added for StandingsTable
import 'package:connect_ed_2/requests/games_cache_manager.dart'; // Import for games
import 'package:connect_ed_2/requests/standings_cache_manager.dart'; // Import for standings
import 'package:flutter/material.dart';

// Define an enum for the segments
enum TeamInfoSegment { upcoming, scores, standings, roster }

class _SegmentedButtonHeaderDelegate extends SliverPersistentHeaderDelegate {
  final CustomSegmentedButton<TeamInfoSegment> segmentedButton;
  final double height;

  _SegmentedButtonHeaderDelegate({
    required this.segmentedButton,
    required this.height,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor, // Match page background
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: segmentedButton,
    );
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant _SegmentedButtonHeaderDelegate oldDelegate) {
    return segmentedButton != oldDelegate.segmentedButton ||
        height != oldDelegate.height;
  }
}

class TeamPage extends StatefulWidget {
  final Team team;
  final String? leagueCode; // Add league code parameter

  const TeamPage({
    super.key,
    required this.team,
    this.leagueCode, // Make it optional to maintain compatibility
  });

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  TeamInfoSegment _selectedSegment = TeamInfoSegment.upcoming;

  // Data states
  bool _isLoadingGames = true;
  bool _isLoadingStandings = true;
  bool _hasGamesError = false;
  bool _hasStandingsError = false;
  List<Game> _upcomingGames = [];
  List<Game> _playedGames = [];
  List<StandingsItem> _standingsData = [];

  // Add a variable to store the league code
  String? _leagueCode;

  @override
  void initState() {
    super.initState();
    _leagueCode = widget.leagueCode; // Store league code
    _loadGamesData();
    _loadStandingsData();
  }

  // Load games data
  Future<void> _loadGamesData() async {
    setState(() {
      _isLoadingGames = true;
      _hasGamesError = false;
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

      // Process games data - filter for the specific league if provided, otherwise filter by team name
      if (cachedGames != null) {
        final now = DateTime.now();
        List<Game> allTeamGames = [];

        if (_leagueCode != null) {
          // If league code is provided, filter by league code
          allTeamGames =
              cachedGames.values
                  .where((game) => game.leagueCode == _leagueCode)
                  .toList();
        } else {
          // If no league code, filter by team name
          allTeamGames =
              cachedGames.values
                  .where(
                    (game) =>
                        game.homeTeam == widget.team.name ||
                        game.awayTeam == widget.team.name,
                  )
                  .toList();
        }

        // Sort all games by date
        allTeamGames.sort((a, b) => a.date.compareTo(b.date));

        // Split into upcoming and played games
        List<Game> upcoming =
            allTeamGames.where((game) {
              return game.date.isAfter(now) ||
                  (game.homeScore == '-' && game.awayScore == '-');
            }).toList();

        List<Game> played =
            allTeamGames.where((game) {
              return game.date.isBefore(now) &&
                  game.homeScore != '-' &&
                  game.awayScore != '-';
            }).toList();

        // Sort played games by date descending (most recent first)
        played.sort((a, b) => b.date.compareTo(a.date));

        setState(() {
          _upcomingGames = upcoming;
          _playedGames = played;
          _isLoadingGames = false;
        });
      }
    } catch (error) {
      setState(() {
        _isLoadingGames = false;
        _hasGamesError = true;
      });
      print('Error loading games: $error');
    }
  }

  // Load standings data
  // Future<void> _loadStandingsData() async {
  //   setState(() {
  //     _isLoadingStandings = true;
  //     _hasStandingsError = false;
  //   });

  //   try {
  //     // Get cached data first
  //     Map<String, StandingsList>? cachedStandings;
  //     try {
  //       cachedStandings = standingsManager.getCachedData();
  //     } catch (e) {
  //       print('Error accessing cached standings: $e');
  //     }

  //     // If no cached data, fetch fresh
  //     if (cachedStandings == null) {
  //       cachedStandings = await standingsManager.fetchData();
  //     }

  //     // Process standings data
  //     if (cachedStandings != null) {
  //       if (_leagueCode != null && cachedStandings.containsKey(_leagueCode)) {
  //         // If we have a league code and it exists in the standings data
  //         final standingsList = cachedStandings[_leagueCode!];
  //         if (standingsList != null) {
  //           setState(() {
  //             _standingsData = standingsList.standings;
  //             _isLoadingStandings = false;
  //           });
  //         } else {
  //           setState(() {
  //             _standingsData = [];
  //             _isLoadingStandings = false;
  //           });
  //         }
  //       } else {
  //         // If no league code or league code not found, search through all standings
  //         StandingsList? teamStandings;

  //         // Loop through all standings lists to find one with our team
  //         for (var standings in cachedStandings.values) {
  //           if (standings.standings.any((item) => item.teamName == widget.team.name)) {
  //             teamStandings = standings;
  //             // Store the league code for future reference if not already set
  //             if (_leagueCode == null) {
  //               _leagueCode =
  //                   cachedStandings.entries
  //                       .firstWhere(
  //                         (entry) => entry.value == teamStandings,
  //                         orElse: () => MapEntry('unknown', teamStandings!),
  //                       )
  //                       .key;
  //             }
  //             break;
  //           }
  //         }

  //         if (teamStandings != null) {
  //           setState(() {
  //             _standingsData = teamStandings!.standings;
  //             _isLoadingStandings = false;
  //           });
  //         } else {
  //           setState(() {
  //             _standingsData = [];
  //             _isLoadingStandings = false;
  //           });
  //         }
  //       }
  //     }
  //   } catch (error) {
  //     setState(() {
  //       _isLoadingStandings = false;
  //       _hasStandingsError = true;
  //     });
  //     print('Error loading standings: $error');
  //   }
  // }

  Future<void> _loadStandingsData() async {
    print('===== STANDINGS DEBUG =====');
    print('Starting _loadStandingsData()');
    print('Game leagueCode: ${widget.team.leagueCode}');

    setState(() {
      _isLoadingStandings = true;
      _hasStandingsError = false;
    });

    try {
      // Get cached data first
      Map<String, StandingsList>? cachedStandings;
      try {
        print('Attempting to get cached standings data');
        cachedStandings = standingsManager.getCachedData();
        if (cachedStandings != null) {
          print('Got cached standings: ${cachedStandings.length} league(s)');
          print('Available leagues: ${cachedStandings.keys.join(', ')}');
        } else {
          print('No cached standings data available');
        }
      } catch (e) {
        print('Error accessing cached standings: $e');
      }

      // If no cached data, fetch fresh
      if (cachedStandings == null) {
        print('Fetching fresh standings data from network');
        cachedStandings = await standingsManager.fetchData();
        print(
          'Fresh standings data fetched: ${cachedStandings?.length} league(s)',
        );
        print('Available leagues: ${cachedStandings?.keys.join(', ')}');
      }

      // Find standings for this league
      final leagueCode = widget.team.leagueCode;
      print('Looking for standings with league code: $leagueCode');

      if (cachedStandings != null && cachedStandings.containsKey(leagueCode)) {
        print('League code $leagueCode found in standings data');

        final standingsList = cachedStandings[leagueCode];
        if (standingsList != null) {
          print(
            'StandingsList for $leagueCode contains ${standingsList.standings.length} team(s)',
          );

          setState(() {
            _standingsData = standingsList.standings;
            _isLoadingStandings = false;
          });
          print('Standings data loaded successfully');
        } else {
          print('ERROR: StandingsList for $leagueCode is null (unexpected)');
          setState(() {
            _isLoadingStandings = false;
            _hasStandingsError = true;
          });
        }
      } else {
        print('ERROR: League code $leagueCode not found in standings data');
        print(
          'Available leagues: ${cachedStandings?.keys.join(', ') ?? 'none'}',
        );

        setState(() {
          _isLoadingStandings = false;
          _hasStandingsError = true;
        });
      }
    } catch (error) {
      print('ERROR in standings data loading: $error');
      setState(() {
        _isLoadingStandings = false;
        _hasStandingsError = true;
      });
    }
    print('===== END STANDINGS DEBUG =====');
  }

  // Helper method to build loading/error/empty state
  Widget _buildLoadingOrErrorState(
    bool isLoading,
    bool hasError,
    String emptyMessage,
  ) {
    if (isLoading) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (hasError) {
      return SliverToBoxAdapter(
        child: Container(
          height: 200,
          padding: EdgeInsets.all(16),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                  size: 36,
                ),
                SizedBox(height: 8),
                Text(
                  'Failed to load data',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Container(
        height: 200,
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text(
            emptyMessage,
            style: TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }

  // Placeholder widgets for different segments
  Widget _buildSegmentContent(TeamInfoSegment segment) {
    switch (segment) {
      case TeamInfoSegment.upcoming:
        if (_isLoadingGames) {
          return _buildLoadingOrErrorState(true, false, '');
        }

        if (_hasGamesError) {
          return _buildLoadingOrErrorState(false, true, '');
        }

        if (_upcomingGames.isEmpty) {
          return _buildLoadingOrErrorState(
            false,
            false,
            'No upcoming games for this team',
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.all(16.0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              mainAxisExtent: 190.0,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => GameWidget(game: _upcomingGames[index]),
              childCount: _upcomingGames.length,
            ),
          ),
        );

      case TeamInfoSegment.scores:
        if (_isLoadingGames) {
          return _buildLoadingOrErrorState(true, false, '');
        }

        if (_hasGamesError) {
          return _buildLoadingOrErrorState(false, true, '');
        }

        if (_playedGames.isEmpty) {
          return _buildLoadingOrErrorState(
            false,
            false,
            'No completed games for this team',
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.all(16.0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              mainAxisExtent: 190.0,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => GameWidget(game: _playedGames[index]),
              childCount: _playedGames.length,
            ),
          ),
        );

      case TeamInfoSegment.standings:
        if (_isLoadingStandings) {
          return _buildLoadingOrErrorState(true, false, '');
        }

        if (_hasStandingsError) {
          return _buildLoadingOrErrorState(false, true, '');
        }

        if (_standingsData.isEmpty) {
          return _buildLoadingOrErrorState(
            false,
            false,
            'No standings data available',
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.all(16.0),
          sliver: SliverToBoxAdapter(
            child: StandingsTable(
              standings: _standingsData,
              homeTeamName: widget.team.name,
            ),
          ),
        );

      case TeamInfoSegment.roster:
        // For now, keep the roster as a placeholder
        return SliverPadding(
          padding: const EdgeInsets.all(16.0),
          sliver: SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: Center(
                child: Text(
                  'Roster information coming soon',
                  style: TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String displayRecord = '#${widget.team.rank}\n${widget.team.record}';
    final theme = Theme.of(context);

    // Calculate the height of the segmented button for the delegate
    // This is an estimate; actual height might depend on text style and padding.
    // A more robust way would be to measure it or use a fixed known height.
    const double segmentedButtonHeight =
        kMinInteractiveDimension; // Approx 48.0

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          CEAppBar(
            title: 'Team Info', // Or dynamically set based on team if needed
            showBackButton: true,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color:
                      Theme.of(
                        context,
                      ).colorScheme.tertiary, // Or theme.colorScheme.tertiary
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.team.name,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          widget.team.sportIcon,
                          size: 36,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rank',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                            Text(
                              '#${widget.team.rank}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 24),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Record',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                            Text(
                              widget.team.record,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SegmentedButtonHeaderDelegate(
              height: segmentedButtonHeight, // Adjust as needed
              segmentedButton: CustomSegmentedButton<TeamInfoSegment>(
                segments: const [
                  ButtonSegment(
                    value: TeamInfoSegment.upcoming,
                    label: Text('Upcoming'),
                  ),
                  ButtonSegment(
                    value: TeamInfoSegment.scores,
                    label: Text('Scores'),
                  ),
                  ButtonSegment(
                    value: TeamInfoSegment.standings,
                    label: Text('Standings'),
                  ),
                ],
                selected: {_selectedSegment},
                onSelectionChanged: (Set<TeamInfoSegment> newSelection) {
                  setState(() {
                    _selectedSegment = newSelection.first;
                  });
                },
              ),
            ),
          ),
          _buildSegmentContent(_selectedSegment),
        ],
      ),
    );
  }
}
