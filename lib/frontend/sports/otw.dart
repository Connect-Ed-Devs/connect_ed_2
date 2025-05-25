import 'package:connect_ed_2/classes/athlete_article.dart';
import 'package:connect_ed_2/frontend/setup/opacity_button.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:intl/intl.dart';

class OTWScreen extends StatelessWidget {
  final String bannerTag;
  final String athleteNameTag;
  final String athleteTitleTag;
  final AthleteArticle article;

  const OTWScreen({
    super.key,
    required this.bannerTag,
    required this.athleteNameTag,
    required this.athleteTitleTag,
    required this.article,
  });

  @override
  Widget build(BuildContext context) {
    final String typeTitle = article.type == 'athlete' ? 'Athlete of the Week' : 'Team of the Week';
    final DateFormat formatter = DateFormat('MMMM d, yyyy');
    final String formattedDate = formatter.format(article.weekOf);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            automaticallyImplyLeading: false,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: const SizedBox.shrink(),
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
                                  image: NetworkImage(article.imageUrl),
                                  fit: BoxFit.cover,
                                  colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
                                  onError: (exception, stackTrace) => AssetImage("assets/placeholder_athlete.png"),
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
                                image: DecorationImage(
                                  image: NetworkImage(article.imageUrl),
                                  fit: BoxFit.cover,
                                  onError: (exception, stackTrace) => AssetImage("assets/placeholder_athlete.png"),
                                ),
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
                                    article.name,
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
                                    typeTitle,
                                    style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Week of $formattedDate",
                                style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8)),
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
                                  typeTitle,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (article.content.isNotEmpty)
                    Text(article.content, style: TextStyle(fontSize: 16, height: 1.6))
                  else
                    Text(
                      "No additional information available for this featured ${article.type}.",
                      style: TextStyle(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  SizedBox(height: 24),
                  Text(
                    "Added on: ${DateFormat('MMMM d, yyyy').format(article.createdAt)}",
                    style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
