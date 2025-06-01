import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../classes/standings_item.dart';
import '../classes/standings_list.dart';
import '../classes/team.dart';
import 'cache_manager.dart';

/// Global instance of the StandingsCacheManager
CacheManager standingsManager = StandingsCacheManager();

class StandingsCacheManager extends CacheManager {
  StandingsCacheManager({
    super.cacheKey = 'standings_data',
    super.smallThreshold = const Duration(minutes: 10),
    super.largeThreshold = const Duration(days: 1),
  });

  @override
  Future<Map<String, StandingsList>> fetchData() async {
    try {
      // Get all documents from Sports collection without using complex queries
      final QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('Sports').get();

      final Map<String, StandingsList> sportsStandings = {};

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final leagueCode = doc.id;

        // Get sport name
        final sportsName = data['name']?.toString() ?? '';

        // Determine the IconData based on the sport name or icon field
        IconData sportIcon = _getSportIcon(sportsName);

        // Parse standings data
        final List<dynamic> standingsData =
            (data['standings_data'] as List<dynamic>?) ?? [];
        print(standingsData);
        final List<StandingsItem> standingsItems = [];

        // Find Appleby team specifically
        StandingsItem? applebyStanding;
        Team? applebyTeam;
        int applebyRank = 0;
        String applebyRecord = '0-0-0';

        for (var i = 0; i < standingsData.length; i++) {
          final item = standingsData[i];
          if (item is Map<String, dynamic>) {
            // Extract standings fields from the map
            final String teamName = item['teamName']?.toString() ?? '';
            final String teamAbbr = item['team_abbr']?.toString() ?? '';
            final int wins = int.tryParse(item['wins']?.toString() ?? '0') ?? 0;
            final int losses =
                int.tryParse(item['losses']?.toString() ?? '0') ?? 0;
            final int ties = int.tryParse(item['ties']?.toString() ?? '0') ?? 0;
            final int points =
                int.tryParse(item['points']?.toString() ?? '0') ?? 0;
            final int rank = i + 1; // Rank based on position in list
            final String record = '$wins-$losses-$ties';

            // Create standings item
            final standingsItem = StandingsItem(
              teamName: teamName,
              teamAbbreviation: teamAbbr,
              rank: rank,
              points: points,
              matchesPlayed: wins + losses + ties,
              wins: wins,
              losses: losses,
              ties: ties,
            );

            standingsItems.add(standingsItem);

            // Check specifically for "Appleby College" team
            if (teamName.toLowerCase().contains('appleby')) {
              applebyStanding = standingsItem;
              applebyRank = rank;
              applebyRecord = record;
            }
          }
        }

        // Sort by rank
        standingsItems.sort((a, b) => a.rank.compareTo(b.rank));

        // Create Appleby team object even if not found in standings
        applebyTeam = Team(
          name: 'Appleby College',
          rank: applebyStanding?.rank ?? applebyRank,
          record:
              applebyStanding != null
                  ? '${applebyStanding.wins}-${applebyStanding.losses}-${applebyStanding.ties}'
                  : applebyRecord,
          sportIcon: sportIcon,
          leagueCode: leagueCode,
        );

        sportsStandings[leagueCode] = StandingsList(
          sportsName: sportsName,
          standings: standingsItems,
          applebyTeam: applebyTeam,
        );
      }

      // Store the fetched data
      super.storeData(sportsStandings);
      return sportsStandings;
    } catch (e) {
      print('Error fetching standings data: $e');
      throw Exception('Failed to load standings data: $e');
    }
  }

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
    if (name.contains('badminton') || name.contains('squash'))
      return Icons.sports_tennis;

    // Default icon for other sports
    return Icons.emoji_events;
  }

  @override
  String encodeData(dynamic data) {
    final Map<String, StandingsList> sportsStandings =
        data as Map<String, StandingsList>;

    // Convert StandingsList objects to serializable maps
    final Map<String, dynamic> encodedMap = {};

    sportsStandings.forEach((leagueCode, standingsList) {
      encodedMap[leagueCode] = standingsList.toMap();
    });

    return jsonEncode(encodedMap);
  }

  @override
  Map<String, StandingsList> decodeData(String data) {
    if (data.isEmpty) return {};

    final Map<String, dynamic> decodedMap =
        jsonDecode(data) as Map<String, dynamic>;
    final Map<String, StandingsList> sportsStandings = {};

    decodedMap.forEach((leagueCode, standingsData) {
      if (standingsData is Map<String, dynamic>) {
        sportsStandings[leagueCode] = StandingsList.fromMap(standingsData);
      }
    });

    return sportsStandings;
  }
}
