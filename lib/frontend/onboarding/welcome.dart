import 'package:connect_ed_2/frontend/components/button.dart';
import 'package:connect_ed_2/frontend/components/text.dart';
import 'package:connect_ed_2/frontend/onboarding/link.dart';
import 'package:flutter/material.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _gradientAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _gradientAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
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
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final gradientHeight = screenHeight * 0.42;

    return Scaffold(
      body: Column(
        children: [
          // Animated gradient section
          SizedBox(
            height: gradientHeight,
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
                  endY = 1.0 - ((value - 0.25) * 8.0); // 1.0 to -1.0
                } else if (value < 0.75) {
                  // Top edge: left to right
                  endX = -1.0 + ((value - 0.5) * 8.0); // -1.0 to 1.0
                  endY = -1.0;
                } else {
                  // Right edge: top to bottom
                  endX = 1.0;
                  endY = -1.0 + ((value - 0.75) * 8.0); // -1.0 to 1.0
                }

                // Check if we're in light mode or dark mode
                final isDarkMode =
                    Theme.of(context).brightness == Brightness.dark;

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
                        image: AssetImage("assets/ConnectEd Transparent.png"),
                        width: screenHeight * 0.25,
                        height: screenHeight * 0.25,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 32),
          // Content section
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32.0),
              color: theme.colorScheme.surface,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Welcome message
                  Text(
                    "Welcome to Connect-Ed",
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                      fontFamily: "Montserrat",
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
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.5,
                    ),
                  ),
                  Spacer(),
                  // Continue button with opacity feedback
                  // SizedBox(
                  //   width: double.infinity,
                  //   height: 56,
                  //   child: OpacityButton(
                  //     onPressed: () {
                  //       // Navigate to link setup page
                  //       Navigator.of(context).pushReplacement(
                  //         MaterialPageRoute(
                  //           builder: (context) => const LinkPage(),
                  //         ),
                  //       );
                  //     },
                  //     child: Container(
                  //       decoration: BoxDecoration(
                  //         color: theme.colorScheme.primary,
                  //         borderRadius: BorderRadius.circular(16),
                  //       ),
                  //       child: Center(
                  //         child: Text(
                  //           "Get Started",
                  //           style: TextStyle(
                  //             fontSize: 18,
                  //             fontWeight: FontWeight.w600,
                  //             color: theme.colorScheme.onPrimary,
                  //           ),
                  //         ),
                  //       ),
                  //     ),
                  //   ),
                  // ),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: AestheticButton(
                      text: "Get Started",
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
          ),
        ],
      ),
    );
  }
}
