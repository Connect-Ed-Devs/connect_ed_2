import 'package:connect_ed_2/classes/standings_item.dart';
import 'package:flutter/material.dart';

class StandingsTable extends StatelessWidget {
  final List<StandingsItem> standings;
  final String? homeTeamName; // Team name to highlight as home
  final String? opposingTeamName; // Team name to highlight as opponent

  const StandingsTable({Key? key, required this.standings, this.homeTeamName, this.opposingTeamName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerStyle = TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: 14,
      color: theme.colorScheme.onSurface.withOpacity(0.7),
    );
    final cellStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w500);

    // Sort standings by rank
    final sortedStandings = List<StandingsItem>.from(standings)..sort((a, b) => a.rank.compareTo(b.rank));

    return Column(
      children: [
        Flex(
          direction: Axis.horizontal,
          children: [
            Expanded(child: Container(), flex: 1),
            Expanded(
              child: Text(
                "Team",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(127),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              flex: 5,
            ),
            Expanded(
              child: Center(
                child: Text(
                  "W",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(127),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  "L",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(127),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  "T",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(127),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  "P",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(127),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),

        for (var item in sortedStandings) ...[
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Flex(
                  direction: Axis.horizontal,
                  children: [
                    () {
                      Color rowItemColor = theme.colorScheme.onSurface; // Default color
                      if (item.teamName == homeTeamName) {
                        rowItemColor = theme.colorScheme.primary;
                      } else if (item.teamName == opposingTeamName) {
                        rowItemColor = theme.colorScheme.error;
                      }
                      final TextStyle currentRowStyle = cellStyle.copyWith(color: rowItemColor);

                      return Expanded(
                        flex: 1,
                        child: Text(
                          item.rank.toString(),
                          style: currentRowStyle.copyWith(
                            fontSize: 12,
                            // Ensure rank opacity is applied to the determined color
                            color: rowItemColor.withOpacity(0.7),
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }(),
                    Expanded(
                      child: Text(
                        item.teamName,
                        style: cellStyle.copyWith(
                          color:
                              item.teamName == homeTeamName
                                  ? theme.colorScheme.primary
                                  : item.teamName == opposingTeamName
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSurface, // Default color
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      flex: 5,
                    ),
                    _buildStatCell(
                      item.wins.toString(),
                      cellStyle.copyWith(
                        color:
                            item.teamName == homeTeamName
                                ? theme.colorScheme.primary
                                : item.teamName == opposingTeamName
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurface,
                      ),
                    ),
                    _buildStatCell(
                      item.losses.toString(),
                      cellStyle.copyWith(
                        color:
                            item.teamName == homeTeamName
                                ? theme.colorScheme.primary
                                : item.teamName == opposingTeamName
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurface,
                      ),
                    ),
                    _buildStatCell(
                      item.ties.toString(),
                      cellStyle.copyWith(
                        color:
                            item.teamName == homeTeamName
                                ? theme.colorScheme.primary
                                : item.teamName == opposingTeamName
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurface,
                      ),
                    ),
                    _buildStatCell(
                      item.points.toString(),
                      cellStyle.copyWith(
                        color:
                            item.teamName == homeTeamName
                                ? theme.colorScheme.primary
                                : item.teamName == opposingTeamName
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: Theme.of(context).colorScheme.onSurface.withAlpha(127), height: 0.5, thickness: 0.25),
            ],
          ),
        ],
        // Header Row
        // Standings Rows
      ],
    );
  }

  Widget _buildHeaderCell(String text, TextStyle style) {
    return Expanded(flex: 1, child: Text(text, style: style, textAlign: TextAlign.center));
  }

  Widget _buildStatCell(String text, TextStyle style) {
    return Expanded(flex: 1, child: Text(text, style: style, textAlign: TextAlign.center));
  }
}
