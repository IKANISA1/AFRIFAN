import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final workspace = _findRepoRoot();

  String source(String path) =>
      File('${workspace.path}/$path').readAsStringSync();

  test('representative product media uses governed shared surfaces', () {
    const governedCachedImageFiles = <String>[
      'packages/features/feat_live/lib/src/screens/news_article_screen.dart',
      'packages/features/feat_home/lib/src/widgets/latest_intel_section.dart',
      'packages/features/feat_shop/lib/src/widgets/product_card.dart',
      'packages/features/feat_shop/lib/src/screens/product_detail_screen.dart',
      'packages/features/feat_live/lib/src/widgets/live_match_widgets.dart',
    ];
    for (final path in governedCachedImageFiles) {
      final value = source(path);
      expect(
        value,
        contains('AfriGovernedCachedImage('),
        reason: '$path must use the governed cached-image boundary.',
      );
      expect(
        value,
        isNot(contains('Image.network(')),
        reason: '$path must not bypass the governed image boundary.',
      );
      expect(
        value,
        isNot(contains('CachedNetworkImage(')),
        reason: '$path must not construct an ungoverned cache widget.',
      );
    }

    final onboarding = source(
      'packages/features/feat_onboarding/lib/src/screens/'
      'onboarding_screen.dart',
    );
    expect(onboarding, contains('AfriGovernedImage('));
    expect(onboarding, contains('AFRICLUB_ONBOARDING_MEDIA_RIGHTS_APPROVED'));
    expect(onboarding, contains('defaultValue: false'));

    final ticket = source(
      'packages/features/feat_ticketing/lib/src/screens/'
      'e_ticket_qr_screen.dart',
    );
    expect(ticket, contains('AfriQrBarcodeSurface('));

    for (final path in const <String>[
      'packages/features/feat_settings/lib/src/screens/settings_screen.dart',
      'packages/features/feat_settings/lib/src/screens/'
          'edit_profile_screen.dart',
    ]) {
      expect(source(path), contains('AfriAvatar('));
    }
  });

  test('locked Home hero gates image data before the frozen widget tree', () {
    final repository = source(
      'packages/features/feat_home/lib/src/repositories/'
      'home_content_repository.dart',
    );
    expect(repository, contains("row['image_rights_approved'] == true"));
    expect(repository, contains("row['image_provenance_id']"));
    expect(repository, contains('imageUrl: imageRightsApproved'));
  });
}

Directory _findRepoRoot() {
  var current = Directory.current.absolute;
  while (true) {
    if (Directory('${current.path}/packages').existsSync() &&
        Directory('${current.path}/apps').existsSync()) {
      return current;
    }
    final parent = current.parent;
    if (parent.path == current.path) {
      throw StateError(
        'Could not locate the AFRICLUB repository from '
        '${Directory.current.path}.',
      );
    }
    current = parent;
  }
}
