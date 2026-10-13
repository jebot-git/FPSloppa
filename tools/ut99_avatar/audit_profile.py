#!/usr/bin/env python3
"""Verify the profiled 64-avatar receipt against both raw per-frame CSVs."""
import argparse
import csv
import gzip
import json
from pathlib import Path
from frame_breakdown import summary


def read_rows(folder, name):
    path = folder / name
    if path.exists():
        with path.open(newline="") as stream:
            return list(csv.DictReader(stream))
    with gzip.open(folder / (name + ".gz"), "rt", newline="") as stream:
        return list(csv.DictReader(stream))


def audit(folder, minimum_seconds):
    result = json.loads((folder / "result.json").read_text())
    categories = json.loads((folder / "categories.json").read_text())
    frames = read_rows(folder, "frames.csv")
    rows = read_rows(folder, "categories.csv")
    assert result["valid"] and result["avatars"] == 64 and result["renderer"] == "forward_plus"
    assert result["wall_seconds"] >= minimum_seconds
    assert result["controller_arms"] and result["tracked_arm_count"]["p50"] == 64
    assert result["both_eye_visible"]["p50"] == 64 and result["ai_work_calls"] == 0
    assert result["shots"] > 0 and result["deaths"] == 0
    assert result["pool"]["invariants_ok"]
    assert result["valid_head_controller_poses"] == result["physics_ms"]["samples"] * 64
    assert len(frames) == result["performance"]["samples"]
    assert all(row["stream_settled"] == "true" for row in frames)
    checks = 10
    for metric in ["frame_ms", "viewport_gpu_ms", "render_cpu_ms", "draw_calls", "primitives"]:
        observed = summary([float(row[metric]) for row in frames])
        for key, value in observed.items():
            assert abs(value - result["performance"][metric][key]) < 1e-5, (metric, key)
            checks += 1
    assert len(rows) == categories["frames"]
    wall = [float(row["wall_frame_ms"]) for row in rows]
    assert min(wall) > 0
    assert abs(summary(wall)["p50"] - categories["wall_frame_ms"]["p50"]) < 1e-5
    exclusive_total = 0
    for label, counters in categories["categories"].items():
        inclusive = [float(row[label + "_inclusive_ms"]) for row in rows]
        exclusive = [float(row[label + "_exclusive_ms"]) for row in rows]
        assert all(i + 1e-4 >= e >= 0 for i, e in zip(inclusive, exclusive)), label
        for unit, values in [("inclusive", inclusive), ("exclusive", exclusive)]:
            for key, value in summary(values).items():
                assert abs(value - counters[unit + "_ms_per_render"][key]) < 1e-4, (label, unit, key)
                checks += 1
            # Totals can include a partial frame after the last post-draw sample.
            assert sum(values) <= counters[unit + "_ms"] + .1, (label, unit, "total")
        exclusive_total += sum(exclusive)
    return {"passed": True, "checks": checks, "render_frames": len(frames),
            "category_frames": len(rows), "all_stream_settled": True,
            "wall_sample_total_ms": sum(wall), "profiled_exclusive_cpu_total_ms": exclusive_total,
            "unattributed_wall_total_ms": sum(wall) - exclusive_total,
            "note": "Unattributed wall time includes unwrapped engine/scene/thread/wait work and profiler overhead; it is not a measured physics category. Process and post-draw sample counts differ at the window boundary."}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("folder", type=Path)
    parser.add_argument("--minimum-seconds", type=float, default=120)
    args = parser.parse_args()
    report = audit(args.folder, args.minimum_seconds)
    (args.folder / "audit.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report))
