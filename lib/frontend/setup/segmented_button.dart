import 'package:flutter/material.dart';

class CustomSegmentedButton<T extends Object> extends StatelessWidget {
  final List<ButtonSegment<T>> segments;
  final Set<T> selected;
  final void Function(Set<T>)? onSelectionChanged;
  final ButtonStyle?
  style; // Optional: allow custom styling per instance if needed

  const CustomSegmentedButton({
    super.key,
    required this.segments,
    required this.selected,
    this.onSelectionChanged,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultStyle = SegmentedButton.styleFrom(
      backgroundColor: theme.colorScheme.tertiary,
      selectedForegroundColor: theme.colorScheme.onPrimary,
      selectedBackgroundColor: theme.colorScheme.primary,
      textStyle: const TextStyle(
        fontSize: 12,
        fontFamily: 'Montserrat',
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(vertical: 8.0), // Added padding
      tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Allow button to shrink
      visualDensity:
          VisualDensity.compact, // Use compact density for a tighter fit

      iconSize: 0, // Correctly hide the selected checkmark icon
      side: BorderSide.none, // Removes the border
    ).copyWith(
      shape: WidgetStateProperty.all<OutlinedBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
    );

    return SegmentedButton<T>(
      showSelectedIcon: false,
      segments: segments,
      selected: selected,
      onSelectionChanged: onSelectionChanged,
      style: style ?? defaultStyle, // Use provided style or default
    );
  }
}
