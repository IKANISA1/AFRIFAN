import 'package:cached_network_image/cached_network_image.dart';
import 'package:core_network/core_network.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 240, height: 160, child: child)),
    ),
  );
}

void main() {
  testWidgets('does not resolve remote media without rights approval', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const AfriGovernedCachedImage(
          imageUrl: 'https://production.invalid/private-photo.jpg',
          semanticLabel: 'Supporter photo',
          provenanceId: 'profile:photo',
          rightsApproved: false,
        ),
      ),
    );

    expect(find.text('Media unavailable'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('uses bounded centralized cache only after explicit approval', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const AfriGovernedCachedImage(
          imageUrl: 'https://example.invalid/approved.jpg',
          semanticLabel: 'Approved club media',
          provenanceId: 'cms:news:approved',
          rightsApproved: true,
        ),
      ),
    );
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));
    final resized = image.image as ResizeImage;
    final provider = resized.imageProvider as CachedNetworkImageProvider;
    final pixelRatio = tester.view.devicePixelRatio;
    expect(provider.url, 'https://example.invalid/approved.jpg');
    expect(provider.cacheManager, same(AfriImageCacheManager.instance));
    expect(provider.maxWidth, (240 * pixelRatio).ceil());
    expect(provider.maxHeight, (160 * pixelRatio).ceil());
  });
}
