# Rayon Sports Android Profile Perfetto Summary - 2026-06-28

## Scope

- Device: Pixel 4a, Android 13, 1080 x 2340, density 440.
- App id: `rw.gikundiro.app`.
- Build mode: Flutter profile APK.
- Flow: cold launch into onboarding, settle, then 16 horizontal swipe events.
- Tooling: Perfetto trace decoded with the official `trace_processor` wrapper
  downloaded to `/tmp/rayon_perfetto_tools/trace_processor`.

## Trace Artifacts

| Run | Manifest | Trace |
| --- | --- | --- |
| Before onboarding surface change | `../android_performance_pixel4a_profile_perfetto_manifest.json` | `rayon-profile-flow-2026-06-28T12-06-06-445680-00-00.pftrace` |
| After onboarding surface change | `../android_performance_pixel4a_profile_perfetto_after_onboarding_surface_manifest.json` | `rayon-profile-flow-2026-06-28T12-17-26-961959-00-00.pftrace` |
| Final offset rebuild with scoped logs | `../android_performance_pixel4a_profile_perfetto_final_scoped_logs_manifest.json` | `rayon-profile-flow-2026-06-28T12-36-05-463906-00-00.pftrace` |
| After expected-offline observability cleanup | `../android_performance_pixel4a_profile_perfetto_after_expected_offline_observability_manifest.json` | `rayon-profile-flow-2026-06-28T18-51-40-883593-00-00.pftrace` |
| After Dart FCM startup gate | `../android_performance_pixel4a_profile_perfetto_after_fcm_startup_gate_manifest.json` | `rayon-profile-flow-2026-06-28T19-09-04-285390-00-00.pftrace` |
| After native + Dart FCM startup gate | `../android_performance_pixel4a_profile_perfetto_after_native_fcm_startup_gate_manifest.json` | `rayon-profile-flow-2026-06-28T19-17-42-389411-00-00.pftrace` |
| After Firebase clean startup gate | `../android_performance_pixel4a_profile_perfetto_after_firebase_clean_startup_gate_manifest.json` | `rayon-profile-flow-2026-06-28T19-38-44-385530-00-00.pftrace` |

## Startup And Window Readiness

| Metric | Before | After | Final | Offline Observability | Dart FCM Gate | Native + Dart FCM Gate | Firebase Clean Gate |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Launch state | COLD | COLD | COLD | COLD | COLD | COLD | COLD |
| `am start -W` total time | 1612 ms | 2506 ms | 1561 ms | 2004 ms | 2509 ms | 2409 ms | 2086 ms |
| Process stopped before launch | true | true | true | true | true | true | true |
| App focused/top window after settle | true | true | true | true | true | true | true |
| Splash top window after settle | false | false | false | false | false | false | false |
| Perfetto trace size | 33,438,357 bytes | 33,455,386 bytes | 33,422,667 bytes | 33,360,042 bytes | 33,460,640 bytes | 33,398,254 bytes | 33,334,808 bytes |

All four runs met the current 3000 ms startup target. The middle after-surface
run was noisier and logcat recorded a `Skipped 54 frames` burst during startup;
the final offset rebuild returned to a 1561 ms cold start, and the
expected-offline observability rebuild measured 2004 ms. The two FCM startup
gate runs stayed inside the target at 2509 ms and 2409 ms. The Firebase clean
startup gate run measured 2086 ms after removing startup observability
registrars and no-touching disabled Dart SDKs. Treat these timings as useful
single-device evidence, not a final p95/p99 benchmark.

## Frame Timeline

| Metric | Before | After | Final | Offline Observability | Dart FCM Gate | Native + Dart FCM Gate | Firebase Clean Gate |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| SurfaceFlinger actual frame rows | 313 | 388 | 376 | 379 | 382 | 391 | 372 |
| On-time present frames | 312 | 386 | 376 | 377 | 381 | 391 | 372 |
| Late present / jank frames | 1 | 2 | 0 | 2 | 1 | 0 | 0 |
| Jank frame rate | 0.32% | 0.52% | 0.00% | 0.53% | 0.26% | 0.00% | 0.00% |
| Max actual-frame duration | 21.290 ms | 25.856 ms | 10.584 ms | 29.480 ms | 10.656 ms | 10.495 ms | 10.379 ms |

