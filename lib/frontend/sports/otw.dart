import 'package:connect_ed_2/frontend/setup/opacity_button.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

class OTWScreen extends StatelessWidget {
  final String bannerTag;
  final String athleteNameTag;
  final String athleteTitleTag;

  const OTWScreen({super.key, required this.bannerTag, required this.athleteNameTag, required this.athleteTitleTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            automaticallyImplyLeading: false,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: const SizedBox.shrink(), // Clear default title
            flexibleSpace: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                // Calculate scroll progress
                double progress = 1.0;
                double height = constraints.maxHeight;
                final double collapsedHeight = MediaQuery.of(context).padding.top + 35;

                if (height > collapsedHeight) {
                  final double maxHeight = 256 + MediaQuery.of(context).padding.top;
                  progress = (maxHeight - height) / (maxHeight - collapsedHeight);
                }

                // Clamp progress between 0.0 and 1.0
                progress = progress.clamp(0.0, 1.0);

                // Calculate opacities for transition
                final expandedTitleOpacity = (1.0 - progress).clamp(0.0, 1.0);
                final collapsedTitleOpacity = progress.clamp(0.0, 1.0);

                return Stack(
                  children: [
                    // Blurred background image (visible when collapsed)
                    Positioned.fill(
                      child: Opacity(
                        opacity: collapsedTitleOpacity,
                        child: ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  image: AssetImage("assets/wooly_test.png"),
                                  fit: BoxFit.cover,
                                  colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Hero image with gradient overlay
                    Opacity(
                      opacity: expandedTitleOpacity,
                      child: Hero(
                        tag: bannerTag,
                        child: Stack(
                          children: [
                            // Image container
                            Container(
                              decoration: BoxDecoration(
                                image: DecorationImage(image: AssetImage("assets/wooly_test.png"), fit: BoxFit.cover),
                              ),
                            ),
                            // Gradient overlay
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter + Alignment(0, -0.75),
                                    end: Alignment.bottomCenter + Alignment(0, -1.5),
                                    colors: [Colors.black.withAlpha(190), Colors.transparent],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Expanded title (fades out when scrolling)
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: ClipRect(
                        child: Opacity(
                          opacity: expandedTitleOpacity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Back button (only visible when expanded)
                              if (expandedTitleOpacity > 0.1)
                                Opacity(
                                  opacity: expandedTitleOpacity,
                                  child: OpacityIconButton(
                                    icon: Icons.arrow_back_ios,
                                    onPressed: () => Navigator.pop(context),
                                    color: Colors.white,
                                  ),
                                ),
                              SizedBox(height: 16),
                              Hero(
                                tag: athleteNameTag,
                                child: Material(
                                  color: Colors.transparent,
                                  child: Text(
                                    "Dylan Woolstencroft",
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 36, color: Colors.white),
                                  ),
                                ),
                              ),
                              SizedBox(height: 8),
                              Hero(
                                tag: athleteTitleTag,
                                child: Material(
                                  color: Colors.transparent,
                                  child: Text(
                                    "Athlete of the Week",
                                    style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Collapsed title (appears when scrolled)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 4,
                      left: 0,
                      right: 0,
                      child: AnimatedOpacity(
                        opacity: collapsedTitleOpacity,
                        duration: const Duration(milliseconds: 100),
                        child: Flex(
                          direction: Axis.horizontal,
                          children: [
                            Flexible(
                              flex: 3,
                              fit: FlexFit.tight,
                              child: OpacityIconButton(
                                icon: Icons.arrow_back_ios,
                                onPressed: () => Navigator.pop(context),
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            Flexible(
                              flex: 10,
                              fit: FlexFit.tight,
                              child: Center(
                                child: Text(
                                  "Athlete of the Week",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
                                ),
                              ),
                            ),
                            Flexible(child: SizedBox(), flex: 3, fit: FlexFit.tight),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            expandedHeight: MediaQuery.of(context).padding.top + 256,
            toolbarHeight: 35,
          ),

          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.all(32),
              child: Text(
                ''' Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aliquam vel eros a lectus facilisis iaculis. Nam eu iaculis mi, quis auctor magna. Sed facilisis molestie ligula, vitae consequat lorem porttitor ac. Maecenas eu ipsum molestie erat sagittis pulvinar. Aliquam mattis at nisi ut tempor. Mauris libero felis, lacinia sed nulla ac, consectetur bibendum odio. Proin cursus vitae eros eu faucibus. In ac purus ut nibh aliquam hendrerit et quis purus. Etiam posuere nulla quam, et porta risus mattis tincidunt. Morbi vel condimentum ex. Aliquam consequat cursus magna feugiat placerat. Nunc eu urna massa. Curabitur eget fringilla eros. Ut id neque orci.

Maecenas iaculis augue id blandit convallis. Pellentesque rutrum volutpat aliquet. Phasellus interdum iaculis elementum. Ut interdum augue elementum, tempus lorem id, dictum sapien. Donec sagittis metus risus, sed imperdiet quam efficitur ac. Phasellus iaculis ex a ligula consequat ornare. Aliquam elementum, mi eget ornare vulputate, lacus urna elementum nulla, a fringilla enim quam in magna. Pellentesque ornare vestibulum venenatis. Pellentesque pulvinar dui non lacus placerat viverra. Cras et enim ac sapien luctus maximus ac et risus. In venenatis dictum libero sed feugiat. Praesent sit amet eros est.

Vestibulum ut tellus eget neque egestas sodales a et urna. Cras rhoncus lacus id luctus bibendum. Vivamus justo diam, facilisis sit amet erat at, tempor sagittis est. Fusce imperdiet mollis justo, a volutpat sem mollis nec. Donec id risus augue. In pretium massa quis nulla tincidunt, at interdum lectus ullamcorper. Mauris ligula elit, aliquet et ullamcorper id, porta at dolor. Cras id placerat orci, quis porttitor urna. Mauris viverra urna non turpis finibus varius. Quisque dictum neque finibus, scelerisque odio id, blandit erat. Nullam pretium sem id sodales pulvinar. Integer euismod odio a mauris interdum vestibulum.''',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
