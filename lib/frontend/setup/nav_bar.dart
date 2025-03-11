import 'dart:ui';
import 'package:flutter/material.dart';

class CENavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onIndexChanged;

  const CENavBar({Key? key, required this.selectedIndex, required this.onIndexChanged}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final navBarHeight = 36 + MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiary.withAlpha(150),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16.0), topRight: Radius.circular(16.0)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16.0), topRight: Radius.circular(16.0)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 7.5, sigmaY: 7.5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: navBarHeight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(context, Icons.home_outlined, Icons.home, 0),
                    _buildNavItem(context, Icons.calendar_today_outlined, Icons.calendar_today, 1),
                    _buildNavItem(context, Icons.stadium_outlined, Icons.stadium, 2),
                    _buildNavItem(context, Icons.sports_basketball_outlined, Icons.sports_basketball, 3),
                    _buildNavItem(context, Icons.article_outlined, Icons.article, 4),
                  ],
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, IconData outlinedIcon, IconData filledIcon, int index) {
    final isSelected = selectedIndex == index;
    final color = isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface;

    return GestureDetector(
      onTap: () {
        onIndexChanged(index);
      },
      behavior: HitTestBehavior.opaque, // Makes the entire area tappable
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0), // Increased padding
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: isSelected ? 0 : 1, end: isSelected ? 1 : 0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            double scale = 1.0 + (value * 0.2);
            // Change icon immediately based on selection state rather than animation value
            return Transform.scale(
              scale: scale,
              child: Icon(isSelected ? filledIcon : outlinedIcon, color: color, size: 24),
            );
          },
        ),
      ),
    );
  }
}
