import 'package:feat_club/src/models/club_content_models.dart';
import 'package:feat_club/src/screens/club_public_link_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('publisher identity strips tracking and rejects unsafe links', () {
    ClubNewsItem article(String url) => ClubNewsItem.fromJson({
      'id': 'one',
      'title': 'Club update',
      'source_url': url,
    });
    expect(
      article(
        'https://publisher.example/news/story?utm_source=app&story=1#top',
      ).sourceUrl,
      'https://publisher.example/news/story?story=1',
    );
    for (final url in [
      'javascript:alert(1)',
      'https://secret@publisher.example/story',
      'https://publisher.example/',
      'https://x.com/clubprofile',
      'https://facebook.com/clubprofile',
    ]) {
      expect(article(url).sourceUrl, isNull);
    }
  });
  test('news photographs require rights and provenance together', () {
    final row = {'id': 'one', 'image_url': 'https://media.example/story.jpg'};
    expect(ClubNewsItem.fromJson(row).imageUrl, isNull);
    expect(
      ClubNewsItem.fromJson({...row, 'image_rights_approved': true}).imageUrl,
      isNull,
    );
    expect(
      ClubNewsItem.fromJson({
        ...row,
        'image_rights_approved': true,
        'image_provenance_id': 'approved-story',
      }).imageUrl,
      row['image_url'],
    );
  });
  test(
    'source links cannot traverse routes or carry an external destination',
    () {
      expect(validPublicEntityPath('/squad/player/club-player'), isTrue);
      for (final path in [
        '/news/../settings',
        '/news/%2fsettings',
        '//attacker.example/news/one',
        '/news/one?redirect=evil',
      ]) {
        expect(validPublicEntityPath(path), isFalse);
      }
      expect(validNativeEntityPath('/club/team/player-1'), isTrue);
      expect(validNativeEntityPath('/wallet/transfer'), isFalse);
    },
  );
}
