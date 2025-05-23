import 'package:connect_ed_2/classes/game.dart';
import 'package:connect_ed_2/frontend/setup/app_bar.dart';
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
              padding: const EdgeInsets.symmetric(vertical: 24.0),
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
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child:
                    _selectedSegment == GameInfoSegment.upcomingGames
                        ? Text('Upcoming Games Content Placeholder')
                        : Text('Standings Content Placeholder', style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
