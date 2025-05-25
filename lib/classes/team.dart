import 'package:flutter/material.dart'; // For IconData

class Team {
  final String name; // e.g., "D1 BOYS SOCCER"
  final int rank; // e.g., 1
  final String record; // e.g., "6-1-0" (Win-Loss-Tie)
  final IconData sportIcon; // e.g., Icons.sports_soccer
  final String leagueCode; // Add league code property

  const Team({
    required this.name,
    required this.rank,
    required this.record,
    required this.sportIcon,
    required this.leagueCode, // Optional parameter
  });
}
