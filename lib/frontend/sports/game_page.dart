import 'package:connect_ed_2/classes/game.dart';
import 'package:connect_ed_2/frontend/setup/app_bar.dart';
import 'package:connect_ed_2/frontend/sports/game_widgets.dart'; // Added for GameWidget
import 'package:connect_ed_2/frontend/sports/standings.dart'; // Added for StandingsTable
import 'package:connect_ed_2/classes/standings_item.dart'; // Added for StandingsItem
import 'package:flutter/material.dart';

enum GameInfoSegment { standings, upcomingGames }

class GamePage extends StatefulWidget {
  GamePage({super.key});

  final Game pageGame = Game(
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
  );

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  GameInfoSegment _selectedSegment = GameInfoSegment.upcomingGames;

  // Dummy data for upcoming games
  final List<Game> _upcomingGames = List.generate(
    5,
    (index) => Game(
      homeTeam: "Team ${String.fromCharCode(65 + index + 5)}", // Different teams for upcoming
      homeabbr: "T${String.fromCharCode(65 + index + 5)}",
      homeLogo: "assets/team_b_logo.png", // Placeholder logo
      awayTeam: "Team ${String.fromCharCode(70 + index + 5)}",
      awayabbr: "T${String.fromCharCode(70 + index + 5)}",
      awayLogo: "assets/team_a_logo.png", // Placeholder logo
      date: DateTime.now().add(Duration(days: index + 7)), // Further in future
      time: "${5 + index}:30 PM",
      homeScore: "-",
      awayScore: "-",
      sportsID: 1,
      sportsName: "Football",
      term: "Fall 2023",
      leagueCode: "NCAA",
    ),
  );

  // Dummy data for standings
  final List<StandingsItem> _standingsData = List.generate(
    5,
    (index) => StandingsItem(
      rank: index + 1,
      teamName: "Team ${String.fromCharCode(65 + index)}", // Corresponds to pageGame teams if A=Eagles, B=Tigers etc.
      teamAbbreviation: "T${String.fromCharCode(65 + index)}",
      wins: 10 - index * 2,
      losses: index + 1,
      ties: index % 2, // some ties
      matchesPlayed: 10 - index * 2 + index + 1 + (index % 2),
      points: (10 - index * 2) * 3 + (index % 2), // 3 for win, 1 for tie
    ),
  );

  Widget _buildUpcomingGamesContent() {
    return Container(
      height: 190,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        // Add padding here if you want space around the list itself
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        itemCount: _upcomingGames.length,
        itemBuilder: (context, index) {
          return Padding(
            // Padding for individual GameWidget
            padding: const EdgeInsets.only(right: 16),
            child: GameWidget(game: _upcomingGames[index]),
          );
        },
      ),
    );
  }

  Widget _buildStandingsContent() {
    // StandingsTable likely handles its own internal padding for rows/header.
    // Add padding here if the whole table needs to be inset.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0), // Add vertical padding if needed
      child: StandingsTable(
        standings: _standingsData,
        homeTeamName: widget.pageGame.homeTeam,
        opposingTeamName: widget.pageGame.awayTeam,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          CEAppBar(title: "${widget.pageGame.homeabbr} v ${widget.pageGame.awayabbr}", showBackButton: true),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(
                    'Final',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        spacing: 16,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            spacing: 8,
                            children: [
                              Container(width: 64, height: 60, color: Colors.blue),
                              Text(
                                widget.pageGame.homeabbr,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                                  fontSize: 16,
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        width: 143,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          spacing: 16,
                          children: [
                            Text(
                              '${widget.pageGame.date.month}.${widget.pageGame.date.day}.${widget.pageGame.date.year} | ${widget.pageGame.time}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                                fontSize: 12,
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Container(
                              width: double.infinity,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                spacing: 32,
                                children: [
                                  Text(
                                    widget.pageGame.homeScore,
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
                                    widget.pageGame.awayScore,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontFamily: 'Montserrat',
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              widget.pageGame.sportsName.toUpperCase(),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                                fontSize: 12,
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        spacing: 16,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            spacing: 8,
                            children: [
                              Container(width: 64, height: 60, color: Colors.blue),
                              Text(
                                widget.pageGame.awayabbr,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withAlpha(153),
                                  fontSize: 16,
                                  fontFamily: 'Montserrat',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
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
                    child: SegmentedButton<GameInfoSegment>(
                      segments: const <ButtonSegment<GameInfoSegment>>[
                        ButtonSegment<GameInfoSegment>(
                          value: GameInfoSegment.upcomingGames,
                          label: Text('Upcoming', style: TextStyle(fontWeight: FontWeight.w500)),
                        ),
                        ButtonSegment<GameInfoSegment>(
                          value: GameInfoSegment.standings,
                          label: Text('Standings', style: TextStyle(fontWeight: FontWeight.w500)),
                        ),
                      ],
                      selected: <GameInfoSegment>{_selectedSegment},
                      onSelectionChanged: (Set<GameInfoSegment> newSelection) {
                        setState(() {
                          _selectedSegment = newSelection.first;
                        });
                      },
                      style: SegmentedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.tertiary,
                        selectedForegroundColor: Theme.of(context).colorScheme.onPrimary,
                        selectedBackgroundColor: Theme.of(context).colorScheme.primary,
                        textStyle: TextStyle(fontSize: 16, fontFamily: "Montserrat", fontWeight: FontWeight.w500),
                        visualDensity: VisualDensity.standard,
                        iconSize: 0, // Hides the checkmark icon
                        side: BorderSide.none, // Removes the border
                      ).copyWith(
                        shape: MaterialStateProperty.all<OutlinedBorder>(
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Placeholder for content based on selected segment
          ),
          if (_selectedSegment == GameInfoSegment.upcomingGames)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8, bottom: 8.0),
                child: Text(
                  "Upcoming Games",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
            ),
          if (_selectedSegment == GameInfoSegment.standings)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8, bottom: 8.0),
                child: Text(
                  "Standings",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w500),
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
            child: SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 24),
          ), // Ensure space at bottom
        ],
      ),
    );
  }
}
