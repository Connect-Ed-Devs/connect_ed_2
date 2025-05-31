import 'package:http/http.dart' as http;
import 'package:icalendar_parser/icalendar_parser.dart'; // Import ICalendar parser

Future<bool> checkLink(String url) async {
  try {
    String httpsUrl = makeHTTPS(url);

    final response = await http.get(Uri.parse(httpsUrl));
    if (response.statusCode != 200) {
      return false;
    }

    // Try to parse the calendar data
    final iCalendar = ICalendar.fromLines(response.body.split('\n'));
    final jsonData = iCalendar.toJson();

    // Check if the 'data' field, which is used in calendar_requests.dart, exists and is parsable.
    // This is a basic check to see if the structure is somewhat as expected.
    if (jsonData['data'] == null) {
      // If "data" is null, it's likely not a format we can process as in calendar_requests.
      return false;
    }
    // Further checks could be added here if specific structures within "data" are critical for validation.
    // For now, successfully parsing and finding a "data" key is considered a pass.

    return true;
  } catch (e) {
    print('Error in checkLink: $e'); // Log the error for debugging
    return false;
  }
}

String makeHTTPS(String url) {
  if (url.contains('webcal')) {
    return url.replaceFirst('webcal', 'https');
  }
  return url;
}
