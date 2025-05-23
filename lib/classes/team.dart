import 'package:flutter/material.dart'; // For IconData

class Team {
  final String name; // e.g., "D1 BOYS SOCCER"
  final int rank; // Added: e.g., 1
  final String record; // e.g., "6-1-0" (Win-Loss-Tie)
  final IconData sportIcon; // e.g., Icons.sports_soccer

  const Team({
    required this.name,
    required this.rank, // Added
    required this.record,
    required this.sportIcon,
  });
}
