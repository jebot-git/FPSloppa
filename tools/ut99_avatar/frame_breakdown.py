#!/usr/bin/env python3
"""Audit archived shooting CSVs and report counters with their original units."""
import argparse
import csv
import gzip
import hashlib
import json
from pathlib import Path


def summary(values):
    ordered = sorted(values)
    return {"samples": len(ordered), "p50": ordered[len(ordered) // 2],
            "p95": ordered[int(len(ordered) * .95)],
            "p99": ordered[int(len(ordered) * .99)], "max": ordered[-1]}


def analyze(folder):
    receipt = folder / "result.json"
    csv_path = folder / "frames.csv.gz"
    result = json.loads(receipt.read_text())
    with gzip.open(csv_path, "rt", newline="") as stream:
        frames = list(csv.DictReader(stream))
    assert len(frames) == result["performance"]["samples"]
    assert all(row["stream_settled"] == "true" for row in frames)
    metrics = ["frame_ms", "viewport_gpu_ms", "render_cpu_ms", "draw_calls", "primitives"]
    for metric in metrics:
        observed = summary([float(row[metric]) for row in frames])
        expected = result["performance"][metric]
        for key in ["samples", "p50", "p95", "p99", "max"]:
            assert abs(observed[key] - expected[key]) < 1e-6, (metric, key)
    tick_rate = 60
    previous = 0
    per_frame = []
    for row in frames:
        cumulative = round(float(row["simulation_seconds"]) * tick_rate)
        per_frame.append(cumulative - previous)
        previous = cumulative
    total_ticks = result["physics_ms"]["samples"]
    assert round(result["simulation_seconds"] * tick_rate) == total_ticks
    trailing_ticks = total_ticks - sum(per_frame)
    assert 0 <= trailing_ticks <= 8
    return {
        "source_sha256": {str(path): hashlib.sha256(path.read_bytes()).hexdigest()
                          for path in [receipt, csv_path]},
        "avatars": result["avatars"], "renderer": result["renderer"],
        "gpu": result["gpu"], "valid": result["valid"],
        "wall_seconds": result["wall_seconds"], "simulation_seconds": result["simulation_seconds"],
        "rendered_samples": len(frames), "physics_ticks": total_ticks, "trailing_ticks_after_last_render_sample": trailing_ticks,
        "wall_average_frame_ms": result["wall_seconds"] * 1000 / len(frames),
        "wall_average_render_fps": len(frames) / result["wall_seconds"],
        "ticks_per_render_mean": total_ticks / len(frames),
        "ticks_per_render": summary(per_frame),
        "reported_process_delta_ms": result["performance"]["frame_ms"],
        "gameplay_cpu_ms_per_tick": result["physics_ms"],
        "synthetic_pose_cpu_ms_per_tick": result["controller_pose_generation_ms"],
        "arm_update_cpu_ms_per_render": result["arm_pose_updates_ms_per_frame"],
        "combined_eye_render_cpu_ms": result["performance"]["render_cpu_ms"],
        "combined_eye_gpu_ms": result["performance"]["viewport_gpu_ms"],
        "draw_calls": result["performance"]["draw_calls"],
        "ai_work_calls": result["ai_work_calls"], "shots": result["shots"],
        "pool": result["pool"],
        "limits": [
            "Historical Mobile renderer and early arm approximation; predates accepted constrained IK and Forward+.",
            "Gameplay timer wraps game._physics_process only; engine physics and other callbacks are not separately timed.",
            "Counters use mixed per-tick and per-render units; medians cannot form an additive frame budget.",
            "CSV contains process deltas and cumulative simulation time, not per-render wall timestamps.",
            "Environment update_ms is a retained last-refresh value in this stationary run; exclude it from per-frame cost.",
            "No separate timings for collision, weapon traces, impacts, animation, head IK or native XR/encoding.",
        ],
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("folder", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = analyze(args.folder)
    encoded = json.dumps(report, indent=2) + "\n"
    if args.output:
        args.output.write_text(encoded)
    else:
        print(encoded, end="")
