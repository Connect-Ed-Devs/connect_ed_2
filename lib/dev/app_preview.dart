// Dev-only preview harness for the whole app.
//
// The shipped app boots into Firebase and live school feeds, and onboarding
// blocks the tabs until a calendar link is saved. That makes it awkward to
// review a single screen. This entrypoint seeds the very same SharedPreferences
// caches a successful fetch would produce (via each manager's real
// encode/store path), marks onboarding complete, and then runs the *actual*
// app root -- same theme, same shell, same nav bar -- so every tab can be
// exercised without a Firebase project or a real calendar link.
//
//   flutter run -d web-server --web-hostname=127.0.0.1 --web-port=8099 \
//       -t lib/dev/app_preview.dart
//
// Not part of the app bundle: nothing imports it, and it is only ever run by
// pointing `-t` at it.
import 'package:connect_ed_2/classes/assessment.dart';
import 'package:connect_ed_2/classes/athlete_article.dart';
import 'package:connect_ed_2/classes/calendar_item.dart';
import 'package:connect_ed_2/classes/game.dart';
import 'package:connect_ed_2/classes/menu_section.dart';
import 'package:connect_ed_2/classes/schedule_item.dart';
import 'package:connect_ed_2/classes/standings_item.dart';
import 'package:connect_ed_2/classes/standings_list.dart';
import 'package:connect_ed_2/classes/team.dart';
import 'package:connect_ed_2/main.dart';
import 'package:connect_ed_2/requests/athlete_cache_manager.dart';
import 'package:connect_ed_2/requests/calendar_requests.dart';
import 'package:connect_ed_2/requests/games_cache_manager.dart';
import 'package:connect_ed_2/requests/menu_cache_manager.dart';
import 'package:connect_ed_2/requests/standings_cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  prefs = await SharedPreferences.getInstance();

  // Skip the onboarding flow so the shell opens straight onto its tabs.
  prefs.setString('setup', 'complete');

  // Seeded calendar data is only a stand-in for a real feed. Once a link is
  // configured (Settings saves one), leave the calendar cache alone so the app
  // fetches and parses the genuine feed instead of demo data.
  final bool hasRealLink = (prefs.getString('link') ?? '').isNotEmpty;
  if (!hasRealLink) {
    _seedCalendar();
  }
  _seedMenu();
  _seedSports();

  // The real root: ThemeData(darkScheme, Montserrat) + MyHomePage with the
  // real CENavBar. Nothing here is a stand-in for app UI.
  runApp(const MyApp());
}

// -----------------------------------------------------------------------------
// Calendar: schedules + assessments (Calendar, Home and Assignments tabs)
// -----------------------------------------------------------------------------

void _seedCalendar() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  DateTime day(int offset) => today.add(Duration(days: offset));

  ScheduleItem lesson(
    String title,
    int startHour,
    int startMinute,
    int endHour,
    int endMinute,
    String room,
    String teacher,
  ) => ScheduleItem(
    title: title,
    startTime: TimeOfDay(hour: startHour, minute: startMinute),
    endTime: TimeOfDay(hour: endHour, minute: endMinute),
    location: room,
    instructor: teacher,
  );

  CalendarItem withAssessments(List<Assessment> assessments) =>
      CalendarItem(schedule: const [], assessments: assessments);

  CalendarItem scheduleAndAssessments(
    List<ScheduleItem> schedule,
    List<Assessment> assessments,
  ) => CalendarItem(schedule: schedule, assessments: assessments);

  calendarManager.storeData(<DateTime, CalendarItem>{
    day(0): scheduleAndAssessments(
      [
        lesson('AP Calculus', 9, 0, 10, 15, 'Room 204', 'Ms. Chen'),
        lesson('English', 10, 25, 11, 40, 'Room 112', 'Mr. Doyle'),
        lesson('Biology', 12, 40, 13, 55, 'Lab 3', 'Dr. Amoah'),
        lesson('History', 14, 5, 15, 20, 'Room 301', 'Ms. Balogun'),
      ],
      [
        Assessment(
          title: 'Trig identities quiz',
          className: 'AP Calculus',
          date: day(0),
        ),
        Assessment(title: 'Read Act III', className: 'English', date: day(0)),
      ],
    ),
    day(1): scheduleAndAssessments(
      [
        lesson('Physics', 9, 0, 10, 15, 'Lab 1', 'Mr. Nyame'),
        lesson('French', 11, 0, 12, 15, 'Room 208', 'Mme. Rousseau'),
      ],
      [
        Assessment(
          title: 'Cell respiration lab report',
          className: 'Biology',
          date: day(1),
        ),
      ],
    ),
    day(-2): withAssessments([
      Assessment(
        title: 'Binary search worksheet',
        className: 'AP Computer Science',
        date: day(-2),
      ),
    ]),
    day(4): withAssessments([
      Assessment(
        title: 'Cold War essay outline',
        className: 'History',
        date: day(4),
      ),
      Assessment(title: 'Verb drills', className: '', date: day(4)),
    ]),
    day(18): withAssessments([
      Assessment(
        title: 'Cumulative problem set',
        className: 'Physics',
        date: day(18),
      ),
    ]),
  });
}

// -----------------------------------------------------------------------------
// Menu (Calendar tab)
// -----------------------------------------------------------------------------

