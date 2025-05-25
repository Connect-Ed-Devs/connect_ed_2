import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../classes/game.dart';
import 'cache_manager.dart';

/// Global instance of the GamesCacheManager
CacheManager gamesManager = GamesCacheManager();

class GamesCacheManager extends CacheManager {
  GamesCacheManager({
    String cacheKey = 'games_data',
    Duration smallThreshold = const Duration(hours: 2),
    Duration largeThreshold = const Duration(days: 1),
  }) : super(cacheKey: cacheKey, smallThreshold: smallThreshold, largeThreshold: largeThreshold);

  @override
  Future<Map<String, Game>> fetchData() async {
    try {
      // Get all documents from Games collection without composite index
      final QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('Games').get();

      final Map<String, Game> games = {};

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final gameId = doc.id;

        // Parse Timestamp to DateTime
        DateTime dateTime;
        if (data['game_date'] is Timestamp) {
          dateTime = (data['game_date'] as Timestamp).toDate();
        } else {
          // Fallback if timestamp is not available or in unexpected format
          try {
            dateTime = DateTime.parse(data['game_date'].toString());
          } catch (e) {
            dateTime = DateTime.now(); // Default to current time if parsing fails
          }
        }

        // Clean up scores by removing any content within round brackets
        String homeScore = (data['home_score']?.toString() ?? '0').trim();
        String awayScore = (data['away_score']?.toString() ?? '0').trim();

        // Remove any content within round brackets like "3-0 (25-20, 25-18, 25-22)"
        homeScore = _removeBracketContent(homeScore);
        awayScore = _removeBracketContent(awayScore);

        games[gameId] = Game(
          homeTeam: data['home_team']?.toString() ?? '',
          homeabbr: data['home_abbr']?.toString() ?? '',
          homeLogo: data['home_logo']?.toString() ?? 'assets/team_a_logo.png',
          awayTeam: data['away_team']?.toString() ?? '',
          awayabbr: data['away_abbr']?.toString() ?? '',
          awayLogo: data['away_logo']?.toString() ?? 'assets/team_b_logo.png',
          date: dateTime,
          time: data['game_time']?.toString() ?? '',
          homeScore: homeScore,
          awayScore: awayScore,
          sportsID: int.tryParse(data['sports_id']?.toString() ?? '0') ?? 0,
          sportsName: data['sports_name']?.toString() ?? '',
          term: data['term']?.toString() ?? '',
          leagueCode: data['league_code']?.toString() ?? '',
        );
      }

      // Store the fetched data
      super.storeData(games);
      return games;
    } catch (e) {
      print('Error fetching games data: $e');
      throw Exception('Failed to load games data: $e');
    }
  }

  /// Helper method to remove content within round brackets from score strings
  String _removeBracketContent(String score) {
    // Regular expression to match content within round brackets
    final RegExp bracketRegex = RegExp(r'\s*\(.*?\)\s*');

    // Replace all matched bracket content with empty string
    return score.replaceAll(bracketRegex, '').trim();
  }

  @override
  String encodeData(dynamic data) {
    final Map<String, Game> games = data as Map<String, Game>;

    // Convert Game objects to serializable maps
    Map<String, dynamic> encodedGames = {};
    games.forEach((gameId, game) {
      encodedGames[gameId] = {
        'homeTeam': game.homeTeam,
        'homeabbr': game.homeabbr,
        'homeLogo': game.homeLogo,
        'awayTeam': game.awayTeam,
        'awayabbr': game.awayabbr,
        'awayLogo': game.awayLogo,
        'date': game.date.toIso8601String(),
        'time': game.time,
        'homeScore': game.homeScore,
        'awayScore': game.awayScore,
        'sportsID': game.sportsID,
        'sportsName': game.sportsName,
        'term': game.term,
        'leagueCode': game.leagueCode,
      };
    });

    return jsonEncode(encodedGames);
  }

  @override
  Map<String, Game> decodeData(String data) {
    if (data.isEmpty) return {};

    final Map<String, dynamic> decodedMap = jsonDecode(data) as Map<String, dynamic>;
    final Map<String, Game> games = {};

    decodedMap.forEach((gameId, gameData) {
      games[gameId] = Game(
        homeTeam: gameData['homeTeam'] as String? ?? '',
        homeabbr: gameData['homeabbr'] as String? ?? '',
        homeLogo: gameData['homeLogo'] as String? ?? '',
        awayTeam: gameData['awayTeam'] as String? ?? '',
        awayabbr: gameData['awayabbr'] as String? ?? '',
        awayLogo: gameData['awayLogo'] as String? ?? '',
        date: DateTime.parse(gameData['date'] as String? ?? DateTime.now().toIso8601String()),
        time: gameData['time'] as String? ?? '',
        homeScore: gameData['homeScore'] as String? ?? '',
        awayScore: gameData['awayScore'] as String? ?? '',
        sportsID: gameData['sportsID'] as int? ?? 0,
        sportsName: gameData['sportsName'] as String? ?? '',
        term: gameData['term'] as String? ?? '',
        leagueCode: gameData['leagueCode'] as String? ?? '',
      );
    });

    return games;
  }
}