The frame timeline stayed below the current 5% jank target in all captures.
However, the app-specific `dumpsys gfxinfo` sample returned 0 frames in the
final and expected-offline observability runs, so Perfetto remains the stronger
source for this flow.

## App Raster Thread

| Metric | Before | After | Final | Offline Observability | Dart FCM Gate | Native + Dart FCM Gate | Firebase Clean Gate |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `GPURasterizer::Draw` slices | 300 | 349 | 370 | 355 | 359 | 366 | 357 |
| Draw slices over 16 ms | 297 | 311 | 321 | 0 | 189 | 339 | 1 |
| Percent over 16 ms | 99.00% | 89.11% | 86.76% | 0.00% | 52.65% | 92.62% | 0.28% |
| Draw slices over 33 ms | 1 | 0 | 0 | 0 | 0 | 1 | 0 |
| Average draw duration | 21.981 ms | 16.635 ms | 16.628 ms | 7.808 ms | 12.629 ms | 16.662 ms | 7.092 ms |
| Max draw duration | 51.219 ms | 18.737 ms | 18.979 ms | 15.096 ms | 20.448 ms | 41.082 ms | 21.774 ms |

Replacing onboarding `GlassCard` blur surfaces with tokenized solid
`AfriSurfaceCard` surfaces materially reduced worst-case raster time and
removed >33 ms raster draws in this measured flow. The expected-offline
observability rebuild is the first captured profile run with no
`GPURasterizer::Draw` slices over 16 ms, but performance signoff still needs
repeatability and a usable app-level frame source beyond the current `gfxinfo`
0-frame samples.

The Firebase clean startup gate run preserved the strongest frame-timeline
result and returned the raster thread close to the expected-offline result:
1/357 raster draws over 16 ms and none over 33 ms. Performance signoff still
needs repeated profile/release captures and a route-complete flow, but this
single run is now clean enough to use as the current baseline.

## Firebase Startup Noise

| Signal | Offline Observability | Dart FCM Gate | Native + Dart FCM Gate | Component Gate | Firebase Clean Gate |
| --- | --- | --- | --- | --- | --- |
| `FirebaseMessaging` startup error | present | present | absent | absent | absent |
| `FIS_AUTH_ERROR` | present | present | absent | absent | absent |
| `FLTFireBGExecutor` / background messaging service | present | present | absent | absent | absent |
| `Firebase-Installations` suspended project error | present | present | present | absent | absent |
| `FirebaseCrashlytics component is not present` local error | absent | absent | absent | present | absent |

The Dart-only FCM gate was insufficient for the upgrade path because persisted
FCM state still allowed Messaging to start. The native + Dart gate prevented
Messaging token/background startup in the captured upgrade run. Firebase
Installations still called the suspended `gen-lang-client-0172279957` project
through Crashlytics/Sessions until the Firebase component registrars were
removed from the merged manifest. The final clean gate also made disabled Dart
observability a no-touch path, removing the intermediate local Crashlytics
component error. To re-enable these SDKs for production, provide a valid
Firebase project and build with the explicit `ENABLE_FIREBASE_OBSERVABILITY`
and `ENABLE_FIREBASE_APP_CHECK` defines after restoring/allowing the required
registrars.

## App Main Thread

| Metric | Before | After | Final | Offline Observability |
| --- | ---: | ---: | ---: | ---: |
| Max app main-thread slice | 4.310 ms | not resolved by process name in after trace | 18.731 ms | not in top sampled rows |
| Max app Dart worker slice | not measured | not measured | 18.136 ms | 31.648 ms `ConcurrentMark` |

