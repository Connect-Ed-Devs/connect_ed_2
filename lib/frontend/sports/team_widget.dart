import 'package:connect_ed_2/classes/team.dart'; // Import the Team class
import 'package:connect_ed_2/frontend/sports/team_page.dart';
import 'package:flutter/material.dart';

class TeamWidget extends StatelessWidget {
  final Team team;

  const TeamWidget({super.key, required this.team});

  @override
  Widget build(BuildContext context) {
    // Combine rank and record for display
    final String displayRecord = "#${team.rank}\n${team.record}";

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => TeamPage(/* team: team */)));
      },
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: Theme.of(context).colorScheme.tertiary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(
                  team.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  displayRecord, // Use the combined displayRecord string
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6), // Adjusted alpha for consistency
                    fontSize: 12,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Spacer(),
            Icon(team.sportIcon, size: 36, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
