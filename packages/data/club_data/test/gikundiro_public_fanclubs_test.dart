import 'package:club_data/club_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses real source identity and hides unapproved member counts', () {
    final row = mapGikundiroPublicFanclub({
      'id': 'chapter-1',
      'slug': 'blue-kigali',
      'name': 'Blue Kigali',
      'province': 'Kigali City',
      'district': 'Gasabo',
      'member_count_public': '97',
      'show_member_count': false,
      'activities': 'Matchday gatherings',
    });
    expect(row['id'], 'gikundiro-chapter-1');
    expect(row['name'], 'Blue Kigali');
    expect(row['region'], 'Kigali City / Gasabo');
    expect(row['member_count_label'], 'Pending confirmation');
    expect(row['banner_image_url'], isNull);
  });
}
