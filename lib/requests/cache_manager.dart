import '../main.dart'; // Import to access global prefs

/// Status of the cache data
enum CacheStatus {
  fresh, // Data is fresh (under small threshold)
  stale, // Data is stale (between small and large threshold)
  expired, // Data is expired (above large threshold)
}

abstract class CacheManager {
  /// The key used for storing data in SharedPreferences
  final String cacheKey;

  /// Small threshold duration - data is considered fresh within this time
  final Duration smallThreshold;

  /// Large threshold duration - data must be updated after this time
  final Duration largeThreshold;

  /// DateTime when the data was last recorded/updated
  DateTime? lastRecorded;

  /// Constructor
  CacheManager({
    required this.cacheKey,
    this.smallThreshold = const Duration(minutes: 5), // Default 5 minutes
    this.largeThreshold = const Duration(hours: 1), // Default 1 hour
  }) {
    // Initialize lastRecorded from SharedPreferences if available
    final timestamp = prefs.getInt('${cacheKey}_timestamp');
    if (timestamp != null) {
      lastRecorded = DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
  }

  /// Checks the status of cached data
  CacheStatus getCacheStatus() {
    if (lastRecorded == null) return CacheStatus.expired;

    final elapsed = DateTime.now().difference(lastRecorded!);

    if (elapsed < smallThreshold) return CacheStatus.fresh;
    if (elapsed < largeThreshold) return CacheStatus.stale;
    return CacheStatus.expired;
  }

  /// Returns a string representation of the cache status
  String getCacheStatusString() {
    final status = getCacheStatus();
    return status
        .toString()
        .split('.')
        .last; // Converts 'CacheStatus.fresh' to 'fresh'
  }

  Future<dynamic> fetchData();

  String encodeData(dynamic data);

  dynamic decodeData(String data);

  /// Stores data in the cache
  void storeData(Map<dynamic, dynamic> data) {
    final jsonData = encodeData(data);

    // Update lastRecorded to current time
    lastRecorded = DateTime.now();

    // Store both the data and the timestamp
    prefs.setString(cacheKey, jsonData);
    prefs.setInt('${cacheKey}_timestamp', lastRecorded!.millisecondsSinceEpoch);
  }

  /// Gets cached data if available and not expired
  dynamic getCachedData() {
    // Simulate an error for testing cached data retrieval
    // throw Exception('Simulated cache read error: Unable to access cached data');

    // Original code commented out for testing

    final jsonData = prefs.getString(cacheKey);

    if (jsonData == null) return null;

    // Only return the cached data if it's fresh or stale
    if (getCacheStatus() != CacheStatus.expired) {
      try {
        return decodeData(jsonData);
      } catch (e) {
        return null;
      }
    }

    return null;
  }

  /// Updates cache with new data from a provider function
  /// Throws any errors from the data provider function without fallback to cached data
}
