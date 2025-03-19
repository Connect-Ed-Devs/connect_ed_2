import 'package:connect_ed_2/frontend/setup/app_bar.dart';
import 'package:connect_ed_2/frontend/sports/otw.dart';
import 'package:flutter/material.dart';

class SportsPage extends StatefulWidget {
  const SportsPage({super.key});

  @override
  State<SportsPage> createState() => _SportsPageState();
}

class _SportsPageState extends State<SportsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          CEAppBar(title: "Sports"),
          SliverToBoxAdapter(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (context) => const OTWScreen()));
              },
              child: Hero(
                tag: "banner",
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  height: 256,
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
                      // Text content
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
                                Text(
                                  "Dylan Woolstencroft",
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: Colors.white),
                                ),
                                Text(
                                  "Athlete of The Week",
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}
