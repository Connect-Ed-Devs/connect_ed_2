class StandingsItem {
  final String teamName;
  final String teamAbbreviation; // Added field
  final int rank;
  final int points;
  final int matchesPlayed;
  final int wins;
  final int losses;
  final int ties;

  StandingsItem({
    required this.teamName,
    required this.teamAbbreviation, // Added to constructor
    required this.rank,
    required this.points,
    required this.matchesPlayed,
    required this.wins,
    required this.losses,
    required this.ties,
  });

  // Optional: Factory constructor for JSON deserialization if needed later
  factory StandingsItem.fromJson(Map<String, dynamic> json) {
    return StandingsItem(
      teamName: json['teamName'] as String,
      teamAbbreviation: json['teamAbbreviation'] as String, // Added to fromJson
      rank: json['rank'] as int,
      points: json['points'] as int,
      matchesPlayed: json['matchesPlayed'] as int,
      wins: json['wins'] as int,
      losses: json['losses'] as int,
      ties: json['ties'] as int,
    );
  }

  // Optional: Method for JSON serialization if needed later
  Map<String, dynamic> toJson() {
    return {
      'teamName': teamName,
      'teamAbbreviation': teamAbbreviation, // Added to toJson
      'rank': rank,
      'points': points,
      'matchesPlayed': matchesPlayed,
      'wins': wins,
      'losses': losses,
      'ties': ties,
    };
  }
}
