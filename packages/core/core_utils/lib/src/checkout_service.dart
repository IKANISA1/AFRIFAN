import 'package:core_network/core_network.dart';

/// Result of a checkout flow — wraps the domain value and metadata
/// needed for operational health tracking.
class CheckoutResult<T> {
  const CheckoutResult({
    required this.value,
    required this.subjectType,
    this.subjectId,
    this.successMetadata = const <String, Object?>{},
  });

  /// The domain-level value produced by the checkout (ticket, order ID, etc.).
  final T value;

  /// Table / subject type for operational health records.
  final String subjectType;

  /// Optional subject record ID for health tracking.
  final String? subjectId;

  /// Additional metadata logged on success.
  final Map<String, Object?> successMetadata;
}

/// Generic checkout orchestrator.
///
/// Flow:
///   1. Generate a payment reference
///   2. Run the [prepare] callback to create domain records
///   3. Launch payment via the provided [launchPayment] callback
///   4. Log operational health (success or failure)
///
/// White-label: not MoMo-specific. The [launchPayment] callback
/// is injected by the consuming feature module.
class CheckoutService {
  CheckoutService({
    required OperationalHealthService healthService,
    required Future<void> Function({
      required String recipientCode,
      required int amount,
      required String reference,
    })
    launchPayment,
    required Future<String> Function({bool forceRefresh}) getRecipientCode,
  }) : _healthService = healthService,
       _launchPayment = launchPayment,
       _getRecipientCode = getRecipientCode;

  final OperationalHealthService _healthService;
  final Future<void> Function({
    required String recipientCode,
    required int amount,
    required String reference,
  })
  _launchPayment;
  final Future<String> Function({bool forceRefresh}) _getRecipientCode;

  /// Run a checkout flow.
  Future<T> openCheckout<T>({
    required String service,
    required String component,
    required String userId,
    required String referencePrefix,
    required int amount,
    required String successMessage,
    required String failureMessage,
    Map<String, Object?> failureMetadata = const <String, Object?>{},
    required Future<CheckoutResult<T>> Function(String paymentReference)
    prepare,
  }) async {
    final recipientCode = await _getRecipientCode(forceRefresh: false);
    final paymentReference =
        '$referencePrefix-${DateTime.now().millisecondsSinceEpoch}';

    try {
      // Create domain records first (tickets, orders, contributions)
      final result = await prepare(paymentReference);

      // Fire the payment handoff
      await _launchPayment(
        recipientCode: recipientCode,
        amount: amount,
        reference: paymentReference,
      );

      // Log success
      await _healthService.recordEvent(
        service: service,
        component: component,
        message: successMessage,
        status: OperationalHealthStatus.ok,
        userId: userId,
        subjectType: result.subjectType,
        subjectId: result.subjectId,
        metadata: result.successMetadata,
      );

      return result.value;
    } catch (error, _) {
      // Log failure
      await _healthService.recordEvent(
        service: service,
        component: component,
        message: failureMessage,
        status: OperationalHealthStatus.error,
        userId: userId,
        subjectType: 'checkout_failure',
        metadata: <String, Object?>{...failureMetadata, 'error': '$error'},
      );
      rethrow;
    }
  }
}
