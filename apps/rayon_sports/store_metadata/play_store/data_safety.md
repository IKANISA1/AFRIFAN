# Gikundiro — Google Play Data Safety working declaration

Status: conservative draft pending reconciliation to the exact signed AAB,
production feature configuration, SDK behavior, privacy approval, and Play
Console entry. “Collected” means transmitted off device. “Shared: No” assumes
Supabase and Firebase remain contracted service providers processing only on
the developer's behalf; the release owner must verify that assumption.

## Overview
This document provides the answers for the Google Play Data Safety form.
The app collects and processes user data through Supabase (backend) and local storage (Hive).

---

## Data Collected

### 1. Personal info
| Data Type | Collected | Shared | Purpose | Optional |
|-----------|-----------|--------|---------|----------|
| Name | Yes | No | Private profile and membership records; public supporter labels are system-controlled aliases | Yes |
| Email address | No | No | Not collected in the shipped mobile auth flow | N/A |
| Phone number | Yes | No | Optional phone authentication, profile/contact use, and authorized mobile-money handoff | Yes, except when required by an enabled signed-in journey |

### 2. Financial Info
| Data Type | Collected | Shared | Purpose | Optional |
|-----------|-----------|--------|---------|----------|
| Purchase history | Yes | No | Contribution/ticket tracking | No |
| Other financial info | Yes | No | Mobile-money transaction references, contribution records, and reconciliation | Varies by enabled transaction feature |

### 3. App activity and user content
| Data Type | Collected | Shared | Purpose | Optional |
|-----------|-----------|--------|---------|----------|
| App interactions | Yes | No | Core journeys, security/audit state, football predictions, and feature use | No |
| Other user-generated content | Yes | No | Private profile nickname and structured football prediction selections. Cross-user text, challenge notes, social discovery, and public user names are disabled for this candidate | Varies by the private profile or prediction journey |

### 4. Device or other IDs
| Data Type | Collected | Shared | Purpose | Optional |
|-----------|-----------|--------|---------|----------|
| Device/app identifiers | Yes | No | Firebase App Check, notification delivery, auth security | No |

### 5. App Info and Performance
| Data Type | Collected | Shared | Purpose | Optional |
|-----------|-----------|--------|---------|----------|
| Crash logs | Conditional | No | App stability and incident diagnosis | Yes — release configuration and applicable consent must allow collection |
| Diagnostics / performance | Conditional | No | Startup, network, and runtime reliability | Yes — release configuration and applicable consent must allow collection |

### 6. Conditional diagnostics and analytics
| Data Type | Collected | Shared | Purpose | Optional |
|-----------|-----------|--------|---------|----------|
| Product interaction | Conditional | No | Privacy-filtered feature analytics | Yes — exact build must enable observability and the user must consent |

## Data Usage Purposes

- **App functionality**: Core features rely on anonymous authentication, optional profile data, transaction records, and structured supporter activity
- **Account management**: Anonymous account/session continuity and optional MoMo profile linkage
- **Notifications**: Optional alert delivery for configured releases
- **Fraud prevention / security**: Device/app attestation for Firebase App Check
- **Analytics**: Closed-taxonomy, privacy-filtered product interactions only after explicit consent
- **Developer communications**: Not enabled by analytics or diagnostics collection

---

## Data Handling

### Encryption and security
- Data is encrypted in transit (HTTPS/TLS) via Supabase
- Authentication and device credentials use platform-protected local storage where implemented
- Do not select the independent-security-review badge without current qualifying evidence

### User Data Deletion
- Users can request account deletion via Settings > Delete Account
- Users who cannot access the app can request deletion through the public
  `https://gikundiro.com/account-deletion` pathway
- Account-linked application data is removed as part of the account deletion flow, subject to lawful retention requirements for transactional records

### Data retention

- Account/profile data: working rule is retention until deletion.
- Transaction, fraud-prevention, security, and audit records: the exact legal
  basis, category-specific periods, access restriction, and deletion schedule
  require privacy/legal approval. Do not enter “3 years” as a blanket store
  answer without approved Rwanda-specific evidence.

---

## Third-Party SDKs

| SDK | Data Collected | Purpose |
|-----|---------------|---------|
| Supabase | Auth tokens, user data | Backend / Database |
| Firebase | Installation/messaging identifiers when notifications are enabled; app-attestation data when App Check is enabled; diagnostics and product interactions only when the exact build enables observability and applicable consent permits collection | Push messaging, security, reliability, and optional analytics |

---

## Declarations

- [x] App does NOT sell user data
- [x] App encrypts data in transit
- [x] App provides a way for users to request data deletion
- [x] App provides both an in-app and public-web deletion request pathway
- [ ] Service-provider contracts and SDK data-use terms have been verified for the final release
- [ ] Exact signed-AAB SDK and network behavior has been reconciled
- [ ] Privacy/legal owner has approved each data type, purpose, optionality, retention rule, and deletion exception
- [ ] Play Console Data Safety and data-deletion answers match this approved release-specific declaration
