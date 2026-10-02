# Trusted receiver-settlement ingress

The supporter application has no SMS collection or authoritative parser capability.
`/sms-ingest` accepts a separately provisioned management gateway;
`/parse-momo-sms` accepts a separate server processor capability and an admitted
event receipt. Supporter bearer tokens and declared carrier sender names grant
neither capability. Authenticated direct raw-evidence insertion, rewriting and
deletion are revoked. Existing financial/operational history remains available to
its governed service and review boundaries.

## Protocol and server authority

The implemented protocol is `africlub.receiver-settlement.v1`. This is an AFRICLUB
management projection contract, not an asserted carrier SMS grammar or a direct
MTN callback implementation. A reviewed gateway must derive its fields from the
actual receiver/provider settlement record, never a supporter-provided SMS or
payer declaration. It supplies one immutable event UUID, provider transaction ID,
receiver settlement-record identity/digest, explicit settled status/time, amount,
currency, provider, receiver, country, exact server-created checkout reference,
and the actual payer's provider/country-specific digest. No user, club, target IDs,
AI override or extra fields are accepted.

The backend resolves gateway/key/receiver/club/provider/country/currency from
owner-controlled provisioning records, checks the current receiver and route,
and resolves the user/business target from the exact server checkout or intent.
A signed payer digest must match that user's verified Auth phone. Missing,
unverified, foreign or ambiguous payer/target bindings fail before a raw evidence
row is stored. The payer digest is immediately removed from the persisted
projection; the full signed body digest retains original-message equality.
Provisioning references must identify the source review and provider acceptance;
references are required metadata, not themselves evidence that the reviews occurred.

The supplied server-side `gateway_client.ts` signs and delivers the actual
projection. It emits fixed JSON member order so recovery after a restart preserves
the content digest. Persist the original event and settlement record in the
management gateway's governed delivery queue before its first HTTP call. Reuse
those same identities after an unknown/lost response; a fresh nonce can
reauthenticate the unchanged original body.

The fixed application profile signs method, the configured Supabase target URI,
content type, content digest and `x-africlub-gateway-protocol` with HMAC-SHA256.
Only the exact payment and refund protocol versions below are supported. The
signed discriminator chooses the current approval registry before body parsing;
the verified body must declare the same protocol. It checks created/expires,
clock skew and a UUID nonce, and rejects extra/multiple signature profiles, browser
Origin and compressed bodies. This uses the signature-base/MAC mechanisms and
freshness parameters in [RFC 9421](https://www.rfc-editor.org/rfc/rfc9421.html).
`Content-Digest` covers exact body bytes using the SHA256 structured byte-sequence
field in [RFC 9530](https://datatracker.ietf.org/doc/html/rfc9530). The receiver
supports this narrow profile, not every optional feature in those standards.
Requests are bounded to 8 KiB and five seconds while reading. The separate
processor accepts a 1 KiB event-only request. SDK responses/deadlines and atomic
per-gateway/per-club admission bound backend work; processing SQL has an eight
second timeout. No AI provider is called by these released payment endpoints.

## Canonical effects and recovery

A successful HTTP202 means that the immutable source receipt was admitted;
it never means the order is paid. Processing is deterministic and invokes the
existing fenced claim/persist/finish functions and the existing exact-target
`allocate_momo_payment_intent` or `confirm_club_commerce_payment` writer in one
transaction. It does not create a second ledger writer or amount-based matching
rule. Membership, frozen Shop receipts and ticket bundles retain their existing
commercial restrictions; tickets still require the original provider-reference
attestation. An actual manual-review outcome leaves the business payment pending.

If final parse completion fails, all interpretation, financial posting, business
status and claim changes roll back together. The previously committed admission
remains durable for redelivery. A committed processing receipt replays without a
second money/reward/stock effect, including after gateway retirement. The same
provider transaction is unique across gateways; changed events and nonce reuse
for different evidence fail. Freshness nonces are reclaimed in bounded batches,
while durable event and provider transaction identities preserve anti-reuse.

The stored projection contains financial/source facts and receiver business
identifiers, no full SMS, payer phone/name, AI text or payer digest. Existing raw,
attempt and interpretation retention remains governed by the source policy.
Receiver/source records and any exported original records need their separately
approved retention/processor rules; no jurisdiction approval is inferred here.

## Refund settlement channel

The same endpoint accepts the separate
`africlub.receiver-refund-settlement.v1` projection through the signed protocol
discriminator. Its 17 exact fields bind the immutable original payment event,
provider transaction and receiver settlement record, the durable approved refund
request/instruction, receiver/provider/country/currency, and the separate provider
refund transaction and settlement record/digest/time/status. No payer contact or
caller-selected destination is accepted. The existing gateway registry plus the
separate default-closed refund approval registry must authorize this channel.
Payment evidence cannot stand in for refund evidence.

`signGatewayRefundEvidence` and `deliverGatewayRefundEvidence` provide the actual
management caller. A successful admission commits before invoking
`process_trusted_payment_refund_evidence`; an error or unverified acknowledgement
returns a pending admission without a confirmation amount. Lost responses recover
with the same original event and instruction. The verified processor receipt
contains the cumulative confirmed amount for that one refund request, which may
include prior portions. A current failed or unknown event contributes zero and
has no compensation identity; prior confirmed portions may still leave the
request partially refunded or refunded. The bounded adapter checks receipt
identities, currency, states and current compensation acknowledgement. SQL owns
original-payment binding, approved amount limits, distinct current operator
authority, immutable compensation and atomic product consequences.

This channel supplies a reviewed protocol and canonical server integration. No
real provider refund operation, settlement feed, approved terms or supported
country journey has been supplied or accepted. The separate refund capability
stays closed until those external gates are met.

## Provisioning and external acceptance

Database ingestion config and every gateway default to disabled; no approved
source or key is seeded. The Edge service cannot write provisioning tables.
Activation requires accountable owner provisioning of an exact active receiver,
route, club, provider/country/currency and protocol, review/acceptance references,
and a current key record referring to an Edge secret named `SMS_GATEWAY_KEY_*`.
Use independently generated cryptographic signing material (32–64 decoded bytes)
and a separate high-entropy `SMS_PROCESSOR_SECRET`. Set
`TRUSTED_SMS_INGRESS_ENABLED=true` only after approved source/provider acceptance
and deployed configuration checks. Rotation creates a new key identity; old
key identity/secret-location binding cannot be edited in place. Revocation is
checked again after database waits before admitting or processing new work.

A MAC authenticates possession of the provisioned gateway credential; it does
not establish that a carrier sent an SMS or that money moved. Provider API
credentials, entitlement, receiver ownership, settlement/callback contract and
real supported-country journeys have not been supplied or verified. MTN's
[official integration example](https://momodeveloper.mtn.com/content/html_widgets/v98wn.html)
uses subscription/account authorization, environment and provider reference
headers; its sandbox example uses EUR. This implementation does not infer Rwanda
production settlement authority or callback verification from that example.
The detailed provider operation page was unavailable during primary-source
review, so no undocumented provider status or webhook signature scheme is assumed.

Transaction feature flags remain governed by the release register. Local forged,
replay, wrong-receiver/payer and synthetic financial tests prove local rejection,
atomicity and recovery mechanics only. Approved gateway deployment, provider
credentials, three-way receiver/order/settlement reconciliation and each real
club/country journey remain external release gates.