void _seedMenu() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  menuManager.storeData(<DateTime, List<MenuSection>>{
    today: [
      MenuSection(
        sectionTitle: 'Lunch',
        courses: [
          [
            'Main',
            'Grilled chicken bowl\nVegetarian option: falafel wrap\nGluten-free buns available',
          ],
          ['Sides', 'Caesar salad\nRoasted sweet potato\nFresh fruit'],
          ['Dessert', 'Chocolate chip cookies'],
        ],
      ),
      MenuSection(
        sectionTitle: 'Dinner',
        courses: [
          ['Main', 'Pasta bar\nMarinara or alfredo'],
          ['Sides', 'Garlic bread\nSteamed broccoli'],
        ],
      ),
    ],
  });
}

// -----------------------------------------------------------------------------
// Sports: games, standings and featured articles (Sports + Home tabs)
// -----------------------------------------------------------------------------

void _seedSports() {
  final now = DateTime.now();

  Game game({
    required String id,
    required String awayTeam,
    required String awayAbbr,
    required DateTime date,
    required String homeScore,
    required String awayScore,
    required String sportsName,
    required String leagueCode,
  }) => Game(
    homeTeam: 'Appleby College',
    homeabbr: 'AC',
    homeLogo: 'assets/AC Logo.png',
    awayTeam: awayTeam,
    awayabbr: awayAbbr,
    awayLogo: 'assets/$awayAbbr Logo.png',
    date: date,
    time: '4:00 PM',
    homeScore: homeScore,
    awayScore: awayScore,
    sportsID: 1,
    sportsName: sportsName,
    term: 'Fall',
    leagueCode: leagueCode,
  );

  gamesManager.storeData(<String, Game>{
    'soccer-1': game(
      id: 'soccer-1',
      awayTeam: 'Upper Canada College',
      awayAbbr: 'UCC',
      date: now.subtract(const Duration(days: 3)),
      homeScore: '3',
      awayScore: '1',
      sportsName: 'Varsity Soccer',
      leagueCode: 'D1_SOCCER',
    ),
    'hockey-1': game(
      id: 'hockey-1',
      awayTeam: 'St. Andrews College',
      awayAbbr: 'SAC',
      date: now.subtract(const Duration(days: 8)),
      homeScore: '2',
      awayScore: '2',
      sportsName: 'Varsity Hockey',
      leagueCode: 'D1_HOCKEY',
    ),
    'soccer-2': game(
      id: 'soccer-2',
      awayTeam: 'Royal St. Georges College',
      awayAbbr: 'RSGC',
      date: now.add(const Duration(days: 2)),
      homeScore: '-',
      awayScore: '-',
      sportsName: 'Varsity Soccer',
      leagueCode: 'D1_SOCCER',
    ),
    'basketball-1': game(
      id: 'basketball-1',
      awayTeam: 'Trinity College School',
      awayAbbr: 'TCS',
      date: now.add(const Duration(days: 5)),
      homeScore: '-',
      awayScore: '-',
      sportsName: 'Varsity Basketball',
      leagueCode: 'D1_BASKETBALL',
    ),
  });

  StandingsList standings({
    required String sportsName,
    required List<StandingsItem> table,
    required int applebyRank,
    required String applebyRecord,
    required IconData icon,
  }) => StandingsList(
    sportsName: sportsName,
    standings: table,
    applebyTeam: Team(
      name: 'Appleby College',
      rank: applebyRank,
      record: applebyRecord,
      sportIcon: icon,
      leagueCode: '',
    ),
  );

  StandingsItem row(
    String name,
    String abbr,
    int rank,
    int points,
    int wins,
    int losses,
    int ties,
  ) => StandingsItem(
    teamName: name,
    teamAbbreviation: abbr,
    rank: rank,
    points: points,
    matchesPlayed: wins + losses + ties,
    wins: wins,
    losses: losses,
    ties: ties,
  );

  standingsManager.storeData(<String, StandingsList>{
    'D1_SOCCER': standings(
      sportsName: 'D1 Boys Soccer',
      table: [
        row('Upper Canada College', 'UCC', 1, 18, 6, 1, 0),
        row('Appleby College', 'AC', 2, 15, 5, 2, 0),
        row('St. Andrews College', 'SAC', 3, 11, 3, 3, 2),
        row('Trinity College School', 'TCS', 4, 7, 2, 5, 1),
      ],
      applebyRank: 2,
      applebyRecord: '5-2-0',
      icon: Icons.sports_soccer,
    ),
    'D1_HOCKEY': standings(
      sportsName: 'D1 Boys Hockey',
      table: [
        row('Appleby College', 'AC', 1, 20, 6, 0, 2),
        row('Royal St. Georges College', 'RSGC', 2, 14, 4, 3, 2),
        row('St. Andrews College', 'SAC', 3, 9, 3, 4, 1),
      ],
      applebyRank: 1,
      applebyRecord: '6-0-2',
      icon: Icons.sports_hockey,
    ),
  });

  AthleteArticle article({
    required String id,
    required String name,
    required String type,
    required String imageUrl,
  }) => AthleteArticle(
    name: name,
    type: type,
    content:
        'Recognised this week for standout effort in training and in games.',
    // Midnight of the Monday of the current week.
    weekOf: DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1)),
    imageUrl: imageUrl,
    createdAt: now,
    updatedAt: now,
    userId: 'preview',
    published: true,
    id: id,
  );

  athleteManager.storeData(<String, List<AthleteArticle>>{
    'articles': [
      article(
        id: 'otw-1',
        name: 'Maya Adeyemi',
        type: 'athlete',
        imageUrl: 'https://picsum.photos/seed/connect-ed-athlete/800/400',
      ),
      article(
        id: 'otw-2',
        name: 'Varsity Soccer',
        type: 'team',
        imageUrl: 'https://picsum.photos/seed/connect-ed-team/800/400',
      ),
    ],
  });
}
