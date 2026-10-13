// The room shown beside a class block comes from the iCal summary's trailing
// parenthetical, which the school fills with its own shorthand. These tests pin
// the two behaviours that matter: a known code is expanded to the campus name,
// and an unknown one is passed through untouched rather than guessed at.
import 'package:connect_ed_2/classes/room_directory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('roomDisplayName', () {
    test('expands a known venue to its campus building', () {
      expect(roomDisplayName('Chapel S1'), 'John Bell Chapel');
      expect(roomDisplayName('Chapel Speech S1'), 'John Bell Chapel');
    });

    test('matches regardless of case or padding', () {
      // The feed writes "Lunch " with a trailing space, and pads other fields
      // with &#160;, so a lookup that respected whitespace would miss.
      expect(roomDisplayName('  chapel speech s1 '), 'John Bell Chapel');
      expect(roomDisplayName('CHAPEL S2'), 'John Bell Chapel');
    });

    test('passes an unmapped code through exactly as the feed spells it', () {
      // The A-D course codes have no published building mapping, and inventing
      // one would send a student to the wrong place.
      expect(roomDisplayName('A-1'), 'A-1');
      expect(roomDisplayName('B-2'), 'B-2');
      expect(roomDisplayName('D-2'), 'D-2');
      expect(roomDisplayName('Academic Support S1'), 'Academic Support S1');
      expect(roomDisplayName('Grade Band SS'), 'Grade Band SS');
    });

    test('returns empty when there is no room at all', () {
      expect(roomDisplayName(null), '');
      expect(roomDisplayName(''), '');
      expect(roomDisplayName('   '), '');
    });

    test('every mapped key is lower-case, so the lookup cannot miss', () {
      for (final key in knownRooms.keys) {
        expect(key, key.toLowerCase(), reason: 'key "$key" must be lower-case');
        expect(key.trim(), key, reason: 'key "$key" must not be padded');
      }
    });
  });
}
