import 'package:flutter/material.dart';

class OTWScreen extends StatelessWidget {
  const OTWScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: "banner",
                child: Stack(
                  children: [
                    // Image container should be at the bottom of the stack
                    Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(image: AssetImage("assets/wooly_test.png"), fit: BoxFit.cover),
                      ),
                    ),
                    // Gradient container should be positioned above the image
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter + Alignment(0, -0.375),
                            end: Alignment.bottomCenter + Alignment(0, -1),
                            colors: [Colors.black.withAlpha(190), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            expandedHeight: MediaQuery.of(context).padding.top + 256,
          ),
        ],
      ),
    );
  }
}
