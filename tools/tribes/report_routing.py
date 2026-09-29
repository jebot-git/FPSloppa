#!/usr/bin/env python3
"""Compare completed headless routing runs; do not hide cutoff outcomes."""
import argparse
from collections import Counter, defaultdict
import json
import math
from pathlib import Path
import re
from statistics import mean, median
from report_match import travel_metrics

TRAVEL = {'st:flag', 'st:capture', 'st:intercept', 'st:return', 'st:hold'}
SCHEMA = 5
ENDINGS = {'match_finished', 'duration_reached', 'no_capture_600s', 'no_pickup_after_capture_600s'}


def completed(row):
    return (row.get('teams') == [8, 8] and row['exit_code'] in (0, 2)
            and not row['timed_out'] and not row['script_errors']
            and row.get('termination_reason') in ENDINGS and 'captures' in row)


def vector(value):
    if isinstance(value, str):
        return tuple(map(float, re.findall(r'-?\d+(?:\.\d+)?(?:e[+-]?\d+)?', value)))
    return value


def json_lines(path):
    for line in path.read_text().splitlines():
        try:
            yield json.loads(line)
        except json.JSONDecodeError:
            continue  # A running writer can have an unfinished final line.


def describe(values):
    values = sorted(values)
    if not values:
        return dict(n=0)
    return dict(n=len(values), mean=mean(values), median=median(values),
                p90=values[min(len(values)-1, int(len(values)*.9))])


def analyze(folder):
    completion = json.loads((folder / 'completion.json').read_text())
    completion['analysis_schema'] = SCHEMA
    if not (folder / 'result.json').exists():
        return completion
    result = json.loads((folder / 'result.json').read_text())
    phases, speeds, stalls, locations = Counter(), [], [], Counter()
    carrier_speeds, carrier_metres, carrier_progress = [], 0., 0.
    by_phase, by_class, previous, windows = defaultdict(list), defaultdict(list), {}, {}
    travelled, net_progress, reversals = 0., 0., 0
    trace = folder / 'navigation.jsonl'
    if trace.exists():
        for row in json_lines(trace):
            ident, serial = row['id'], row['serial']
            position, goal = vector(row['position']), vector(row['target'])
            active = row['goal'] in TRAVEL and math.dist(position, goal) > 8
            old = previous.get(ident)
            previous[ident] = row
            if not active:
                windows.pop(ident, None)
                continue
            speed = row['speed_kmh']
            speeds.append(speed); by_phase[row['phase']].append(speed); by_class[row['class']].append(speed)
            if row['goal'] == 'st:capture':
                carrier_speeds.append(speed)
            if old and old['serial'] == serial and 0 < row['seconds']-old['seconds'] < 2:
                dt = row['seconds']-old['seconds']
                phases[row['phase']] += dt
                if old['goal'] == row['goal'] and math.dist(vector(old['target']), goal) < 3:
                    metres = math.dist(vector(old['position']), position)
                    progress = math.dist(vector(old['position']), goal)-math.dist(position, goal)
                    travelled += metres
                    net_progress += progress
                    if row['goal'] == 'st:capture':
                        carrier_metres += metres
                        carrier_progress += progress
                if speed < 7.2:
                    locations[(round(position[0]/16)*16, round(position[2]/16)*16)] += dt
                velocity, old_velocity = vector(row['velocity']), vector(old['velocity'])
                lengths = math.hypot(velocity[0], velocity[2])*math.hypot(old_velocity[0], old_velocity[2])
                if lengths > 64 and (velocity[0]*old_velocity[0]+velocity[2]*old_velocity[2])/lengths < -.5:
                    reversals += 1
            window = windows.get(ident)
            if not window or window['serial'] != serial or math.dist(window['position'], position) > 3 or speed > 7.2:
                if window and window['serial'] == serial and old and row['seconds']-old['seconds'] < 2 and row['seconds']-window['at'] >= 5:
                    stalls.append(dict(id=ident, seconds=row['seconds']-window['at'], start=window['at'],
                                       position=window['position'], phase=window['phase'], goal=window['goal']))
                windows[ident] = dict(at=row['seconds'], position=position, serial=serial, phase=row['phase'], goal=row['goal'])
    departures, losses = [], []
    events = folder / 'navigation-events.jsonl'
    if events.exists():
        last = {}
        for row in json_lines(events):
            if row['kind'] == 'abrupt_speed_loss':
                losses.append(row)
            elif row['seconds']-last.get((row['id'], row['serial']), -100) > .5:
                departures.append(row); last[row['id'], row['serial']] = row['seconds']
    flag_events = result.get('flag_events', [])
    home = next((sample for sample in result['samples'] if len(sample.get('flags', [])) == 2
                 and all(not flag['carrier'] and not flag['dropped'] for flag in sample['flags'])), None)
    bases = [vector(flag['position']) for flag in home['flags']] if home else None
    # Use the same one-second analysis as the recorded live matches.
    live = travel_metrics(json.loads((folder / 'travel.json').read_text()), flag_events, bases)
    completion.update(dict(pickups=sum(e['kind'] == 'pickup' for e in flag_events), captures=sum(result['scores']),
                           recorded_match_metrics=dict(travel_median_kmh=live['travel_median_kmh'], travel_p90_kmh=live['travel_p90_kmh'],
                               no_progress_35s=len(live['no_5m_objective_progress_in_35s']),
                               pickup_speed_kmh=describe([r['pickup_horizontal_kmh'] for r in live['carries']]),
                               pickup_homeward_kmh=describe([r['homeward_pickup_kmh'] for r in live['carries'] if 'homeward_pickup_kmh' in r])),
                           travel_speed_kmh=describe(speeds), phase_seconds=dict(phases),
                           carrier_speed_kmh=describe(carrier_speeds),
                           carrier_slow_fraction=sum(s < 7.2 for s in carrier_speeds)/max(1,len(carrier_speeds)),
                           carrier_metres=carrier_metres, carrier_net_progress_metres=carrier_progress,
                           phase_speed_kmh={k: describe(v) for k, v in by_phase.items()}, class_speed_kmh={k: describe(v) for k, v in by_class.items()},
                           slow_episodes=stalls, slow_episode_seconds=sum(s['seconds'] for s in stalls),
                           travel_metres=travelled, net_goal_progress_metres=net_progress,
                           reversal_samples=reversals, abrupt_speed_losses=len(losses),
                           departure_speed_kmh=describe([r['entry_kmh'] for r in departures]),
                           ski_departures=sum(r['ski_approach'] for r in departures),
                           fast_ski_departures=sum(r['ski_approach'] and r['entry_kmh'] > 50 for r in departures),
                           slow_hotspots=[dict(x=x, z=z, seconds=n) for (x, z), n in locations.most_common(12)],
                           tactics=result.get('samples', [{}])[-1].get('tactics', {}),
                           metrics=json.loads((folder / 'navigation-summary.json').read_text())))
    return completion


