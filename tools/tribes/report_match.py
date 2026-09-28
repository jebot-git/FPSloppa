#!/usr/bin/env python3
"""Summarize a recorded ST bot match; sampled transitions are not event totals."""
import argparse
import json
from pathlib import Path
import re
from math import dist


def vector(text):
    return tuple(map(float, re.findall(r"-?\d+(?:\.\d+)?(?:e[+-]?\d+)?", text)))


def summarize(folder):
    folder = Path(folder)
    complete = (folder / "result.json").exists()
    if complete:
        result = json.loads((folder / "result.json").read_text())
        samples = result["samples"]
    elif (folder / "samples.json").exists():
        samples = json.loads((folder / "samples.json").read_text())
        result = samples[-1]
    else:
        result = json.loads((folder / "server.json").read_text())
        samples = [result]
    previous, lanes, roles, diversions, captures = {}, {}, {}, [], []
    last_score = [0, 0]
    for sample in samples:
        if sample["scores"] != last_score:
            captures.append({"observed_seconds": sample["seconds"], "scores": sample["scores"]})
            last_score = sample["scores"]
        for bot in sample["bots"]:
            ident = bot["id"]
            if "lane" in bot:
                lanes.setdefault(ident, set()).add(bot["lane"])
            roles.setdefault(ident, set()).add(bot["role"])
            old = previous.get(ident)
            if (old and not bot["dead"] and not old["dead"]
                    and old["deaths"] == bot["deaths"] and old["role"] == "capper"
                    and old["goal"] == "st:flag" and bot["role"] == "siege"
                    and dist(vector(old["position"]), vector(old["target"])) < 100):
                diversions.append({"seconds": sample["seconds"], "id": ident})
            previous[ident] = bot
    log = (folder / "server.log").read_text()
    first_capture = result.get("first_capture_seconds")
    cutoff = result.get("first_capture_limit_seconds", 600)
    if first_capture is None:
        deadline_status = "not_recorded"
    elif 0 <= first_capture <= cutoff + .00001:
        deadline_status = "passed"
    elif first_capture > cutoff or result["seconds"] >= cutoff - .00001:
        deadline_status = "failed"
    else:
        deadline_status = "incomplete" if complete else "pending"
    return {
        "folder": str(folder), "complete": complete,
        "seconds": result["seconds"], "scores": result["scores"],
        "first_capture_seconds": first_capture,
        "first_capture_limit_seconds": cutoff,
        "capture_deadline_status": deadline_status,
        "termination_reason": result.get("termination_reason") if complete else "running",
        "capture_events": [event for event in result.get("flag_events", []) if event["kind"] == "capture"],
        "flag_pickups": {"red": log.count("took the BLUE flag"), "blue": log.count("took the RED flag")},
        "captures_in_samples": captures,
        "near_flag_capper_to_siege_transitions": len(diversions),
        "diversion_samples": diversions,
        "lane_counts": {ident: len(values) for ident, values in lanes.items()},
        "role_counts": {ident: len(values) for ident, values in roles.items()},
        "tactics": samples[-1].get("tactics", {}),
        "offense": samples[-1].get("offense", {}),
        "fixed_fire": samples[-1].get("fixed_fire", {}),
        "peak_horizontal_kmh": max((bot.get("movement", {}).get("peak_kmh", 0) for sample in samples for bot in sample["bots"]), default=0),
        "script_errors": log.count("SCRIPT ERROR"),
        "sampling_note": "Five-second samples can miss brief role or flag transitions; pickup totals come from the event log. Different runs are not a controlled statistical comparison.",
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("folder", type=Path)
    parser.add_argument("--output", type=Path)
    options = parser.parse_args()
    report = summarize(options.folder)
    content = json.dumps(report, indent=2) + "\n"
    if options.output:
        options.output.write_text(content)
    else:
        print(content, end="")
