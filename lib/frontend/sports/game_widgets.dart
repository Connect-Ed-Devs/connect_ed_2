import 'package:connect_ed_2/classes/game.dart';
import 'package:flutter/material.dart';

class GameWidget extends StatelessWidget {
  const GameWidget({super.key, required this.game, this.fixedWith = true});

  final Game game;
  final bool fixedWith;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: fixedWith ? 160 : null,
      height: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.tertiary, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(game.sportsName.toUpperCase(), style: TextStyle(fontSize: 12)),
          SizedBox(height: 16),
          Row(
            children: [
              Container(width: 32, height: 32, color: Colors.white),
              SizedBox(width: 4),
              Text(game.homeabbr, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400)),
              Spacer(),
              Text(game.homeScore, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Container(width: 32, height: 32, color: Colors.white),
              SizedBox(width: 4),
              Text(game.awayabbr, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400)),
              Spacer(),
              Text(game.awayScore, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
            ],
          ),
          Spacer(),
          Text(
            '${game.date.month}.${game.date.day}.${game.date.year}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(190),
            ),
          ),
        ],
      ),
    );
  }
}
