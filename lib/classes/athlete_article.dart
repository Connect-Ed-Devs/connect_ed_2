class AthleteArticle {
  /// Name of the athlete or team
  final String name;

  /// Type of article - 'athlete' for Athlete of the Week, 'team' for Team of the Week
  final String type;

  /// Content/description about the athlete or team
  final String content;

  /// First day of the week this article is for (ISO 8601 format: yyyy-MM-dd)
  final DateTime weekOf;

  /// URL to the image that should be displayed
  final String imageUrl;

  /// When the article was created
  final DateTime createdAt;

  /// When the article was last updated
  final DateTime updatedAt;

  /// User ID of the creator
  final String userId;

  /// Whether the article is published
  final bool published;

  /// Unique ID for the article
  final String? id;

  AthleteArticle({
    required this.name,
    required this.type,
    required this.content,
    required this.weekOf,
    required this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.userId,
    required this.published,
    this.id,
  });

  /// Convert AthleteArticle to a Map for serialization
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'content': content,
      'weekOf': weekOf.toIso8601String(),
      'imageUrl': imageUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'userId': userId,
      'published': published,
      'id': id,
    };
  }

  /// Create AthleteArticle from a Map for deserialization
  factory AthleteArticle.fromMap(Map<String, dynamic> map) {
    return AthleteArticle(
      name: map['name'] ?? '',
      type: map['type'] ?? 'athlete',
      content: map['content'] ?? '',
      weekOf:
          map['weekOf'] is DateTime ? map['weekOf'] : DateTime.parse(map['weekOf'] ?? DateTime.now().toIso8601String()),
      imageUrl: map['imageUrl'] ?? '',
      createdAt:
          map['createdAt'] is DateTime
              ? map['createdAt']
              : DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt:
          map['updatedAt'] is DateTime
              ? map['updatedAt']
              : DateTime.parse(map['updatedAt'] ?? DateTime.now().toIso8601String()),
      userId: map['userId'] ?? '',
      published: map['published'] ?? false,
      id: map['id'],
    );
  }

  /// Create a copy of this AthleteArticle with optional parameter overrides
  AthleteArticle copyWith({
    String? name,
    String? type,
    String? content,
    DateTime? weekOf,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
    bool? published,
    String? id,
  }) {
    return AthleteArticle(
      name: name ?? this.name,
      type: type ?? this.type,
      content: content ?? this.content,
      weekOf: weekOf ?? this.weekOf,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      published: published ?? this.published,
      id: id ?? this.id,
    );
  }
}
