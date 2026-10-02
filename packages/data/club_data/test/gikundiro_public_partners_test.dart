import 'package:club_data/club_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('partner needs exact approved logo media', () {
    final row = <String, dynamic>{
      'id': 'partner-1',
      'name': 'Rayon Partner',
      'category': 'Principal',
      'website_url': 'https://partner.example/',
    };
    final asset = <String, dynamic>{
      'id': 'asset-1',
      'asset_url': 'https://gikundiro.com/partner.png',
      'usage_rights': 'official-owned-channel-media',
      'usage_scopes': ['partners'],
    };
    final partner = mapGikundiroPublicPartner(row, asset);
    expect(partner?['id'], 'gikundiro-partner-1');
    expect(partner?['logo_url'], 'https://gikundiro.com/partner.png');
    expect(partner?['website_url'], 'https://partner.example/');
    expect(
      mapGikundiroPublicPartner(row, {
        ...asset,
        'usage_scopes': ['shop'],
      }),
      isNull,
    );
  });
}
