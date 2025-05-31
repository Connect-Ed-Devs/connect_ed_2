class MenuSection {
  /// The title of the meal section (e.g., "Breakfast", "Brunch", "Lunch", "Dinner")
  final String sectionTitle;

  /// List of courses where each course is a 2-element array:
  /// [0] = course name (String)
  /// [1] = food items (String)
  final List<List<String>> courses;

  MenuSection({required this.sectionTitle, required this.courses});

  /// Get the course name at the specified index
  String getCourseName(int index) {
    if (index >= 0 && index < courses.length) {
      return courses[index][0];
    }
    return '';
  }

  /// Get the food items for the course at the specified index
  String getFoodItems(int index) {
    if (index >= 0 && index < courses.length) {
      return courses[index][1];
    }
    return '';
  }

  /// Get the total number of courses in this section
  int get courseCount => courses.length;

  /// Check if this section has any courses
  bool get isEmpty => courses.isEmpty;

  /// Check if this section has courses
  bool get isNotEmpty => courses.isNotEmpty;

  @override
  String toString() {
    return 'MenuSection(sectionTitle: $sectionTitle, courseCount: $courseCount)';
  }

  /// Create a copy of this MenuSection with optional parameter overrides
  MenuSection copyWith({String? sectionTitle, List<List<String>>? courses}) {
    return MenuSection(
      sectionTitle: sectionTitle ?? this.sectionTitle,
      courses: courses ?? this.courses,
    );
  }

  /// Convert MenuSection to a Map for serialization
  Map<String, dynamic> toMap() {
    return {'sectionTitle': sectionTitle, 'courses': courses};
  }

  /// Create MenuSection from a Map for deserialization
  factory MenuSection.fromMap(Map<String, dynamic> map) {
    return MenuSection(
      sectionTitle: map['sectionTitle'] ?? '',
      courses: List<List<String>>.from(
        (map['courses'] ?? []).map((course) => List<String>.from(course)),
      ),
    );
  }
}
