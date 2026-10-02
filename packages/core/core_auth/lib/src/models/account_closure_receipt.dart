/// Opaque recovery capability. Contains no user, phone, tenant or transaction data.
class AccountClosureReceipt {
  const AccountClosureReceipt({required this.requestId, required this.status});
  final String requestId;
  final String status;
  bool get isComplete => status == 'completed';
  bool get isConfirmed =>
      const {'deletion_pending', 'failed', 'completed'}.contains(status);
  Map<String, dynamic> toJson() => {'request_id': requestId, 'status': status};
}
