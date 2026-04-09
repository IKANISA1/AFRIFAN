# Gikundiro — Google Play Data Safety Declaration

## Overview
This document provides the answers for the Google Play Data Safety form.
The app collects and processes user data through Supabase (backend) and local storage (Hive).

---

## Data Collected

### 1. Personal Info
| Data Type | Collected | Shared | Purpose | Optional |
|-----------|-----------|--------|---------|----------|
| Name | Yes | No | Account / Membership | Yes |
| Email address | No | No | Not collected in the shipped mobile auth flow | N/A |
| Phone number | Yes | No | Optional MoMo payments, SMS ledger | Yes |

### 2. Financial Info
| Data Type | Collected | Shared | Purpose | Optional |
|-----------|-----------|--------|---------|----------|
| Purchase history | Yes | No | Contribution/ticket tracking | No |
| Other financial info | Yes | No | MoMo transaction ledger | No |

### 3. App Activity
| Data Type | Collected | Shared | Purpose | Optional |
|-----------|-----------|--------|---------|----------|
| App interactions | Yes | No | Gamification, feature usage | No |

### 4. Device or other IDs
| Data Type | Collected | Shared | Purpose | Optional |
|-----------|-----------|--------|---------|----------|
| Device/app identifiers | Yes | No | Firebase App Check, notification delivery, auth security | No |

### 5. Photos and Videos
| Data Type | Collected | Shared | Purpose | Optional |
|-----------|-----------|--------|---------|----------|
| Photos / face data | Yes | No | BioPay enrollment and matching | Yes |

---

## Data Usage Purposes

- **App functionality**: Core features rely on anonymous authentication, optional profile data, and purchase history
- **Account management**: Anonymous account/session continuity and optional MoMo profile linkage
- **Notifications**: Optional alert delivery for configured releases
- **Fraud prevention / security**: Device/app attestation for Firebase App Check, face data for BioPay

---

## Data Handling

### Encryption
- Data is encrypted in transit (HTTPS/TLS) via Supabase
- Sensitive local data may be stored in encrypted local app storage where supported by the implementation

### User Data Deletion
- Users can request account deletion via Settings > Delete Account
- Account-linked application data is removed as part of the account deletion flow, subject to lawful retention requirements for transactional records

### Data Retention
- Account data: retained until account deletion
- Transaction history: retained for 3 years (legal compliance)
- BioPay biometric templates/embeddings may be transmitted to secure server-side matching services for enrolled users and are retained while the enrollment remains active

---

## Third-Party SDKs

| SDK | Data Collected | Purpose |
|-----|---------------|---------|
| Supabase | Auth tokens, user data | Backend / Database |
| Firebase | App attestation data, messaging token | App Check / Push messaging |
| Google ML Kit | Face geometry (local) | BioPay facial detection |
| TensorFlow Lite | Face embeddings (local and secure request payloads) | BioPay face matching |

---

## Declarations

- [ ] App does NOT sell user data
- [ ] App encrypts data in transit
- [ ] App provides a way for users to request data deletion
- [ ] App complies with Google Play Families Policy (N/A — target 13+)
- [ ] App follows the User Data Policy
