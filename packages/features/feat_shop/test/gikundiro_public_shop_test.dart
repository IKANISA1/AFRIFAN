import 'package:feat_shop/src/gikundiro_public_shop.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only exact current-season approved media becomes an enquiry item', () {
    final row = <String, dynamic>{
      'id': 'shirt-1',
      'name': 'Rayon Sports home shirt',
      'description': 'Current home shirt',
      'price_rwf': 25000,
      'verification_status': 'current_media_verified_2026_27',
      'variant_options': {
        'sizes': ['S', 'M'],
      },
    };
    final asset = <String, dynamic>{
      'id': 'asset-1',
      'asset_url': 'https://example.org/registered-shirt.jpg',
      'storage_bucket': 'gikundiro-media',
      'storage_path': 'shirts/current.jpg',
      'usage_rights': 'official-owned-channel-media',
      'usage_scopes': ['shop'],
    };
    final item = mapGikundiroPublicProduct(row, asset, {
      'label': 'Shirts',
    }, now: DateTime.utc(2026, 9, 24));
    expect(item?['id'], 'gikundiro-shirt-1');
    expect(item?['price'], 25000);
    expect(item?['commerce_mode'], 'enquiry');
    expect(item?['image_rights_approved'], true);
    expect(
      mapGikundiroPublicProduct(
        {...row, 'verification_status': 'pending_supplier_photo_upload'},
        asset,
        null,
        now: DateTime.utc(2026, 9, 24),
      ),
      isNull,
    );
    expect(
      mapGikundiroPublicProduct(
        row,
        {...asset, 'usage_rights': 'generated-review-before-commercial-reuse'},
        null,
        now: DateTime.utc(2026, 9, 24),
      ),
      isNull,
    );
  });
}
