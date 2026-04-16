# feat_BioPay

Canonical BioPay implementation for AFRICLUB.

Guardrails:
- Keep this package as the primary BioPay implementation for the club app suite.
- Treat standalone BioPay ideas as inputs only; do not replace this package with a host app from another repository.
- Preserve the current Supabase Edge Function and App Check security boundary unless a replacement reaches full parity first.
- Preserve the current BioPay hub contract intentionally; update tests when UI changes are deliberate.
- Android host apps that enable BioPay should use `FlutterFragmentActivity` for biometric and plugin compatibility.
