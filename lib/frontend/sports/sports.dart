import 'package:carousel_slider/carousel_slider.dart';
import 'package:connect_ed_2/classes/game.dart';
import 'package:connect_ed_2/frontend/setup/app_bar.dart';
import 'package:connect_ed_2/frontend/setup/opacity_button.dart';
import 'package:connect_ed_2/frontend/sports/game_widgets.dart';
import 'package:connect_ed_2/frontend/sports/otw.dart';
import 'package:flutter/material.dart';

class SportsPage extends StatefulWidget {
  const SportsPage({super.key});

  @override
  State<SportsPage> createState() => _SportsPageState();
}

class _SportsPageState extends State<SportsPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          CEAppBar(title: "Sports"),
          SliverToBoxAdapter(
            child: Column(
              children: [
                CarouselSlider(
                  items: [OTWWidget(), OTWWidget(), OTWWidget()],
                  options: CarouselOptions(
                    viewportFraction: 1.0,
                    enableInfiniteScroll: false,
                    height: 256,
                    autoPlay: true,
                    onPageChanged: (index, reason) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    return Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            _currentIndex == index
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.onSurface.withAlpha(127),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 32)),
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Recent", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
                  OpacityTextButton(text: "View More", onPressed: () {}),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              height: 190,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: 5,
                itemBuilder: (context, index) {
                  // Define 5 unique games
                  final List<Game> games = [
                    Game(
                      homeTeam: "Eagles",
                      homeabbr: "EAG",
                      homeLogo: "assets/team_a_logo.png",
                      awayTeam: "Tigers",
                      awayabbr: "TIG",
                      awayLogo: "assets/team_b_logo.png",
                      date: DateTime.now().add(Duration(days: 2)),
                      time: "6:30 PM",
                      homeScore: "24",
                      awayScore: "21",
                      sportsID: 1,
                      sportsName: "Football",
                      term: "Fall 2023",
                      leagueCode: "NCAA",
                    ),
                    Game(
                      homeTeam: "Warriors",
                      homeabbr: "WAR",
                      homeLogo: "assets/team_a_logo.png",
                      awayTeam: "Bulls",
                      awayabbr: "BUL",
                      awayLogo: "assets/team_b_logo.png",
                      date: DateTime.now().add(Duration(days: 5)),
                      time: "7:00 PM",
                      homeScore: "85",
                      awayScore: "79",
                      sportsID: 2,
                      sportsName: "Basketball",
                      term: "Fall 2023",
                      leagueCode: "NCAA",
                    ),
                    Game(
                      homeTeam: "Lions",
                      homeabbr: "LIO",
                      homeLogo: "assets/team_a_logo.png",
                      awayTeam: "Cobras",
                      awayabbr: "COB",
                      awayLogo: "assets/team_b_logo.png",
                      date: DateTime.now().add(Duration(days: 1)),
                      time: "5:00 PM",
                      homeScore: "2",
                      awayScore: "1",
                      sportsID: 3,
                      sportsName: "Soccer",
                      term: "Fall 2023",
                      leagueCode: "NCAA",
                    ),
                    Game(
                      homeTeam: "Sharks",
                      homeabbr: "SHK",
                      homeLogo: "assets/team_a_logo.png",
                      awayTeam: "Wolves",
                      awayabbr: "WLV",
                      awayLogo: "assets/team_b_logo.png",
                      date: DateTime.now().add(Duration(days: 3)),
                      time: "4:15 PM",
                      homeScore: "3",
                      awayScore: "0",
                      sportsID: 4,
                      sportsName: "Volleyball",
                      term: "Fall 2023",
                      leagueCode: "NCAA",
                    ),
                    Game(
                      homeTeam: "Ravens",
                      homeabbr: "RAV",
                      homeLogo: "assets/team_a_logo.png",
                      awayTeam: "Panthers",
                      awayabbr: "PAN",
                      awayLogo: "assets/team_b_logo.png",
                      date: DateTime.now().add(Duration(days: 7)),
                      time: "2:00 PM",
                      homeScore: "5",
                      awayScore: "3",
                      sportsID: 5,
                      sportsName: "Baseball",
                      term: "Fall 2023",
                      leagueCode: "NCAA",
                    ),
                  ];

                  return Padding(
                    padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                    child: GameWidget(game: games[index]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OTWWidget extends StatelessWidget {
  const OTWWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (context) => const OTWScreen()));
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16),
        height: 256,
        child: Stack(
          children: [
            // Include both image and gradient in the Hero
            Hero(
              tag: "banner",
              child: Stack(
                children: [
                  // Background container with image
                  Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(image: AssetImage("assets/wooly_test.png"), fit: BoxFit.cover),
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter + Alignment(0, 0.375),
                        end: Alignment.topCenter + Alignment(0, 1.25),
                        colors: [Colors.black.withAlpha(190), Colors.transparent],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Text content with Hero animations
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Hero(
                        tag: "athlete-name",
                        child: Material(
                          color: Colors.transparent,
                          child: Text(
                            "Dylan Woolstencroft",
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: Colors.white),
                          ),
                        ),
                      ),
                      Hero(
                        tag: "athlete-title",
                        child: Material(
                          color: Colors.transparent,
                          child: Text(
                            "Athlete of The Week",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.white, size: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
