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

## Startup And Window Readiness

| Metric | Before | After | Final |
| --- | ---: | ---: | ---: |
| Launch state | COLD | COLD | COLD |
| `am start -W` total time | 1612 ms | 2506 ms | 1561 ms |
| Process stopped before launch | true | true | true |
| App focused/top window after settle | true | true | true |
| Splash top window after settle | false | false | false |
| Perfetto trace size | 33,438,357 bytes | 33,455,386 bytes | 33,422,667 bytes |

All three runs met the current 3000 ms startup target. The middle after-surface
run was noisier and logcat recorded a `Skipped 54 frames` burst during startup;
the final offset rebuild returned to a 1561 ms cold start. Treat these timings
as useful single-device evidence, not a final p95/p99 benchmark.

## Frame Timeline

| Metric | Before | After | Final |
| --- | ---: | ---: | ---: |
| SurfaceFlinger actual frame rows | 313 | 388 | 376 |
| On-time present frames | 312 | 386 | 376 |
| Late present / jank frames | 1 | 2 | 0 |
| Jank frame rate | 0.32% | 0.52% | 0.00% |
| Max actual-frame duration | 21.290 ms | 25.856 ms | 10.584 ms |

The frame timeline stayed below the current 5% jank target in all captures.
However, the app-specific `dumpsys gfxinfo` sample returned 0 frames in the
final run, so Perfetto remains the stronger source for this flow.

## App Raster Thread

| Metric | Before | After | Final |
| --- | ---: | ---: | ---: |
| `GPURasterizer::Draw` slices | 300 | 349 | 370 |
| Draw slices over 16 ms | 297 | 311 | 321 |
| Percent over 16 ms | 99.00% | 89.11% | 86.76% |
| Draw slices over 33 ms | 1 | 0 | 0 |
| Average draw duration | 21.981 ms | 16.635 ms | 16.628 ms |
| Max draw duration | 51.219 ms | 18.737 ms | 18.979 ms |

Replacing onboarding `GlassCard` blur surfaces with tokenized solid
`AfriSurfaceCard` surfaces materially reduced worst-case raster time and
removed >33 ms raster draws in this measured flow. It did not fully clear the
16 ms raster budget, so performance signoff remains open.

## App Main Thread

| Metric | Before | After | Final |
| --- | ---: | ---: | ---: |
| Max app main-thread slice | 4.310 ms | not resolved by process name in after trace | 18.731 ms |
| Max app Dart worker slice | not measured | not measured | 18.136 ms |

The before trace did not point to Dart main-thread work as the bottleneck. The
final trace included one 18.731 ms `Dart_NotifyIdle` main-thread slice and one
18.136 ms Dart worker slice, but the dominant repeated budget issue remains
raster/GPU work around Flutter rendering.

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
- External services: Firebase Installations/FIS and Supabase DNS/service
  failures remain release-readiness blockers.
