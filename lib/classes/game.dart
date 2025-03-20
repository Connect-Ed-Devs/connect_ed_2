class Game {
  String homeTeam;
  String homeabbr;
  String homeLogo;
  String awayTeam;
  String awayabbr;
  String awayLogo;
  DateTime date;
  String time;
  String homeScore;
  String awayScore;
  int sportsID;
  String sportsName;
  String term;
  String leagueCode;

  Game({
    required this.homeTeam,
    required this.homeabbr,
    required this.homeLogo,
    required this.awayTeam,
    required this.awayabbr,
    required this.awayLogo,
    required this.date,
    required this.time,
    required this.homeScore,
    required this.awayScore,
    required this.sportsID,
    required this.sportsName,
    required this.term,
    required this.leagueCode,
  });
}
