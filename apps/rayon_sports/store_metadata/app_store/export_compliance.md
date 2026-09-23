# Apple export-compliance working answer

The app uses HTTPS/TLS through Supabase/Firebase and platform-protected secure
storage. No custom encryption algorithm, VPN, cryptographic currency, or
general-purpose encryption product was identified in the app behavior audited
for this package.

Working position, subject to legal/export and exact-archive review:

- App uses encryption: **Yes**, through standard operating-system/network
  security and secure storage.
- Uses non-exempt encryption: **No** is the proposed answer if the final archive
  contains only standard exempt encryption.
- French import declaration or CCATS documentation: not expected on that basis,
  but App Store Connect determines the actual follow-up questions.

Required evidence before portal entry:

- exact archive dependency and entitlement inventory;
- confirmation that no SDK or native library adds non-exempt cryptography;
- legal/export owner approval;
- approved `ITSAppUsesNonExemptEncryption` value in the final binary if the
  project chooses to declare it in `Info.plist`;
- App Store Connect encryption answer and any requested documents.

This file is not legal advice and is not an export authorization.

