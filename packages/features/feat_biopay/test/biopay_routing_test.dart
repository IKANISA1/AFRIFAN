import 'package:core_auth/core_auth.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_biopay/feat_biopay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('BioPay hub routing', () {
    testWidgets(
      'unenrolled user is redirected to profile when tapping face scan',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/biopay',
          routes: [
            GoRoute(
              path: '/biopay',
              builder: (context, state) => const BioPayScreen(),
            ),
            GoRoute(
              path: '/biopay/profile',
              builder: (context, state) =>
                  const Scaffold(body: Text('Profile Route')),
            ),
          ],
        );

        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              biopayProfileProvider.overrideWith((ref) => null),
              biopayEnabledProvider.overrideWith((ref) => true),
              currentUserProvider.overrideWith(
                (ref) => const UserProfile(
                  id: 'user-1',
                  clubId: 'rayon_sports_rw',
                  publicUserId: '483912',
                  phone: '0788123456',
                  momoNumber: '0788123456',
                  momoProvider: 'MoMo',
                ),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Face Scan'), findsOneWidget);
        await tester.tap(find.text('Face Scan'));
        await tester.pumpAndSettle();

        expect(find.text('Profile Route'), findsOneWidget);
      },
    );

    testWidgets('enrolled user taps top profile icon to reach profile screen', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/biopay',
        routes: [
          GoRoute(
            path: '/biopay',
            builder: (context, state) => const BioPayScreen(),
          ),
          GoRoute(
            path: '/biopay/profile',
            builder: (context, state) =>
                const Scaffold(body: Text('Profile Route')),
          ),
        ],
      );

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            biopayProfileProvider.overrideWith(
              (ref) => const BiopayProfile(
                publicId: '483912',
                id: 'id1',
                userId: 'user1',
                displayName: 'John',
                routeType: PaymentRecipientType.phoneNumber,
                recipientValue: '0788123456',
                countryCode: 'RW',
                active: true,
                consentVersion: 'v1',
              ),
            ),
            biopayEnabledProvider.overrideWith((ref) => true),
            currentUserProvider.overrideWith(
              (ref) => const UserProfile(
                id: 'user-1',
                clubId: 'rayon_sports_rw',
                publicUserId: '483912',
                phone: '0788123456',
                momoNumber: '0788123456',
                momoProvider: 'MoMo',
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.person_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Profile Route'), findsOneWidget);
    });

    testWidgets('users without a linked MOMO route are sent to profile on face scan tap', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/biopay',
        routes: [
          GoRoute(
            path: '/biopay',
            builder: (context, state) => const BioPayScreen(),
          ),
          GoRoute(
            path: '/biopay/profile',
            builder: (context, state) =>
                const Scaffold(body: Text('Profile Route')),
          ),
        ],
      );

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            biopayProfileProvider.overrideWith(
              (ref) => const BiopayProfile(
                publicId: '483912',
                id: 'id1',
                userId: 'user1',
                displayName: 'John',
                routeType: PaymentRecipientType.phoneNumber,
                recipientValue: '0788123456',
                countryCode: 'RW',
                active: true,
                consentVersion: 'v1',
              ),
            ), // even if enrolled
            biopayEnabledProvider.overrideWith((ref) => true),
            currentUserProvider.overrideWith(
              (ref) => const UserProfile(
                id: 'user-1',
                clubId: 'rayon_sports_rw',
                publicUserId: '483912',
              ),
            ), // no momo details
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Face Scan'), findsOneWidget);
      await tester.tap(find.text('Face Scan'));
      await tester.pumpAndSettle();

      // Because momo is missing, it interrupts to the profile hub
      expect(find.text('Profile Route'), findsOneWidget);
    });
  });
}
