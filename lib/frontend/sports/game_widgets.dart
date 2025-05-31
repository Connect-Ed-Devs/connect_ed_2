import 'package:connect_ed_2/classes/game.dart';
import 'package:connect_ed_2/frontend/sports/game_page.dart';
import 'package:flutter/material.dart';

class GameWidget extends StatelessWidget {
  const GameWidget({super.key, required this.game, this.fixedWith = true});

  final Game game;
  final bool fixedWith;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => GamePage(game: game)),
        );
      },
      child: Container(
        width: fixedWith ? 160 : null,
        height: 190,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.tertiary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(game.sportsName.toUpperCase(), style: TextStyle(fontSize: 12)),
            Spacer(),
            Row(
              children: [
                _buildTeamLogo(context, game.homeabbr),
                SizedBox(width: 4),
                Text(
                  game.homeabbr,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                ),
                Spacer(),
                Text(
                  _formatScore(game.homeScore),
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                _buildTeamLogo(context, game.awayabbr),
                SizedBox(width: 4),
                Text(
                  game.awayabbr,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                ),
                Spacer(),
                Text(
                  _formatScore(game.awayScore),
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              '${game.date.month}.${game.date.day}.${game.date.year}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(190),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to format score
  String _formatScore(String score) {
    // If the score is marked as missing or is empty, display a dash
    if (score == '-' || score.trim().isEmpty || score == 'Missing') {
      return '-';
    }
    return score;
  }

  Widget _buildTeamLogo(BuildContext context, String abbr) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Image.asset(
        'assets/$abbr Logo.png',
        width: 32,
        height: 32,
        errorBuilder: (context, error, stackTrace) {
          // Return placeholder shield icon when image fails to load
          return Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.2),
            ),
            child: Center(
              child: Icon(
                Icons.shield_outlined,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        },
      ),
    );
  }
}
