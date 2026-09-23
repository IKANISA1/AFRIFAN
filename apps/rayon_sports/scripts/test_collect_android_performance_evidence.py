#!/usr/bin/env python3

import importlib.util
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("collect_android_performance_evidence.py")
SPEC = importlib.util.spec_from_file_location("android_performance", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class SurfaceFlingerLatencyTest(unittest.TestCase):
    def test_parses_android_app_summary_memory_totals(self) -> None:
        meminfo = """
 App Summary
                       Pss(KB)                        Rss(KB)
                        ------                         ------
           Java Heap:    12,345                         23,456
         Native Heap:     8,765                         10,000
                Code:     4,321                         20,000
               Stack:       512                            600
            Graphics:    10,240                         11,000
       Private Other:     2,048
              System:     3,210

               TOTAL PSS:    41,441            TOTAL RSS:    67,104       TOTAL SWAP PSS:       128
"""

        result = MODULE.parse_meminfo(meminfo)

        self.assertTrue(result["memory_stats_available"])
        self.assertEqual(result["java_heap_kb"], 12345)
        self.assertEqual(result["graphics_kb"], 10240)
        self.assertEqual(result["total_pss_kb"], 41441)
        self.assertEqual(result["total_rss_kb"], 67104)
        self.assertEqual(result["total_swap_pss_kb"], 128)

    def test_parses_active_frames_jank_and_percentiles(self) -> None:
        trace = "\n".join(
            [
                "16666666",
                "1 100000000 2",
                "1 116666666 2",
                "1 133333332 2",
                "1 166666664 2",
            ]
        )

        result = MODULE.parse_surface_flinger_latency(trace)

        self.assertTrue(result["frame_stats_available"])
        self.assertEqual(result["total_frames"], 3)
        self.assertEqual(result["janky_frames"], 1)
        self.assertEqual(result["janky_percent"], "33.33%")
        self.assertEqual(result["p95_ms"], 33.333)

    def test_excludes_idle_gaps_from_active_jank(self) -> None:
        trace = "\n".join(
            [
                "16666666",
                "1 100000000 2",
                "1 116666666 2",
                "1 500000000 2",
                "1 516666666 2",
            ]
        )

        result = MODULE.parse_surface_flinger_latency(trace)

        self.assertEqual(result["idle_gap_count"], 1)
        self.assertEqual(result["total_frames"], 2)
        self.assertEqual(result["janky_frames"], 0)
        self.assertEqual(result["janky_percent"], "0.00%")

    def test_assessment_uses_selected_frame_metric_source(self) -> None:
        assessment = MODULE.build_assessment(
            collection_success=True,
            frame_metrics={"total_frames": 80, "janky_percent": "2.50%"},
            frame_metrics_source="surface_flinger_flutter_blast_surface",
            start_timing={"totaltime_ms": 1800},
            startup_target_ms=3000,
            max_janky_percent=5.0,
            minimum_frame_sample=60,
            memory_metrics={"total_pss_kb": 180000},
            max_total_pss_kb=200000,
        )

        self.assertTrue(assessment["performance_signoff_ready"])
        self.assertEqual(
            assessment["frame_metrics_source"],
            "surface_flinger_flutter_blast_surface",
        )
        self.assertTrue(assessment["memory_target_met"])

    def test_assessment_fails_closed_without_memory_budget(self) -> None:
        assessment = MODULE.build_assessment(
            collection_success=True,
            frame_metrics={"total_frames": 80, "janky_percent": "2.50%"},
            frame_metrics_source="android_gfxinfo",
            start_timing={"totaltime_ms": 1800},
            startup_target_ms=3000,
            max_janky_percent=5.0,
            minimum_frame_sample=60,
            memory_metrics={"total_pss_kb": 180000},
            max_total_pss_kb=None,
        )

        self.assertFalse(assessment["memory_budget_declared"])
        self.assertIsNone(assessment["memory_target_met"])
        self.assertFalse(assessment["performance_signoff_ready"])
        self.assertIn(
            "A maximum total-PSS budget was not declared.",
            assessment["issues"],
        )


if __name__ == "__main__":
    unittest.main()
