# Africlub Offline Behavior Strategy

## Overview

The Africlub mobile app follows a **cache-first, network-refresh** pattern. All
data is fetched from Supabase via RPC calls and cached locally using
`HiveCacheService`. When the network is unavailable, the app gracefully degrades
by serving cached data and showing clear state indicators.

---

## Architecture

```
Supabase RPC  →  SafeRpc (timeout + retry)
                    ↓
              HiveCacheService (Hive box, TTL-based)
                    ↓
              UI (AsyncNotifier / setState)
```

### Cache Layers

| Layer | Implementation | TTL | Fallback |
|---|---|---|---|
| Fixtures catalog | `HiveCacheService` | 5 min | Expired cache |
| Competition catalog | `HiveCacheService` | 6 hr | Expired cache |
| User predictions | `HiveCacheService` | 2 min | Expired cache |
| Community picks | `HiveCacheService` | 5 min | Expired cache |
| FET leaderboard | `SafeRpc` response | per-request | Empty list |
| CMS content blocks | `FeatureConfigService` | session | Last snapshot |

### Cache Miss Behavior

- `_cachedListQuery()` and `_cachedObjectQuery()` in `PredictionRepository`
  always attempt network first. On failure, they call `_readCachedList()` or
  `_readCachedObject()` with `allowExpired: true` — meaning stale data is
  served rather than showing an error.
- `SafeRpc` automatically retries transient failures up to 3 times with
  exponential backoff.

---

## Screen-Level Behavior

### Loading States
Every screen MUST show a skeleton loader (`AfriSkeletonList`) while data loads.

### Error States
Every screen MUST catch errors and show `AfriStateView.offline()` with:
- A clear message ("Challenges are temporarily unavailable")
- A "Retry" button that re-triggers the data load

### Empty States
When data loads successfully but is empty, screens show contextual empty state
messaging (e.g., "No predictions yet. Browse fixtures to get started.").

---

## Network Transitions

The app does NOT actively monitor connectivity changes. Instead:

1. **Pull-to-refresh** is available on all data screens via `RefreshIndicator`.
2. **Tab switch** re-triggers data loads for stale tabs.
3. **`SafeRpc`** handles transient failures transparently with retry.

### What Happens When Offline

| Action | Behavior |
|---|---|
| Open Home tab | Shows cached feed, stale data served |
| Open Fan Zone tab | Shows cached challenges, stale data served |
| Open Fixture browser | Shows cached fixtures if available |
| Submit prediction | Fails with error snackbar after timeout |
| Join partner WDW pool | Fails with error snackbar after timeout |
| Pull to refresh | Shows loading, then error state if still offline |
| View membership | Shows cached membership data |

---

## Intentional Limitations

1. **No offline queue**: Write operations (predictions, partner pool joins,
   partner earn claims, catalog reward redemptions, and admin adjustments)
   are NOT queued for later submission. They fail immediately with user feedback.
   This is intentional — stale predictions could be invalid after kickoff.

2. **No background sync**: The app does not sync data in the background. All
   data fetching is user-initiated (screen load, pull-to-refresh, tab switch).

3. **No connectivity banner**: There is no persistent "You are offline" banner.
   Instead, each screen handles its own error state. This avoids permission
   prompts and keeps the UX clean.

---

## Future Considerations

- **Optimistic writes**: Could queue non-time-sensitive writes (friend requests,
  profile updates) for background submission.
- **Connectivity monitoring**: Could add a lightweight connectivity check using
  `connectivity_plus` to show a subtle offline indicator.
- **Service worker (web)**: The web admin panel could benefit from a service
  worker for static asset caching.
