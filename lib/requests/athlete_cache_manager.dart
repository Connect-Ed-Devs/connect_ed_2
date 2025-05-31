import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../classes/athlete_article.dart';
import 'cache_manager.dart';

/// Global instance of the AthleteArticleCacheManager
CacheManager athleteManager = AthleteArticleCacheManager();

class AthleteArticleCacheManager extends CacheManager {
  AthleteArticleCacheManager({
    super.cacheKey = 'athlete_data',
    super.smallThreshold,
    super.largeThreshold = const Duration(days: 2),
  });

  @override
  Future<Map<String, List<AthleteArticle>>> fetchData() async {
    try {
      // Modified query to avoid the index requirement issue
      final QuerySnapshot snapshot =
          await FirebaseFirestore.instance
              .collection('athlete-entries')
              .where('published', isEqualTo: true)
              // Removing the orderBy that was causing the index issue
              .get();

      final List<AthleteArticle> athleteArticles = [];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        // Parse Timestamp fields to DateTime
        final createdAt =
            (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final updatedAt =
            (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now();

        // Parse weekOf field - the field name from the image suggests it might be weekOf
        String? weekOfString = data['weekOf'] as String?;
        DateTime weekOf;

        if (weekOfString != null) {
          try {
            weekOf = DateTime.parse(weekOfString);
          } catch (e) {
            // If parsing fails, try to extract from the provided format if it's like "2025-05-20"
            final parts = weekOfString.split('-');
            if (parts.length == 3) {
              try {
                weekOf = DateTime(
                  int.parse(parts[0]), // Year
                  int.parse(parts[1]), // Month
                  int.parse(parts[2]), // Day
                );
              } catch (e) {
                weekOf = DateTime.now(); // Fallback to current date
              }
            } else {
              weekOf = DateTime.now(); // Fallback to current date
            }
          }
        } else {
          weekOf = DateTime.now(); // Fallback to current date
        }

        athleteArticles.add(
          AthleteArticle(
            name: data['title'] ?? '',
            type: data['type'] ?? 'athlete',
            content: data['content'] ?? '',
            weekOf: weekOf,
            imageUrl: data['imageUrl'] ?? '',
            createdAt: createdAt,
            updatedAt: updatedAt,
            userId: data['userId'] ?? '',
            published: data['published'] ?? false,
            id: doc.id,
          ),
        );
      }

      // Sort the articles client-side instead of in the query
      athleteArticles.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Create a map with "articles" key pointing to the list
      final Map<String, List<AthleteArticle>> articlesMap = {
        'articles': athleteArticles,
      };

      // Store the fetched data as a map
      super.storeData(articlesMap);
      return articlesMap;
    } catch (e) {
      print('Error fetching athlete articles: $e');
      throw Exception('Failed to load athlete articles: $e');
    }
  }

  @override
  String encodeData(dynamic data) {
    // Cast to the correct type: a map with string key and list of AthleteArticle value
    final Map<String, List<AthleteArticle>> articlesMap =
        data as Map<String, List<AthleteArticle>>;

    // Extract the list of articles
    final List<AthleteArticle> articles = articlesMap['articles'] ?? [];

    // Convert to a proper json structure
    final Map<String, dynamic> jsonMap = {
      'articles': articles.map((article) => article.toMap()).toList(),
    };

    return jsonEncode(jsonMap);
  }

  @override
  Map<String, List<AthleteArticle>> decodeData(String data) {
    if (data.isEmpty) return {'articles': []};

    final Map<String, dynamic> jsonMap =
        jsonDecode(data) as Map<String, dynamic>;
    final List<dynamic> articlesJson = jsonMap['articles'] as List<dynamic>;

    final List<AthleteArticle> articles =
        articlesJson
            .map((item) => AthleteArticle.fromMap(item as Map<String, dynamic>))
            .toList();

    return {'articles': articles};
  }
}