The before trace did not point to Dart main-thread work as the bottleneck. The
final trace included one 18.731 ms `Dart_NotifyIdle` main-thread slice and one
18.136 ms Dart worker slice. The expected-offline observability trace did not
surface app main-thread slices in the top sampled rows; its largest app-owned
row from the sampled set was a 31.648 ms `DartWorker` `ConcurrentMark`.

## Queries Used

```sql
select count(*) as frames,
       sum(case when on_time_finish=0 then 1 else 0 end) as not_on_time,
       sum(case when jank_type is not null and jank_type != 'None' then 1 else 0 end) as jank_frames,
       round(avg(dur)/1000000.0,3) as avg_ms,
       round(max(dur)/1000000.0,3) as max_ms
from actual_frame_timeline_slice;
```

```sql
select count(*) as draws,
       sum(case when s.dur > 16000000 then 1 else 0 end) as over_16ms,
       sum(case when s.dur > 33000000 then 1 else 0 end) as over_33ms,
       round(100.0*sum(case when s.dur > 16000000 then 1 else 0 end)/count(*),2) as pct_over_16ms,
       round(avg(s.dur)/1000000.0,3) as avg_ms,
       round(max(s.dur)/1000000.0,3) as max_ms
from slice s
join thread_track tt on s.track_id=tt.id
join thread th on tt.utid=th.utid
where th.name='1.raster'
  and s.name='GPURasterizer::Draw';
```

## Current Assessment

- Startup: improved enough for provisional evidence, but needs repeated clean
  runs once Firebase/Supabase/device noise is resolved.
- Frame timeline: below the 5% jank target in all Perfetto traces, with the
  final offset rebuild showing 0 late/jank frames in this single run.
- Raster thread: improved after removing onboarding blur, but still too close
  to or above the 16 ms budget for final signoff.
- Store screenshot readiness: the final onboarding screenshot is clean after
  temporarily hiding and restoring the developer-device accessibility shortcut,
  but route-by-route clean captures are still incomplete.
- Expected-offline observability: the rebuilt profile APK no longer produced
  the previous `FeatureConfigRepo` / `get_platform_config` DNS error in the
  collector excerpt or current filtered logcat search for this run.
- External services: Firebase Messaging, Crashlytics, Sessions, Performance,
  Analytics, and App Check are now gated out of startup by default. The current
  profile log excerpt no longer shows Firebase Installations, FIS auth, or
  suspended-project errors. Release readiness still needs a valid production
  Firebase project and an explicit re-enable plan for Crashlytics/App Check
  before those services can be claimed ready.

## Release Responsive Search Addendum

Final release APK:
`apps/rayon_sports/build/app/outputs/flutter-apk/app-release.apk`,
SHA-256
`f9d5c81c0774810501910caa03ea7dc783469c95edbcc82c7edcd07b43ae9edc`.

Final release startup/focus manifest:
`apps/rayon_sports/store_metadata/play_store/android_performance_pixel4a_release_perfetto_responsive_search_startup_manifest.json`.

Final release trace:
`apps/rayon_sports/store_metadata/play_store/performance_traces/rayon-profile-flow-2026-06-28T21-46-42-833452-00-00.pftrace`.

| Metric | Release startup/focus |
| --- | ---: |
| Cold start `TotalTime` | 570 ms |
| App focused after settle | yes |
| Critical Firebase startup terms | 0 |
| SurfaceFlinger actual frame rows | 173 |
| Not-on-time frames | 0 |
| Jank-classified frames | 1 |
| Average actual-frame duration | 6.669 ms |
| Max actual-frame duration | 20.912 ms |

The release trace is suitable as startup/focus evidence for the responsive
search APK. It is not a full scripted interaction signoff: horizontal scripted
swipes on the Pixel 4a / Android 13 device were intercepted by the system
edge-back gesture and moved the app to the launcher, even after narrowing the
gesture band and switching to leftward swipes. Keep a route-complete interaction
performance pass open for the next release-readiness phase.
