import 'package:connect_ed_2/classes/standings_item.dart';
import 'package:connect_ed_2/classes/team.dart';
import 'package:flutter/material.dart';

class StandingsList {
  final String sportsName;
  final List<StandingsItem> standings;
  final Team applebyTeam; // Appleby College team is required

  StandingsList({
    required this.sportsName,
    required this.standings,
    required this.applebyTeam, // No longer optional
  });

  // Create StandingsList from a Map for deserialization
  factory StandingsList.fromMap(Map<String, dynamic> map) {
    // Parse standings items
    final List<dynamic> standingsData = map['standings_data'] ?? [];
    final List<StandingsItem> standingsList = [];

    for (var item in standingsData) {
      if (item is Map<String, dynamic>) {
        standingsList.add(
          StandingsItem(
            teamName: item['teamName'] as String? ?? '',
            teamAbbreviation: item['teamAbbr'] as String? ?? '',
            rank: item['rank'] as int? ?? 0,
            points: item['points'] as int? ?? 0,
            matchesPlayed: item['gamesPlayed'] as int? ?? 0,
            wins: item['wins'] as int? ?? 0,
            losses: item['losses'] as int? ?? 0,
            ties: item['ties'] as int? ?? 0,
          ),
        );
      }
    }

    // Parse appleby team data - now it's always present
    final teamData = map['appleby_team'] as Map<String, dynamic>;
    final applebyTeam = Team(
      name: teamData['name'] as String? ?? 'Appleby College',
      rank: teamData['rank'] as int? ?? 0,
      record: teamData['record'] as String? ?? '0-0-0',
      sportIcon:
          teamData['sportIconCodePoint'] != null
              ? IconData(teamData['sportIconCodePoint'] as int, fontFamily: 'MaterialIcons')
              : Icons.sports,
      leagueCode: teamData['leagueCode'] as String? ?? '',
    );

    return StandingsList(
      sportsName: map['sports_name'] as String? ?? '',
      standings: standingsList,
      applebyTeam: applebyTeam,
    );
  }

  // Convert StandingsList to a Map for serialization
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> result = {
      'sports_name': sportsName,
      'standings_data':
          standings
              .map(
                (item) => {
                  'teamName': item.teamName,
                  'teamAbbr': item.teamAbbreviation,
                  'rank': item.rank,
                  'points': item.points,
                  'gamesPlayed': item.matchesPlayed,
                  'wins': item.wins,
                  'losses': item.losses,
                  'ties': item.ties,
                },
              )
              .toList(),
      // Always include Appleby team data
      'appleby_team': {
        'name': applebyTeam.name,
        'rank': applebyTeam.rank,
        'record': applebyTeam.record,
        'sportIconCodePoint': applebyTeam.sportIcon.codePoint,
      },
    };

    return result;
  }
}
