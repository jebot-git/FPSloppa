#!/usr/bin/env python3
"""Bounded, reproducible full-physics practice matches; no network peers required."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
CASES = [
    ("lqdm1", "dm", "doom"), ("lqdm2", "tdm", "doom"),
    ("lqdm3", "ctf", "doom"), ("koth_solstice", "koth", "doom"), ("koth_torture", "koth", "doom"),
    ("koth_hyperborea", "koth", "doom"), ("koth_alichar", "koth", "doom"),
    ("lqdm5", "ig", "doom"), ("lqdm6", "ft", "doom"),
    ("lqdm7", "cc", "doom"), ("lqdm8", "if", "doom"),
    ("tf_ironspan", "tf", "doom"), ("as_hislop", "as", "doom"),
    ("as_frigate", "as", "ut99"), ("dm_lasercade_slop", "dm", "quake"),
    ("dm_auhdm2_slop", "dm", "ut99"), ("dm_anctomb_slop", "dm", "doom"),
    ("dm_anchall_slop", "dm", "quake"), ("dm_battlef_slop", "dm", "ut99"),
    ("as_hislop_tiny", "as", "ut99"), ("as_frigate_tiny", "as", "quake"),
    ("tf_ironspan", "tf", "quake"), ("tf_ironspan", "tf", "ut99"),
]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", default="current")
    parser.add_argument("--project", type=Path, default=ROOT, help="Optional isolated Godot project copy")
    parser.add_argument("--seconds", type=int, default=300)
    parser.add_argument("--timeout", type=int, default=480)
    parser.add_argument("--case", action="append", help="Map/mode/rules or map to include")
    parser.add_argument("--snapshot-ai", action="store_true", help="Freeze AI sources for comparison while editing")
    args = parser.parse_args()
    dest = ROOT / "test-results/bot-soak" / args.label
    dest.mkdir(parents=True, exist_ok=True)
    project = args.project.resolve()
    ai = project / "deathmatch/bots.gd"
    navigation = project / "deathmatch/bot_ai/navigation.gd"
    teamplay = project / "deathmatch/bot_ai/teamplay.gd"
    if args.snapshot_ai:
        if (dest / "bots.gd").exists():
            parser.error("Choose a fresh label to avoid overwriting an AI snapshot")
        (dest / "navigation.gd").write_text(navigation.read_text())
        (dest / "teamplay.gd").write_text(teamplay.read_text())
        (dest / "bots.gd").write_text(ai.read_text().replace(
            "res://deathmatch/bot_ai/navigation.gd", str(dest / "navigation.gd")).replace(
            "res://deathmatch/bot_ai/teamplay.gd", str(dest / "teamplay.gd")))
    summary = []
    for number, (map_name, mode, rules) in enumerate(CASES):
        key = f"{map_name}-{mode}-{rules}"
        if args.case and key not in args.case and map_name not in args.case:
            continue
        output = dest / f"{key}.json"
        options = dict(map=map_name, mode=mode, rules=rules, seconds=args.seconds,
                       seed=7129, class_offset={"doom": 0, "quake": 1, "ut99": 2}[rules],
                       output=str(output))
        if args.snapshot_ai:
            options["ai_script"] = str(dest / "bots.gd")
        options["source_sha256"] = {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
            for path in ((dest / "bots.gd", dest / "navigation.gd", dest / "teamplay.gd") if args.snapshot_ai else (ai, navigation, teamplay))}
        command = ["godot", "--headless", "--xr-mode", "off", "--fixed-fps", "60",
                   "--path", str(project), "--script", "res://deathmatch/tests/bot_soak.gd",
                   "--", json.dumps(options)]
        started = time.monotonic()
        with (dest / f"{key}.log").open("w") as log:
            try:
                result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                    env={**os.environ, "XDG_DATA_HOME": "/tmp/fpsloppa-bot-soak"}, timeout=args.timeout)
                code = result.returncode
            except subprocess.TimeoutExpired:
                code = 124
        errors = [line for line in (dest / f"{key}.log").read_text(errors="replace").splitlines()
                  if line.startswith(("SCRIPT ERROR:", "ERROR:"))]
        if errors and code == 0:
            code = 1
        row = dict(case=key, exit_code=code, wall_seconds=round(time.monotonic()-started, 2), runtime_errors=errors)
        if code == 0 and output.exists():
            data = json.loads(output.read_text())
            bots = list(data["bots"].values())
            row.update(seconds=round(data["simulated_seconds"], 1), shots=sum(b["shots"] for b in bots),
                distance=round(sum(b["distance"] for b in bots)),
                stationary_percent=round(100*sum(b["stationary_seconds"] for b in bots)/max(1,sum(b["active_seconds"] for b in bots)), 2),
                max_stall=round(max(b["max_stall"] for b in bots), 1), score=data["score"],
                stage=data["as_stage"], checkpoint=data["as_checkpoint"],
                physics_p50_ms=data["physics_p50_ms"], physics_p95_ms=data["physics_p95_ms"])
        summary.append(row)
        (dest / "summary.json").write_text(json.dumps(summary, indent=2)+"\n")
        print(json.dumps(row), flush=True)
    return int(any(row["exit_code"] != 0 for row in summary))

if __name__ == "__main__":
    raise SystemExit(main())
