import 'biopay_handoff_resolution.dart';
import 'biopay_match_result.dart';
import 'biopay_money.dart';
import 'biopay_profile.dart';

enum BioPayReviewSource { faceScan, qrScan, nfcScan }

class BioPayPaymentReviewArgs {
  const BioPayPaymentReviewArgs.faceMatch({
    required this.matchResult,
    this.initialAmount,
  }) : source = BioPayReviewSource.faceScan,
       handoffResolution = null;

  const BioPayPaymentReviewArgs.handoff({
    required this.source,
    required this.handoffResolution,
  }) : assert(source != BioPayReviewSource.faceScan),
       matchResult = null,
       initialAmount = null;

  final BioPayReviewSource source;
  final BioPayMatchResult? matchResult;
  final BioPayHandoffResolution? handoffResolution;
  final int? initialAmount;

  BioPayProfile? get profile => matchResult?.profile;

  bool get canEditAmount => source == BioPayReviewSource.faceScan;

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
    BioPayReviewSource.faceScan => 'Face Match Confirmed',
    BioPayReviewSource.qrScan => 'QR Request Verified',
    BioPayReviewSource.nfcScan => 'NFC Request Verified',
  };

  String get sourceDescription => switch (source) {
    BioPayReviewSource.faceScan => 'Review alias and enter amount.',
    BioPayReviewSource.qrScan => 'QR verified. Review alias to continue.',
    BioPayReviewSource.nfcScan => 'NFC verified. Review alias to continue.',
  };

  String get confirmLabel =>
      canEditAmount ? 'Open Payment Dialer' : 'Confirm and Open';

  String get amountInputLabel =>
      BioPayAmountInputLabel(currencyCode: currencyCode);

  String get lockedAmountLabel => lockedAmount == null
      ? 'Open amount'
      : formatBioPayAmount(
          amount: lockedAmount!,
          currencySymbol: currencySymbol,
          currencyCode: currencyCode,
        );

  String get successPrimaryRoute => '/BioPay';

  String get successPrimaryLabel => 'Back to BioPay';

  String? get secondaryRoute => switch (source) {
    BioPayReviewSource.faceScan => '/BioPay/scan?mode=pay',
    BioPayReviewSource.qrScan => '/BioPay/qr/scan',
    BioPayReviewSource.nfcScan => '/BioPay/nfc',
  };

  String get secondaryLabel => switch (source) {
    BioPayReviewSource.faceScan => 'Pay Another Member',
    BioPayReviewSource.qrScan => 'Scan Another QR',
    BioPayReviewSource.nfcScan => 'Scan Another NFC Request',
  };
}
