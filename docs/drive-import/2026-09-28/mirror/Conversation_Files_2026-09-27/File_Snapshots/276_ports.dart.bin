import 'models.dart';

final class NativeWireRequest {
  NativeWireRequest(this.uri,this.method,Map<String,String> headers,this.body):headers=Map.unmodifiable(headers);
  final Uri uri;
  final String method;
  final Map<String,String> headers;
  final String? body;
}
final class NativeWireResponse {
  NativeWireResponse(this.status,Map<String,String> headers,this.body):headers=Map.unmodifiable(headers);
  final int status;
  final Map<String,String> headers;
  final String body;
}
abstract interface class NativeMembershipTransport {
  /// Exactly one submission, bounded response, no redirects, TLS validation and no logs.
  Future<NativeWireResponse> send(NativeWireRequest request, Duration timeout);
}
abstract interface class NativeMembershipApi {
  Future<MembershipSession> session();
  Future<PreparedCheckout> prepare(MembershipSession actor,String requestId,String tier);
  Future<CurrentCheckout> read(MembershipSession actor,String orderId);
  Future<HistoricalMembershipReceipt> receipt(MembershipSession actor,String orderId);
}
abstract interface class NativeRecoveryStore {
  /// Must coordinate ALL isolates/processes sharing this OS-protected account scope.
  Future<T> runExclusive<T>(String scope,Future<T> Function() work);
  Future<String?> load(String scope);
  /// Durable atomic replacement; false on concurrent edit. Never use plain preferences.
  Future<bool> compareAndSet(String scope,String? expected,String value);
}
abstract interface class MembershipDialer {
  /// Open the reviewed code once in an external system application. Not a transfer.
  Future<bool> open(String ussdCode);
}
