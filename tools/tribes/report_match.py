#!/usr/bin/env python3
"""Summarize a recorded ST bot match; sampled transitions are not event totals."""
import argparse
import json
from pathlib import Path
import re
from math import dist
from collections import Counter, defaultdict
from statistics import median, quantiles


def vector(text):
    return tuple(map(float, re.findall(r"-?\d+(?:\.\d+)?(?:e[+-]?\d+)?", text)))


def combat_metrics(folder):
    path = folder / 'combat.jsonl'
    if not path.exists():
        return {'recorded': False}
    damage, deaths, fatal_events = Counter(), Counter(), []
    for line in path.read_text().splitlines():
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            continue  # A running writer may not yet have flushed its last line.
        if not row.get('victim', {}).get('carrier'):
            continue
        hit = row['data']
        damage[hit['weapon']] += hit['damage']
        if hit.get('fatal'):
            deaths[hit['weapon']] += 1
            fatal_events.append(row)
    return dict(recorded=True, carrier_damage_by_weapon=dict(damage),
                carrier_deaths_by_weapon=dict(deaths), fatal_carrier_events=fatal_events)


def travel_metrics(samples, events, bases=None):
    phases, packs = Counter(), Counter()
    speeds, previous = [], {}
    by_phase = defaultdict(list)
    no_progress, watches = [], {}
    near_flag_seconds = 0.0
    for sample in samples:
        now = sample.get('seconds', sample.get('clock', 0))
        for bot in sample['bots']:
            ident = bot['id']
            attacking = bot.get('goal') in ('st:flag', 'st:capture') and not bot.get('dead', False)
            old = previous.get(ident)
            if attacking:
                if 'velocity' in bot:
                    velocity = vector(bot['velocity'])
                    speed = (velocity[0] ** 2 + velocity[2] ** 2) ** .5 * 3.6
                else:
                    speed = bot.get('speed_kmh', 0)  # Five-second live snapshots.
                speeds.append(speed)
                by_phase[bot['goal'] + '/' + bot.get('phase', '')].append(speed)
                elapsed = min(6, now - old[0]) if old and old[1].get('serial') == bot.get('serial') else 0
                phases[bot.get('phase', '')] += elapsed
                packs[bot.get('pack', '')] += elapsed
                distance = bot.get('distance')
                if distance is None:
                    distance = dist(vector(bot['position']), vector(bot['target']))
                if bot['goal'] == 'st:flag' and distance < 100:
                    near_flag_seconds += elapsed
                key = (ident, bot.get('serial'), bot['goal'])
                watch = watches.get(key)
                if watch is None or distance < watch[1] - 5 or distance < 8:
                    watches[key] = (now, distance)
                elif now - watch[0] >= 35:
                    no_progress.append(dict(id=ident, seconds=now, distance=distance,
                                            phase=bot.get('phase', '')))
                    watches[key] = (now, distance)
            else:
                for key in [key for key in watches if key[0] == ident]:
                    del watches[key]
            previous[ident] = (now, bot)
    carries = []
    for index, event in enumerate(events):
        if event['kind'] != 'pickup':
            continue
        end = next((row for row in events[index + 1:]
                    if row['carrier'] == event['carrier'] and row['flag_team'] == event['flag_team']
                    and row['kind'] in ('drop', 'release', 'capture')), None)
        captured = end is not None and any(row['kind'] == 'capture' and row['carrier'] == event['carrier']
                                          and abs(row['seconds'] - end['seconds']) < .001 for row in events)
        velocity = vector(event['velocity'])
        row = dict(carrier=event['carrier'], flag_team=event['flag_team'], pickup_seconds=event['seconds'],
                   hp_at_pickup=event['hp'], energy_at_pickup=event['energy'], pack=event.get('pack'),
                   pickup_horizontal_kmh=(velocity[0] ** 2 + velocity[2] ** 2) ** .5 * 3.6,
                   outcome='capture' if captured else 'dropped' if end else 'in_progress')
        if bases:
            home = bases[1 - event['flag_team']]
            origin = vector(event['position'])
            direction = (home[0] - origin[0], home[2] - origin[2])
            length = (direction[0] ** 2 + direction[1] ** 2) ** .5
            row['homeward_pickup_kmh'] = ((velocity[0] * direction[0] + velocity[2] * direction[1])
                                             / max(.001, length) * 3.6)
            if end:
                row['home_progress_m'] = dist(origin, home) - dist(vector(end['position']), home)
        if end:
            row.update(carry_seconds=end['seconds'] - event['seconds'], hp_at_end=end.get('hp'),
                       displacement_m=dist(vector(event['position']), vector(end['position'])),
                       living_drop=end['kind'] == 'drop' and end.get('hp', 0) > 0)
        carries.append(row)
    return dict(travel_median_kmh=median(speeds) if speeds else 0,
                travel_p90_kmh=quantiles(speeds, n=10, method='inclusive')[8] if len(speeds) > 1 else 0,
                travel_by_goal_phase={key: dict(samples=len(values), median_kmh=median(values),
                    p90_kmh=quantiles(values, n=10, method='inclusive')[8] if len(values) > 1 else values[0],
                    fraction_above_90_kmh=sum(value > 90 for value in values) / len(values))
                    for key, values in sorted(by_phase.items())},
                attacking_phase_seconds=dict(phases), attacking_pack_seconds=dict(packs),
                enemy_flag_100m_exposure_seconds=near_flag_seconds,
                no_5m_objective_progress_in_35s=no_progress, carries=carries)


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
    events = result.get('flag_events', [])
    if not events and (folder / 'flag-events.json').exists():
        events = json.loads((folder / 'flag-events.json').read_text())
    travel = json.loads((folder / 'travel.json').read_text()) if (folder / 'travel.json').exists() else samples
    home_sample = next((sample for sample in samples if len(sample.get('flags', [])) == 2
                        and all(not flag['carrier'] and not flag['dropped'] for flag in sample['flags'])), None)
    bases = [vector(flag['position']) for flag in home_sample['flags']] if home_sample else None
    return {
        "folder": str(folder), "complete": complete,
        "seconds": result["seconds"], "scores": result["scores"],
        "first_capture_seconds": first_capture,
        "first_capture_limit_seconds": cutoff,
        "capture_deadline_status": deadline_status,
        "termination_reason": result.get("termination_reason") if complete else "running",
        "post_capture_activity": {key: result.get(key) for key in ('last_capture_seconds', 'last_pickup_seconds', 'waiting_for_pickup', 'post_capture_pickup_limit_seconds')},
        "behaviour": travel_metrics(travel, events, bases),
        "combat": combat_metrics(folder),
        "capture_events": [event for event in events if event["kind"] == "capture"],
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
        "sampling_note": "Five-second samples can miss brief role or flag transitions; pickup totals come from the event log. Travel metrics use one-second movement records when available, otherwise five-second snapshots. Different runs are not a controlled statistical comparison.",
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
