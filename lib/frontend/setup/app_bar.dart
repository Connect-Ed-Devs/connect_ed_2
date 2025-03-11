import 'package:flutter/material.dart';
import 'dart:ui';

class CEAppBar extends StatelessWidget {
  final String title;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const CEAppBar({Key? key, required this.title, this.showBackButton = false, this.onBackPressed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 75,
      toolbarHeight: 35,
      pinned: true,
      elevation: 0,
      backgroundColor: Theme.of(context).colorScheme.surface,
      // Remove default title to avoid conflicts
      title: const SizedBox.shrink(),
      leading:
          showBackButton
              ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
              )
              : null,
      flexibleSpace: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Calculate progress directly from constraints
          // This gives a more reliable measurement of scroll state
          double progress = 1.0;
          double height = constraints.maxHeight;

          // Get the collapsed height (toolbar height + status bar)
          final double collapsedHeight = MediaQuery.of(context).padding.top + kToolbarHeight;

          // Calculate progress as percentage between expanded and collapsed
          if (height > collapsedHeight) {
            final double maxHeight = 75 + MediaQuery.of(context).padding.top;
            progress = (maxHeight - height) / (maxHeight - collapsedHeight);
          }

          // Ensure progress is clamped between 0.0 and 1.0
          progress = progress.clamp(0.0, 1.0);

          // Calculate opacities
          final largeTitleOpacity = (1.0 - progress).clamp(0.0, 1.0);
          final smallTitleOpacity = progress.clamp(0.0, 1.0);

          final leftPaddingExpanded = showBackButton ? 40.0 : 16.0;

          return Container(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            // Ensure background is always fully opaque
            color: Theme.of(context).colorScheme.surface,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Large title at bottom when expanded
                Positioned(
                  bottom: 16.0,
                  left: leftPaddingExpanded,
                  child: Row(
                    children: [
                      if (showBackButton && largeTitleOpacity > 0.1)
                        Opacity(
                          opacity: largeTitleOpacity,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Icon(Icons.arrow_back, size: 28),
                          ),
                        ),
                      Opacity(
                        opacity: largeTitleOpacity,
                        child: Text(title, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),

                // Small title centered in app bar when collapsed
                Positioned(
                  top: MediaQuery.of(context).padding.top + 4,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: smallTitleOpacity,
                    duration: const Duration(milliseconds: 100),
                    child: Center(
                      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
