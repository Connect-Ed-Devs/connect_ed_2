/// Turns the short venue codes in the school's iCal export into the names
/// students actually see on signage and on the portal.
///
/// The export is the only room source there is. A census of every property on
/// all 1,172 events of a real export finds `SUMMARY`, `DTSTART`, `DTEND`,
/// `UID`, `DTSTAMP`, `STATUS`, `CLASS`, `PRIORITY`, `CATEGORIES` - and
/// **zero** `LOCATION` fields, no description on any timed event, and no
/// building name or room number anywhere in the file. The feed's access token
/// unlocks nothing else either: `/app/` redirects to a login, the API paths
/// 404, and asking the feed for `loc=1`, `detail=1` or `type=full` returns
/// byte-identical output. All the room data there is lives in the trailing
/// parenthetical of the summary, `Physics, Grade 11 - AP Physics 1 - 02 (A-1)`.
///
/// So a code with no entry below is shown exactly as the feed spells it. That
/// is deliberate: a plausible-looking guess would send someone to the wrong
/// building, which is worse than a terse but correct one.
library;

/// Full campus names for the codes that are already a named place.
///
/// Buildings per the College's own campus tour: the chapel is the John Bell
/// Chapel. The `A-1`..`D-2` course codes are deliberately absent, because
/// nothing published ties them to a building - add them here as the school's
/// own mapping becomes known, and they will render immediately.
const Map<String, String> knownRooms = {
  'chapel s1': 'John Bell Chapel',
  'chapel s2': 'John Bell Chapel',
  'chapel speech s1': 'John Bell Chapel',
  'chapel speech s2': 'John Bell Chapel',
};

/// The name to show for a room as the feed spells it.
///
/// Matching ignores case and surrounding whitespace, because the feed pads
/// some codes (`Lunch ` carries a trailing space) and pads again with `&#160;`
/// on others. Returns an empty string when there is no room at all.
String roomDisplayName(String? raw) {
  final code = raw?.trim() ?? '';
  if (code.isEmpty) return '';
  return knownRooms[code.toLowerCase()] ?? code;
}