def aggregate(rows):
    valid = [r for r in rows if completed(r)]
    duration = sum(r['seconds'] for r in valid)
    travel_seconds = sum(r['metrics']['travel_seconds'] for r in valid)
    return dict(runs=len(rows), valid_8v8=len(valid),
                normal_endings=sum(r['termination_reason'] in ('match_finished', 'duration_reached') for r in valid),
                cutoffs=dict(Counter(r['termination_reason'] for r in valid if r['termination_reason'] not in ('match_finished', 'duration_reached'))),
                with_capture=sum(r['captures'] > 0 for r in valid), captures=sum(r['captures'] for r in valid),
                game_seconds=duration, captures_per_20_minutes=sum(r['captures'] for r in valid)*1200/max(1,duration),
                pickups=sum(r['pickups'] for r in valid), first_capture_seconds=describe([r['first_capture_seconds'] for r in valid if r['first_capture_seconds'] >= 0]),
                per_run_median_travel_kmh=describe([r['travel_speed_kmh']['median'] for r in valid if r['travel_speed_kmh']['n']]),
                per_run_carrier_median_kmh=describe([r['carrier_speed_kmh']['median'] for r in valid if r['carrier_speed_kmh']['n']]),
                per_run_carrier_slow_fraction=describe([r['carrier_slow_fraction'] for r in valid if r['carrier_speed_kmh']['n']]),
                carrier_net_progress_per_metre=sum(r['carrier_net_progress_metres'] for r in valid)/max(1,sum(r['carrier_metres'] for r in valid)),
                per_run_attacking_median_kmh=describe([r['recorded_match_metrics']['travel_median_kmh'] for r in valid]),
                per_run_attacking_p90_kmh=describe([r['recorded_match_metrics']['travel_p90_kmh'] for r in valid]),
                no_progress_35s_per_game_minute=sum(r['recorded_match_metrics']['no_progress_35s'] for r in valid)*60/max(1,duration),
                per_run_pickup_homeward_kmh=describe([r['recorded_match_metrics']['pickup_homeward_kmh']['median'] for r in valid if r['recorded_match_metrics']['pickup_homeward_kmh']['n']]),
                slow_travel_fraction=sum(r['metrics']['slow_seconds'] for r in valid)/max(1,travel_seconds),
                downhill_ski_fraction=sum(r['metrics']['down_ski_seconds'] for r in valid)/max(1,sum(r['metrics']['ground_down_seconds'] for r in valid)),
                uphill_walk_or_jet_fraction=sum(r['metrics']['up_walk_or_jet_seconds'] for r in valid)/max(1,sum(r['metrics']['ground_up_seconds'] for r in valid)),
                abrupt_losses_per_travel_minute=sum(r['abrupt_speed_losses'] for r in valid)*60/max(1,travel_seconds),
                failed_launches_per_game_minute=sum(r['tactics'].get('failed_launches',0) for r in valid)*60/max(1,duration),
                recoveries_per_game_minute=sum(r['tactics'].get('progress_recoveries',0) for r in valid)*60/max(1,duration),
                rolling_launches=sum(r['tactics'].get('rolling_launches',0) for r in valid),
                fast_ski_departures=sum(r['fast_ski_departures'] for r in valid),
                fast_ski_departures_per_travel_minute=sum(r['fast_ski_departures'] for r in valid)*60/max(1,travel_seconds),
                per_run_class_median_kmh={name: describe([r['class_speed_kmh'][name]['median'] for r in valid if name in r['class_speed_kmh']]) for name in sorted({name for r in valid for name in r['class_speed_kmh']})},
                per_run_phase_median_kmh={name: describe([r['phase_speed_kmh'][name]['median'] for r in valid if name in r['phase_speed_kmh']]) for name in sorted({name for r in valid for name in r['phase_speed_kmh']})},
                per_run_median_departure_kmh=describe([r['departure_speed_kmh']['median'] for r in valid if r['departure_speed_kmh']['n']]))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folders', nargs='+', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    report = dict(note='Completed normal server simulations only. Cutoffs are retained. Paired seeds reduce variance but asynchronous engine work can prevent bitwise determinism. Contact departures are debounced by 0.5 seconds and are not all sustained flights.', batches={})
    for folder in args.folders:
        rows = []
        for path in sorted(folder.glob('*/completion.json')):
            artifact = path.parent / 'routing-analysis.json'
            row = json.loads(artifact.read_text()) if artifact.exists() else {}
            if row.get('analysis_schema') != SCHEMA:
                row = analyze(path.parent)
                artifact.write_text(json.dumps(row, indent=2)+'\n')
            rows.append(row)
        report['batches'][folder.name] = dict(maps={name: aggregate([r for r in rows if r['map'] == name]) for name in sorted({r['map'] for r in rows})}, runs=rows)
    if len(args.folders) == 2:
        first, second = [report['batches'][folder.name]['runs'] for folder in args.folders]
        baseline = {(r['map'], r['seed']): r for r in first if completed(r)}
        pairs = [(baseline[r['map'], r['seed']], r) for r in second if (r['map'], r['seed']) in baseline and completed(r)]
        report['paired'] = {}
        for name in sorted({b['map'] for a,b in pairs}):
            subset = [(a,b) for a,b in pairs if b['map'] == name]
            report['paired'][name] = dict(pairs=len(subset),
                capture_count_wins=sum(b['captures']>a['captures'] for a,b in subset),
                capture_count_losses=sum(b['captures']<a['captures'] for a,b in subset),
                capture_count_ties=sum(b['captures']==a['captures'] for a,b in subset),
                median_travel_kmh_delta=describe([b['travel_speed_kmh']['median']-a['travel_speed_kmh']['median'] for a,b in subset]),
                recovery_rate_delta=describe([(b['tactics'].get('progress_recoveries',0)/b['seconds']-a['tactics'].get('progress_recoveries',0)/a['seconds'])*60 for a,b in subset]))
    args.output.write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({k: v['maps'] for k,v in report['batches'].items()}, indent=2))


if __name__ == '__main__':
    main()
