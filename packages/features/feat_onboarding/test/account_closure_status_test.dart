import 'package:core_auth/core_auth.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_onboarding/src/account_closure_status_view.dart';
import 'package:feat_onboarding/src/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const id = '99963000-0000-4000-8000-000000000999';

class RecoveryRepository extends AuthRepository {
  RecoveryRepository() : super(clubId: '24');
  AccountClosureReceipt? saved = const AccountClosureReceipt(
    requestId: id,
    status: 'deletion_pending',
  );
  final refreshedReferences = <String>[];
  int reads = 0;
  @override
  Future<AccountClosureReceipt?> loadAccountClosureReceipt() async {
    reads++;
    return saved;
  }

  @override
  Future<AccountClosureReceipt> refreshAccountClosureStatus(
    AccountClosureReceipt receipt,
  ) async {
    refreshedReferences.add(receipt.requestId);
    return saved = AccountClosureReceipt(
      requestId: receipt.requestId,
      status: 'failed',
    );
  }

  @override
  Future<void> forgetAccountClosureReceipt() async => saved = null;
}

Future<void> pump(
  WidgetTester tester,
  String status, {
  bool fail = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AfriLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AfriLocalizations.supportedLocales,
      home: AccountClosureStatusView(
        receipt: AccountClosureReceipt(requestId: id, status: status),
        onRefresh: (receipt) async {
          if (fail) throw StateError('private provider detail');
          return AccountClosureReceipt(
            requestId: receipt.requestId,
            status: 'failed',
          );
        },
        onForget: () async {},
        onSignIn: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TypographyTokens.debugUseFallbackFonts = true;
  });
  tearDown(() {
    TypographyTokens.debugUseFallbackFonts = false;
  });
  testWidgets(
    'unconfirmed request never claims revoked access or completed deletion',
    (tester) async {
      await pump(tester, 'requesting');
      expect(find.textContaining('not been confirmed'), findsOneWidget);
      expect(find.textContaining('Your access has been revoked'), findsNothing);
      expect(find.textContaining(id), findsOneWidget);
    },
  );
  testWidgets(
    'pending receipt survives status refresh and shows actual failed work',
    (tester) async {
      await pump(tester, 'deletion_pending');
      expect(
        find.textContaining('Personal data removal is pending'),
        findsOneWidget,
      );
      await tester.tap(find.text('Check request status'));
      await tester.pumpAndSettle();
      expect(find.textContaining('failed and will be retried'), findsOneWidget);
      expect(find.textContaining('steps are complete'), findsNothing);
    },
  );
  testWidgets('status errors preserve reference without raw provider details', (
    tester,
  ) async {
    await pump(tester, 'deletion_pending', fail: true);
    await tester.tap(find.text('Check request status'));
    await tester.pumpAndSettle();
    expect(find.textContaining('status is unavailable'), findsOneWidget);
    expect(find.textContaining('private provider'), findsNothing);
    expect(find.textContaining(id), findsOneWidget);
  });
  testWidgets(
    'only completed authoritative receipt shows completed steps while stating retained records',
    (tester) async {
      await pump(tester, 'completed');
      expect(find.textContaining('steps are complete'), findsOneWidget);
      expect(
        find.textContaining('transaction records remain retained'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'actual onboarding reads the retained receipt, refreshes the same capability, and hides only local status',
    (tester) async {
      final repository = RecoveryRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: [
              AfriLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AfriLocalizations.supportedLocales,
            home: OnboardingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.reads, 1);
      expect(find.byType(AccountClosureStatusView), findsOneWidget);
      expect(find.textContaining(id), findsOneWidget);
      await tester.tap(find.text('Check request status'));
      await tester.pumpAndSettle();
      expect(repository.refreshedReferences, [id]);
      expect(find.textContaining('failed and will be retried'), findsOneWidget);
      await tester.tap(find.text('Hide this request'));
      await tester.pumpAndSettle();
      expect(repository.saved, isNull);
      expect(find.byType(AccountClosureStatusView), findsNothing);
      expect(find.text('Continue without sign-in'), findsOneWidget);
    },
  );
}
