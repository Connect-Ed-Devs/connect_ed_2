import 'package:core_ui/core_ui.dart';
import 'package:connect_ed_2/frontend/onboarding/setup_link.dart';
import 'package:flutter/material.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // The body scrolls, so it no longer stretches to fill the window itself.
      // Without this the space the content no longer occupies would fall back
      // to the Scaffold's default rather than the surface the header sits on.
      backgroundColor: theme.colorScheme.surface,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Measured against the viewport, not against the content: the art
          // must not grow with the system text size, or it squeezes the button
          // off the bottom of the screen on a device with large text.
          final headerHeight = constraints.maxHeight * 0.42;
          final logoSize = constraints.maxHeight * 0.25;

          return SingleChildScrollView(
            child: ConstrainedBox(
              // Exactly viewport-tall while the content fits, so the button
              // still sits at the bottom of the screen; taller, and therefore
              // scrollable, once a large text size needs the room. This was a
              // fixed Column with an Expanded content area, which could not
              // scroll and so pushed Get Started out of reach - a first-run
              // dead end that looked like a broken homepage.
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                // Header at the top, content block at the bottom, with the
                // slack (when there is any) falling in between.
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Animated gradient section
                  SizedBox(
                    height: headerHeight,
                    width: double.infinity,
                    child: AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        // Calculate moving positions for gradient anchors
                        final double value = _animationController.value;

                        // Create rectangle motion pattern (moving along edges)
                        // This creates a path that follows the perimeter of the rectangle
                        double beginX, beginY, endX, endY;

                        // First point moves around perimeter
                        if (value < 0.25) {
                          // Top edge: left to right
                          beginX = -1.0 + (value * 8.0); // -1.0 to 1.0
                          beginY = -1.0;
                        } else if (value < 0.5) {
                          // Right edge: top to bottom
                          beginX = 1.0;
                          beginY = -1.0 + ((value - 0.25) * 8.0); // -1.0 to 1.0
                        } else if (value < 0.75) {
                          // Bottom edge: right to left
                          beginX = 1.0 - ((value - 0.5) * 8.0); // 1.0 to -1.0
                          beginY = 1.0;
                        } else {
                          // Left edge: bottom to top
                          beginX = -1.0;
                          beginY = 1.0 - ((value - 0.75) * 8.0); // 1.0 to -1.0
                        }

                        // Second point moves in opposite direction
                        if (value < 0.25) {
                          // Bottom edge: right to left
                          endX = 1.0 - (value * 8.0); // 1.0 to -1.0
                          endY = 1.0;
                        } else if (value < 0.5) {
                          // Left edge: bottom to top
                          endX = -1.0;
                          endY = 1.0 - ((value - 0.25) * 8.0); // -1.0 to 1.0
                        } else if (value < 0.75) {
                          // Top edge: left to right
                          endX = -1.0 + ((value - 0.5) * 8.0); // -1.0 to 1.0
                          endY = -1.0;
                        } else {
                          // Right edge: top to bottom
                          endX = 1.0;
                          endY = -1.0 + ((value - 0.75) * 8.0); // 1.0 to 1.0
                        }

                        // Select appropriate gradient colors based on theme mode
                        final List<Color> gradientColors = [
                          Color.fromARGB(255, 160, 207, 235),
                          Color.fromARGB(255, 0, 66, 112),
                        ];

                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment(beginX, beginY),
                              end: Alignment(endX, endY),
                              colors: gradientColors,
                            ),
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(16.0),
                              bottomRight: Radius.circular(16.0),
                            ),
                          ),
                          child: SizedBox(
                            width: 128,
                            height: 128,
                            child: Center(
                              child: Image(
                                image: AssetImage(
                                  'assets/ConnectEd Transparent.png',
                                ),
                                width: logoSize,
                                height: logoSize,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Content section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32.0),
                    color: theme.colorScheme.surface,
                    child: Column(
                      children: [
                        // Welcome message
                        Text(
                          'Welcome to Connect-Ed',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                            fontFamily: 'Montserrat',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        TypewriterText(
                          texts: [
                            'Sports, academics, and more, all in one place',
                            'View your schedule, assessments, and more',
                            'View events and articles',
                            'Connect with your peers and teachers',
                          ],
                          textStyle: TextStyle(
                            fontSize: 16,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                            height: 1.5,
                          ),
                        ),
                        // A fixed gap, not a Spacer: this column is inside a
                        // scroll view now, where a flex child has no bounded
                        // height to divide.
                        const SizedBox(height: 48),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OpacityBlockButton(
                            text: 'Get Started',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LinkPage(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
