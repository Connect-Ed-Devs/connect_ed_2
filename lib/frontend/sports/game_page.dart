import 'package:connect_ed_2/classes/game.dart';
import 'package:connect_ed_2/classes/standings_list.dart';
import 'package:connect_ed_2/frontend/setup/app_bar.dart';
import 'package:connect_ed_2/frontend/sports/game_widgets.dart';
import 'package:connect_ed_2/frontend/sports/standings.dart';
import 'package:connect_ed_2/classes/standings_item.dart';
import 'package:connect_ed_2/frontend/setup/segmented_button.dart';
import 'package:connect_ed_2/requests/games_cache_manager.dart';
import 'package:connect_ed_2/requests/standings_cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum GameInfoSegment { standings, upcomingGames }

class GamePage extends StatefulWidget {
  final Game game;

  // Constructor now requires a Game object
  const GamePage({super.key, required this.game});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  GameInfoSegment _selectedSegment = GameInfoSegment.upcomingGames;

  // Data states
  bool _isLoadingGames = true;
  bool _isLoadingStandings = true;
  bool _hasGamesError = false;
  bool _hasStandingsError = false;
  List<Game> _upcomingGames = [];
  List<StandingsItem> _standingsData = [];
  String _sportName = '';

  @override
  void initState() {
    super.initState();
    _loadGameData();
    _loadStandingsData();
  }

  // Load upcoming games for the same sport
  Future<void> _loadGameData() async {
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

      // Filter games by same sport and upcoming dates
      final now = DateTime.now();
      final List<Game> filteredGames =
          cachedGames?.values
              .where(
                (game) =>
                    game.sportsName == widget.game.sportsName &&
                    (game.date.isAfter(now) ||
                        (game.homeScore == '-' && game.awayScore == '-')),
              )
              .toList() ??
          [];

      // Sort by date (closest first)
      filteredGames.sort((a, b) => a.date.compareTo(b.date));

      setState(() {
        // Take up to 5 games
        _upcomingGames = filteredGames.take(5).toList();
        _sportName = widget.game.sportsName;
        _isLoadingGames = false;
      });
    } catch (error) {
      setState(() {
        _isLoadingGames = false;
        _hasGamesError = true;
      });
      print('Error loading games: $error');
    }
  }

  // Load standings data
  Future<void> _loadStandingsData() async {
    print('===== STANDINGS DEBUG =====');
    print('Starting _loadStandingsData()');
    print('Game leagueCode: ${widget.game.leagueCode}');

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
      final leagueCode = widget.game.leagueCode;
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

  // Format date to "Month D, YYYY" format
  String _formatDate(DateTime date) {
    return DateFormat('MMMM d, yyyy').format(date);
  }

  // Helper method to format time by removing AM/PM
  String _formatTime(String time) {
    // Simply remove AM/PM from the time string
    return time
        .replaceAll('AM', '')
        .replaceAll('PM', '')
        .replaceAll('am', '')
        .replaceAll('pm', '')
        .trim();
  }

  Widget _buildUpcomingGamesContent() {
    if (_isLoadingGames) {
      return SizedBox(
        height: 190,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasGamesError) {
      return Container(
        height: 190,
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
                'Failed to load upcoming games',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_upcomingGames.isEmpty) {
      return Container(
        height: 190,
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text(
            'No upcoming games scheduled',
            style: TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 190,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        itemCount: _upcomingGames.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GameWidget(game: _upcomingGames[index]),
          );
        },
      ),
    );
  }

  Widget _buildStandingsContent() {
    if (_isLoadingStandings) {
      return SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasStandingsError) {
      return Container(
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
                'Failed to load standings data',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_standingsData.isEmpty) {
      return Container(
        height: 200,
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text(
            'No standings data available',
            style: TextStyle(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: StandingsTable(
        standings: _standingsData,
        homeTeamName: widget.game.homeTeam,
        opposingTeamName: widget.game.awayTeam,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          CEAppBar(
            title: '${widget.game.homeabbr} v ${widget.game.awayabbr}',
            showBackButton: true,
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(
                    // Show "Final" for games with scores, otherwise "Upcoming"
                    widget.game.homeScore != '-' && widget.game.awayScore != '-'
                        ? 'Final'
                        : 'Upcoming',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 16,
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(16),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    spacing: 16,
                    children: [
                      // Home team
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Replace the color box with the team logo
                          _buildTeamLogo(widget.game.homeabbr),
                          SizedBox(height: 8),
                          Text(
                            widget.game.homeabbr,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.7),
                              fontSize: 16,
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      // Score section
                      SizedBox(
                        width: 140,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '${_formatDate(widget.game.date)} | ${_formatTime(widget.game.time)}',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.7),
                                fontSize: 12,
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    _formatScore(widget.game.homeScore),
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'V',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    _formatScore(widget.game.awayScore),
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              widget.game.sportsName.toUpperCase(),
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.7),
                                fontSize: 12,
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Away team
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Replace the color box with the team logo
                          _buildTeamLogo(widget.game.awayabbr),
                          SizedBox(height: 8),
                          Text(
                            widget.game.awayabbr,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.7),
                              fontSize: 16,
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: Container(
              // Remove horizontal padding to allow SegmentedButton to go edge-to-edge
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              margin: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: CustomSegmentedButton<GameInfoSegment>(
                      // Use the new CustomSegmentedButton
                      segments: const <ButtonSegment<GameInfoSegment>>[
                        ButtonSegment<GameInfoSegment>(
                          value: GameInfoSegment.upcomingGames,
                          label: Text(
                            'Upcoming',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        ButtonSegment<GameInfoSegment>(
                          value: GameInfoSegment.standings,
                          label: Text(
                            'Standings',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                      selected: <GameInfoSegment>{_selectedSegment},
                      onSelectionChanged: (Set<GameInfoSegment> newSelection) {
                        setState(() {
                          _selectedSegment = newSelection.first;
                        });
                      },
                      // The style is now part of CustomSegmentedButton's default,
                      // but can be overridden here if needed via its 'style' parameter.
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_selectedSegment == GameInfoSegment.upcomingGames)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 8,
                  bottom: 8.0,
                ),
                child: Text(
                  'Upcoming Games',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          if (_selectedSegment == GameInfoSegment.standings)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 8,
                  bottom: 8.0,
                ),
                child: Text(
                  'Standings',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child:
                _selectedSegment == GameInfoSegment.upcomingGames
                    ? _buildUpcomingGamesContent()
                    : _buildStandingsContent(),
          ),

          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).viewPadding.bottom + 24,
            ),
          ), // Ensure space at bottom
        ],
      ),
    );
  }

  // Helper method to format scores
  String _formatScore(String score) {
    return score == '-' ? '--' : score;
  }

  // Helper method to build team logo
  Widget _buildTeamLogo(String abbr) {
    return SizedBox(
      width: 64,
      height: 60,
      child: Image.asset(
        'assets/$abbr Logo.png',
        errorBuilder: (context, error, stackTrace) {
          // If image not found, show a placeholder
          return Container(
            width: 64,
            height: 60,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                Icons.shield_outlined,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        },
      ),
    );
  }
}
