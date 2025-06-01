import 'package:connect_ed_2/classes/menu_section.dart';
import 'package:flutter/material.dart';

class MenuDialog extends StatefulWidget {
  final List<MenuSection> menuSections;

  const MenuDialog({super.key, required this.menuSections});

  @override
  MenuDialogState createState() => MenuDialogState();
}

class MenuDialogState extends State<MenuDialog> {
  // Track expanded state for each section
  late Map<int, bool> _expandedSections;

  @override
  void initState() {
    super.initState();
    // Initialize all sections as expanded
    _expandedSections = {};
    for (int i = 0; i < widget.menuSections.length; i++) {
      _expandedSections[i] = true;
    }
  }

  // Toggle section expanded state
  void _toggleSection(int index) {
    setState(() {
      _expandedSections[index] = !(_expandedSections[index] ?? true);
    });
  }

  // Format section titles with proper capitalization
  String _formatSectionTitle(String title) {
    if (title.isEmpty) return '';

    // Split by spaces, capitalize each word, rejoin
    return title
        .split(' ')
        .map(
          (word) =>
              word.isNotEmpty
                  ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
                  : '',
        )
        .join(' ');
  }

  // Properly format food items text
  String _formatFoodItems(String text) {
    // Replace literal "\n" sequences with actual newlines
    String processed = text.replaceAll('\\n', '\n');

    // Trim extra whitespace around lines
    processed = processed.split('\n').map((line) => line.trim()).join('\n');

    return processed;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.flatware, size: 24),
          SizedBox(width: 8),
          Text("Today's Menu"),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400, // Fixed height for scrolling
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.menuSections.length,
          itemBuilder: (context, index) {
            final menuSection = widget.menuSections[index];
            if (menuSection.isEmpty) return SizedBox.shrink();

            final isExpanded = _expandedSections[index] ?? true;
            final formattedTitle = _formatSectionTitle(
              menuSection.sectionTitle,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sticky header with toggle button - removed elevation
                InkWell(
                  onTap: () => _toggleSection(index),
                  child: Container(
                    color: Theme.of(context).colorScheme.surface,
                    padding: const EdgeInsets.symmetric(
                      vertical: 8.0,
                      horizontal: 8.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formattedTitle,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                // Expandable content
                AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  height: isExpanded ? null : 0,
                  child:
                      isExpanded
                          ? Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children:
                                  menuSection.courses.map((course) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12.0,
                                        top: 8.0,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _formatSectionTitle(
                                              course[0],
                                            ), // Capitalize course name
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            _formatFoodItems(
                                              course[1],
                                            ), // Process food items text
                                            style: TextStyle(
                                              fontSize: 12,
                                            ), // 12px as requested
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                            ),
                          )
                          : SizedBox.shrink(),
                ),
                Divider(
                  height: 4,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('CLOSE'),
        ),
      ],
    );
  }
}
