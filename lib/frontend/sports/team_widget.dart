import 'package:connect_ed_2/classes/team.dart';
import 'package:connect_ed_2/frontend/sports/team_page.dart';
import 'package:flutter/material.dart';

class TeamWidget extends StatelessWidget {
  final Team team;

  const TeamWidget({Key? key, required this.team}) : super(key: key);

  // Helper method to determine the appropriate icon based on sport name
  IconData _getSportIcon(String sportName) {
    String name = sportName.toLowerCase();

    if (name.contains('football')) return Icons.sports_football;
    if (name.contains('soccer')) return Icons.sports_soccer;
    if (name.contains('basketball')) return Icons.sports_basketball;
    if (name.contains('volleyball')) return Icons.sports_volleyball;
    if (name.contains('baseball')) return Icons.sports_baseball;
    if (name.contains('hockey')) return Icons.sports_hockey;
    if (name.contains('tennis')) return Icons.sports_tennis;
    if (name.contains('golf')) return Icons.golf_course;
    if (name.contains('swimming')) return Icons.pool;
    if (name.contains('track')) return Icons.directions_run;
    if (name.contains('cricket')) return Icons.sports_cricket;
    if (name.contains('rugby')) return Icons.sports_rugby;
    if (name.contains('handball')) return Icons.sports_handball;
    if (name.contains('badminton') || name.contains('squash')) return Icons.sports_tennis;

    // Default icon for other sports
    return Icons.emoji_events;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Get appropriate icon based on sport name
    final IconData sportIcon = team.sportIcon ?? _getSportIcon(team.name);

    return GestureDetector(
      onTap: () {
        // Navigate to team page when tapped, passing both team and leagueCode if available
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => TeamPage(
                  team: team,
                  leagueCode: team.leagueCode, // Pass league code if it's available in the Team object
                ),
          ),
        );
      },
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: const Color(0xFF303030),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  "#${team.rank.toString()}",
                  style: TextStyle(
                    color: Colors.white.withAlpha(153),
                    fontSize: 12,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  team.record,
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white.withAlpha(153),
                    fontSize: 12,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Spacer(),
            Icon(sportIcon, size: 36, color: Colors.white.withAlpha(200)),
          ],
        ),
      ),
    );
  }
}
