import 'package:flutter/material.dart';
import 'dart:ui';

class CEAppBar extends StatelessWidget {
  final String title;
  final String? collapsedTitle;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final Widget? trailingAction;

  const CEAppBar({
    super.key,
    required this.title,
    this.collapsedTitle,
    this.showBackButton = false,
    this.onBackPressed,
    this.trailingAction,
  });

  @override
  Widget build(BuildContext context) {
    // Use provided collapsed title or fall back to the main title
    final String smallTitle = collapsedTitle ?? title;

    return SliverAppBar(
      expandedHeight: 75,
      toolbarHeight: 35,
      pinned: true,
      elevation: 0,
      automaticallyImplyLeading: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      title: const SizedBox.shrink(),
      // Remove the leading property completely
      flexibleSpace: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Calculate progress directly from constraints
          double progress = 1.0;
          double height = constraints.maxHeight;

          // Get the collapsed height (toolbar height + status bar)
          final double collapsedHeight =
              MediaQuery.of(context).padding.top +
              35; // Use toolbarHeight value

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

          final leftPaddingExpanded = 16.0;

          return Container(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            color: Theme.of(context).colorScheme.surface,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Large title at bottom when expanded
                Positioned(
                  bottom: 16.0,
                  left: leftPaddingExpanded,
                  width: constraints.maxWidth - leftPaddingExpanded - 16.0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (showBackButton)
                              Opacity(
                                opacity: largeTitleOpacity,
                                child: IconButton(
                                  icon: const Icon(Icons.arrow_back_ios),
                                  onPressed:
                                      onBackPressed ??
                                      () => Navigator.of(context).pop(),
                                  iconSize: 36,
                                ),
                              ),
                            Expanded(
                              child: Opacity(
                                opacity: largeTitleOpacity,
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Opacity(
                        opacity: largeTitleOpacity,
                        child: trailingAction ?? const SizedBox.shrink(),
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
                    child: Flex(
                      direction: Axis.horizontal,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          fit: FlexFit.tight,
                          child:
                              showBackButton
                                  ? IconButton(
                                    icon: const Icon(
                                      Icons.arrow_back_ios,
                                      size: 18,
                                    ),
                                    onPressed:
                                        onBackPressed ??
                                        () => Navigator.of(context).pop(),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    visualDensity: VisualDensity.compact,
                                  )
                                  : const SizedBox.shrink(),
                        ),
                        Flexible(
                          flex: 5,
                          fit: FlexFit.tight,
                          child: Text(
                            smallTitle,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Flexible(fit: FlexFit.tight, child: SizedBox.shrink()),
                      ],
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
