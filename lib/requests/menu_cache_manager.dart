import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../classes/menu_section.dart';
import 'cache_manager.dart';

CacheManager menuManager = MenuCacheManager();

class MenuCacheManager extends CacheManager {
  MenuCacheManager({
    String cacheKey = 'menu_data',
    Duration smallThreshold = const Duration(hours: 12),
    Duration largeThreshold = const Duration(days: 7),
  }) : super(cacheKey: cacheKey, smallThreshold: smallThreshold, largeThreshold: largeThreshold);

  @override
  Future<Map<DateTime, List<MenuSection>>> fetchData() async {
    final snapshot = await FirebaseFirestore.instance.collection('menus').get();
    Map<DateTime, List<MenuSection>> result = {};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final dateStr = data['date'] as String?;
      if (dateStr == null) continue;
      final date = DateTime.parse(dateStr);
      final meals = data['meals'] as List<dynamic>? ?? [];
      List<MenuSection> sections = [];
      for (var meal in meals) {
        final title = meal['timeOfDay'] as String? ?? '';
        final coursesRaw = meal['courses'] as List<dynamic>? ?? [];
        List<List<String>> courses =
            coursesRaw.map<List<String>>((c) {
              return [c['courseType'] as String? ?? '', c['foodItem'] as String? ?? ''];
            }).toList();
        sections.add(MenuSection(sectionTitle: title, courses: courses));
      }
      result[date] = sections;
    }
    super.storeData(result);
    return result;
  }

  @override
  String encodeData(dynamic data) {
    final map = data as Map<DateTime, List<MenuSection>>;
    final out = <String, dynamic>{};
    map.forEach((date, sections) {
      out[date.toIso8601String()] =
          sections.map((s) => {'sectionTitle': s.sectionTitle, 'courses': s.courses}).toList();
    });
    return out.isEmpty ? '' : jsonEncode(out);
  }

  @override
  Map<DateTime, List<MenuSection>> decodeData(String data) {
    if (data.isEmpty) return {};

    final decoded = jsonDecode(data) as Map<String, dynamic>;
    Map<DateTime, List<MenuSection>> result = {};
    decoded.forEach((dateStr, listRaw) {
      final date = DateTime.parse(dateStr);
      final sections =
          (listRaw as List<dynamic>).map<MenuSection>((m) {
            return MenuSection.fromMap(m as Map<String, dynamic>);
          }).toList();
      result[date] = sections;
    });
    return result;
  }
}
