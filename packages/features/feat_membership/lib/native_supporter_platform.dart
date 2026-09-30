/// Explicit OS adapter wiring. Construction never submits authentication/payment.
library;

import 'package:core_auth/native_identity_flutter.dart';

import 'native_supporter_journey.dart';

export 'native_supporter_journey.dart';
export 'src/screens/native_membership_journey_screen.dart';

Future<NativeSupporterJourney> openNativeSupporterJourney({
  required NativeIdentityScope scope,
  required List<NativeMembershipPlan> plans,
  bool enabled = false,
  bool acceptedDevicePolicy = false,
}) async {
  final store = await PlatformNativeCredentialStore.open(
    channel: const FlutterNativeCredentialChannel(),
    scope: scope,
    enabled: enabled,
    acceptedDevicePolicy: acceptedDevicePolicy,
  );
  return NativeSupporterJourney(
    identityClient: NativeIdentityWireClient(
      scope: scope,
      transport: const IoNativeIdentityTransport(),
      enabled: enabled,
    ),
    credentialStore: store,
    membershipTransport: const IoMembershipTransport(),
    plans: plans,
    enabled: enabled,
  );
}
