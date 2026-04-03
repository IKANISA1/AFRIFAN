import 'biopay_handoff_resolution.dart';
import 'biopay_match_result.dart';
import 'biopay_money.dart';
import 'biopay_profile.dart';

enum BiopayReviewSource { faceScan, qrScan, nfcScan }

class BiopayPaymentReviewArgs {
  const BiopayPaymentReviewArgs.faceMatch({
    required this.matchResult,
    this.initialAmount,
  }) : source = BiopayReviewSource.faceScan,
       handoffResolution = null;

  const BiopayPaymentReviewArgs.handoff({
    required this.source,
    required this.handoffResolution,
  }) : assert(source != BiopayReviewSource.faceScan),
       matchResult = null,
       initialAmount = null;

  final BiopayReviewSource source;
  final BiopayMatchResult? matchResult;
  final BiopayHandoffResolution? handoffResolution;
  final int? initialAmount;

  BiopayProfile? get profile => matchResult?.profile;

  bool get canEditAmount => source == BiopayReviewSource.faceScan;

  int? get suggestedAmount => initialAmount ?? handoffResolution?.amount;

  int? get lockedAmount => canEditAmount ? null : handoffResolution?.amount;

  String get formattedAlias =>
      profile?.formattedAlias ?? handoffResolution?.formattedAlias ?? '000-000';

  String get routeLabel =>
      profile?.routeLabel ?? handoffResolution?.routeLabel ?? 'Payment route';

  String get maskedRecipientValue =>
      profile?.maskedRecipientValue ??
      handoffResolution?.maskedRecipientValue ??
      '•••';

  String get currencyCode =>
      handoffResolution?.currencyCode ?? profile?.country.currencyCode ?? 'USD';

  String? get currencySymbol => handoffResolution?.currencySymbol;

  double? get matchScore => matchResult?.score;

  String? get matchReceipt => matchResult?.matchReceipt;

  String get sourceTitle => switch (source) {
    BiopayReviewSource.faceScan => 'FACE MATCH CONFIRMED',
    BiopayReviewSource.qrScan => 'QR REQUEST VERIFIED',
    BiopayReviewSource.nfcScan => 'NFC REQUEST VERIFIED',
  };

  String get sourceDescription => switch (source) {
    BiopayReviewSource.faceScan =>
      'Review alias and enter amount.',
    BiopayReviewSource.qrScan =>
      'QR verified. Review alias to continue.',
    BiopayReviewSource.nfcScan =>
      'NFC verified. Review alias to continue.',
  };

  String get confirmLabel =>
      canEditAmount ? 'OPEN PAYMENT DIALER' : 'CONFIRM AND OPEN';

  String get amountInputLabel => biopayAmountInputLabel(currencyCode: currencyCode);

  String get lockedAmountLabel => lockedAmount == null
      ? 'Open amount'
      : formatBiopayAmount(
          amount: lockedAmount!,
          currencySymbol: currencySymbol,
          currencyCode: currencyCode,
        );

  String get successPrimaryRoute => '/biopay';

  String get successPrimaryLabel => 'BACK TO BIOPAY';

  String? get secondaryRoute => switch (source) {
    BiopayReviewSource.faceScan => '/biopay/scan?mode=pay',
    BiopayReviewSource.qrScan => '/biopay/qr/scan',
    BiopayReviewSource.nfcScan => '/biopay/nfc',
  };

  String get secondaryLabel => switch (source) {
    BiopayReviewSource.faceScan => 'PAY ANOTHER MEMBER',
    BiopayReviewSource.qrScan => 'SCAN ANOTHER QR',
    BiopayReviewSource.nfcScan => 'SCAN ANOTHER NFC REQUEST',
  };
}
