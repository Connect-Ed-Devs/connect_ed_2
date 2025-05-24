import 'package:connect_ed_2/classes/team.dart';
import 'package:connect_ed_2/frontend/setup/app_bar.dart';
import 'package:connect_ed_2/frontend/setup/segmented_button.dart';
import 'package:connect_ed_2/classes/game.dart'; // Added for Game
import 'package:connect_ed_2/frontend/sports/game_widgets.dart'; // Added for GameWidget
import 'package:connect_ed_2/classes/standings_item.dart'; // Added for StandingsItem
import 'package:connect_ed_2/frontend/sports/standings.dart'; // Added for StandingsTable
import 'package:flutter/material.dart';

// Define an enum for the segments
enum TeamInfoSegment { upcoming, scores, standings, roster }

class _SegmentedButtonHeaderDelegate extends SliverPersistentHeaderDelegate {
  final CustomSegmentedButton<TeamInfoSegment> segmentedButton;
  final double height;

  _SegmentedButtonHeaderDelegate({required this.segmentedButton, required this.height});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
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
    return segmentedButton != oldDelegate.segmentedButton || height != oldDelegate.height;
  }
}

class TeamPage extends StatefulWidget {
  final Team team;

  const TeamPage({super.key, required this.team});

  @override
  State<TeamPage> createState() => _TeamPageState();
}

class _TeamPageState extends State<TeamPage> {
  TeamInfoSegment _selectedSegment = TeamInfoSegment.upcoming;

  // Dummy data for games (can be reused or varied for upcoming/scores)
  final List<Game> _mockGames = List.generate(
    8,
    (index) => Game(
      homeTeam: "Team ${String.fromCharCode(65 + index)}",
      homeabbr: "T${String.fromCharCode(65 + index)}",
      homeLogo: "assets/team_a_logo.png",
      awayTeam: "Team ${String.fromCharCode(73 + index)}", // I to P
      awayabbr: "T${String.fromCharCode(73 + index)}",
      awayLogo: "assets/team_b_logo.png",
      date: DateTime.now().add(Duration(days: index + (index % 2 == 0 ? 2 : -2))), // Mix of past and future
      time: "${5 + index}:00 PM",
      homeScore: (index % 2 == 0) ? "${20 + index}" : "-", // Scores for some
      awayScore: (index % 2 == 0) ? "${18 + index}" : "-",
      sportsID: 1, // Example sport ID
      sportsName: "Soccer", // Example sport name
      term: "Spring 2024",
      leagueCode: "League X",
    ),
  );

  // Dummy data for standings
  final List<StandingsItem> _mockStandings = List.generate(
    8,
    (index) => StandingsItem(
      rank: index + 1,
      teamName: "Team ${String.fromCharCode(65 + index)}",
      teamAbbreviation: "T${String.fromCharCode(65 + index)}",
      wins: 15 - index * 2,
      losses: index + 1,
      ties: index % 3,
      matchesPlayed: (15 - index * 2) + (index + 1) + (index % 3),
      points: (15 - index * 2) * 3 + (index % 3),
    ),
  );

  // Placeholder widgets for different segments
  Widget _buildSegmentContent(TeamInfoSegment segment) {
    switch (segment) {
      case TeamInfoSegment.upcoming:
      case TeamInfoSegment.scores:
        return SliverPadding(
          padding: const EdgeInsets.all(16.0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // Number of columns
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
              mainAxisExtent: 190.0, // Set fixed height for game items
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              return GameWidget(game: _mockGames[index]);
            }, childCount: _mockGames.length),
          ),
        );
      case TeamInfoSegment.standings:
        return SliverPadding(
          padding: const EdgeInsets.all(16.0),
          sliver: SliverToBoxAdapter(
            child: StandingsTable(
              standings: _mockStandings,
              homeTeamName: widget.team.name, // Highlight the current team
            ),
          ),
        );
      case TeamInfoSegment.roster:
        return SliverPadding(
          padding: const EdgeInsets.all(16.0),
          sliver: SliverToBoxAdapter(child: Center(child: Text('${widget.team.name} - Roster Content'))),
        );
      default:
        return SliverPadding(
          padding: const EdgeInsets.all(16.0),
          sliver: SliverToBoxAdapter(child: Center(child: Text('Select a segment'))),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String displayRecord = "#${widget.team.rank}\n${widget.team.record}";
    final theme = Theme.of(context);

    // Calculate the height of the segmented button for the delegate
    // This is an estimate; actual height might depend on text style and padding.
    // A more robust way would be to measure it or use a fixed known height.
    const double segmentedButtonHeight = kMinInteractiveDimension; // Approx 48.0

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          CEAppBar(
            title: "Team Info", // Or dynamically set based on team if needed
            showBackButton: true,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiary, // Or theme.colorScheme.tertiary
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(widget.team.name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
                        ),
                        Icon(widget.team.sportIcon, size: 36, color: theme.colorScheme.onSurfaceVariant),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Rank",
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                              ),
                            ),
                            Text(
                              "#${widget.team.rank}",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 24),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Record",
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                              ),
                            ),
                            Text(
                              widget.team.record,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurfaceVariant,
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
                  ButtonSegment(value: TeamInfoSegment.upcoming, label: Text('Upcoming')),
                  ButtonSegment(value: TeamInfoSegment.scores, label: Text('Scores')),
                  ButtonSegment(value: TeamInfoSegment.standings, label: Text('Standings')),
                  ButtonSegment(value: TeamInfoSegment.roster, label: Text('Roster')),
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
