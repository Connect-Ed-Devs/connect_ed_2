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
        Navigator.push(context, MaterialPageRoute(builder: (context) => TeamPage(team: team)));
      },
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: ShapeDecoration(
          color: Theme.of(context).colorScheme.tertiary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Column(
          // Removed mainAxisSize: MainAxisSize.min to allow Column to fill available height
          // Removed non-standard 'spacing: 16' property
          mainAxisAlignment: MainAxisAlignment.start, // Can be .spaceBetween if Spacer is the only flexible part
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min, // Inner column for text can remain min
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4, // This is a valid property if this is a custom Column, or use SizedBox if standard
              children: [
                Text(team.name, style: TextStyle(fontSize: 16, fontFamily: 'Montserrat', fontWeight: FontWeight.w500)),
                Text(
                  displayRecord, // Use the combined displayRecord string
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(127), // Adjusted alpha for consistency
                    fontSize: 12,
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            // Add a SizedBox for explicit spacing if needed before the Spacer
            // SizedBox(height: 16),
            Spacer(), // This will now push the Icon to the bottom
            Icon(team.sportIcon, size: 36),
          ],
        ),
      ),
    );
  }
}
