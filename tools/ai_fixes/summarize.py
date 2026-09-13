"""Verify final evidence and retain compact, durable results outside test-results."""
from pathlib import Path
import hashlib
import json
import re
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'test-results/ai-fixes'
PROJECT = OUT / 'project-v1'


def read(path):
    return json.loads(path.read_text())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def vector(text):
    return [float(x) for x in text.strip('()').split(',')]


def match(path):
    d = read(path)
    b = d['balance']
    allowed = {0, 2, 11} if d['effective_rules'] == 'ut99' else {0, 1, 2}
    events = [e for e in d['events'] if any(w in e['text'] for w in
              [' is frozen', ' thawed', 'wins the freeze round'])]
    times = [0] + [e['time'] for e in events] + [d['simulated_seconds']]
    carriers = b['flag_carriers']
    return dict(case=path.stem, map=d['actual_map'], mode=d['case']['mode'],
                rules=d['effective_rules'], seed=d['case']['seed'], mirror=d['case']['mirror'],
                score=d['score'], seconds=d['simulated_seconds'], bots=len(d['bots']),
                deaths=len(b['death_equipment']),
                basic_deaths=sum(set(x['owned']) <= allowed for x in b['death_equipment']),
                weapon_pickups=sum(x['kind'] == 'weapon' for x in b['pickups']),
                flag_takes=len(carriers), captures=sum(c['ended'] == 'capture' for c in carriers),
                carrier_episodes=carriers, freezes=b['freezes'], thaws=b['thaws'],
                freeze_rounds=b['freeze_rounds'], last_freeze_event=events[-1] if events else None,
                max_freeze_event_gap=max(y-x for x, y in zip(times, times[1:])),
                max_sampled_y=max(vector(x['position'])[1] for t in d['traces'] for x in t['bots']),
                assault_progress=b['assault_progress'], attacker_water_seconds=b['attacker_water_seconds'])


def main():
    evidence = {}
    inputs = {}
    finals = []
    jobs = read(ROOT / 'tools/ai_fixes/final-jobs.json')
    for job in jobs:
        path = OUT / 'final' / (job['name'] + '.json')
        status_path = path.with_name(path.stem + '-status.json')
        status = read(status_path)
        assert status['passed'] and status['output_sha256'] == sha(path), path
        for name, digest in status['inputs'].items():
            assert sha(PROJECT / name) == digest, name
            assert name not in inputs or inputs[name] == digest, name
            inputs[name] = digest
        source = ROOT / 'tools/ai_fixes' / (job.get('script', 'match') + '.gd')
        assert sha(source) == status['script_sha256'], source
        evidence[str(path.relative_to(ROOT))] = sha(path)
        evidence[str(status_path.relative_to(ROOT))] = sha(status_path)
        if job.get('script') != 'water':
            row = match(path)
            assert row['bots'] == 8, row['case']
            if row['mode'] == 'ctf':assert row['captures'] == sum(row['score'])
            if row['mode'] == 'if':
                assert row['freeze_rounds'] == sum(row['score'])
                assert row['max_sampled_y'] < 25 and row['last_freeze_event']['time'] > 290
            if row['mode'] == 'as':
                assert row['assault_progress'][-1]['finished']
                assert row['assault_progress'][-1]['leg'] == 1
            else:assert abs(row['seconds'] - job['seconds']) < .05
            finals.append(row)
    assert len(finals) == 18
    water = read(OUT / 'final/water.json')
    assert len(water) == 4 and all(r['passed'] and r['water_seconds'] > 0 for r in water)
    water_summary = [{**{k: r[k] for k in ['route', 'control', 'passed', 'water_seconds']},
                      'seconds': sum(s['seconds'] for s in r['segments'])} for r in water]
    access, supplies = {}, {}
    for label, dest in [('final-access', access), ('final-supply', supplies)]:
        for status_path in sorted((OUT / label).glob('*-status.json')):
            status = read(status_path)
            path = status_path.with_name(status_path.name.replace('-status', ''))
            assert status['passed'] and sha(path) == status['output_sha256']
            evidence[str(path.relative_to(ROOT))] = sha(path)
            data = read(path)
            rows = data['rows']
            if label == 'final-access':
                assert all(r['passed'] for r in rows)
                dest[data['map']] = [{k: r[k] for k in ['team', 'start', 'end', 'seconds', 'passed']} for r in rows]
            else:
                assert all(r['capsule_clear'] and r['detour_ratio'] > 0 for r in rows)
                dest[data['map']] = rows
    assert len(access) == len(supplies) == 4
    assert sum(map(len, access.values())) == 37
    assert sum(map(len, supplies.values())) == 224
    nav = {}
    for label in ['baseline', 'final']:
        path = OUT / ('traversal-' + label + '.json')
        evidence[str(path.relative_to(ROOT))] = sha(path)
        nav[label] = read(path)
    guided = [r for r in nav['final']['trials'] if r['forced_route']]
    assert len(guided) == 6 and all(0 < r['arrival_seconds'] < 16 for r in guided)
    regressions = read(ROOT / 'docs/validation/ai-balance-regressions.json')
    integration = read(ROOT / 'docs/validation/ai-balance-integration.json')
    assert len(regressions) == 11 and all(r['passed'] for r in regressions)
    assert len(integration) == 3 and all(r['passed'] for r in integration)
    geometry_path = OUT / 'project-nav/test-results/koth/geometry.json'
    geometry = read(geometry_path)
    assert not geometry['failures'] and len(geometry['maps']) == 4
    evidence[str(geometry_path.relative_to(ROOT))] = sha(geometry_path)
    for path in OUT.glob('regression-*.log'):
        evidence[str(path.relative_to(ROOT))] = sha(path)
    evidence['test-results/ai-fixes/koth-validation-final.log'] = sha(OUT / 'koth-validation-final.log')
    baseline = [match(p) for p in sorted((OUT / 'baseline').glob('koth_*-m?.json'))]
    baseline.append(match(OUT / 'baseline/if-trace.json'))
    for row in baseline:
        path = OUT / 'baseline' / (row['case'] + '.json')
        status = read(path.with_name(path.stem + '-status.json'))
        assert status['passed'] and status['output_sha256'] == sha(path)
        evidence[str(path.relative_to(ROOT))] = sha(path)
    owned = ['deathmatch/bots.gd', 'deathmatch/bot_ai/objectives.gd',
             'deathmatch/bot_ai/navigation.gd', 'deathmatch/movement/spawn_clearance.gd',
             'maps/navigation/qsrc_dm3.res']
    assets = ['maps/navigation/qsrc_dm3.res']
    for name in ['koth_solstice', 'koth_hyperborea']:
        assets += ['maps/' + name + '.bsp', 'maps/cache/' + name + '.scn',
                   'maps/cache/' + name + '-lightmap1.scn']
    for name in set(owned + [n for n in assets if not n.endswith('.scn')]):
        assert sha(ROOT / name) == sha(PROJECT / name), name
    integration_access = {}
    for status_path in sorted((OUT / 'integration-access').glob('*-status.json')):
        status = read(status_path)
        path = status_path.with_name(status_path.name.replace('-status', ''))
        assert status['passed'] and sha(path) == status['output_sha256']
        rows = read(path)['rows']
        assert all(r['passed'] for r in rows)
        integration_access[read(path)['map']] = len(rows)
        evidence[str(path.relative_to(ROOT))] = sha(path)
        evidence[str(status_path.relative_to(ROOT))] = sha(status_path)
    assert sum(integration_access.values()) == 37
    # Other threads changed connection handling and default TF state in arena.gd.
    # Verify the exact spawn function independently, without overwriting those edits.
    spawn = lambda p: re.search(r'^func _spawn\(.*?(?=^func |\Z)', p.read_text(), re.M | re.S).group()
    assert spawn(ROOT / 'deathmatch/arena.gd') == spawn(PROJECT / 'deathmatch/arena.gd')
    package = ROOT.parent / 'Builds/FPSloppa-0.10v-Base-Assets.zip'
    manifest = read(ROOT / 'deathmatch/assets/base_manifest.json')
    assert sha(package) == manifest['sha256']
    with zipfile.ZipFile(package) as archive:
        for name in assets:
            digest = hashlib.sha256(archive.read(name)).hexdigest()
            assert digest == sha(ROOT / name)
            assert digest == next(r['sha256'] for r in manifest['files'] if r['path'] == name)
    sys.path.insert(0, str(ROOT / 'tools/makkon'))
    from theme import lumps
    for name in ['koth_solstice', 'koth_hyperborea']:
        old = lumps((Path('/tmp/fpsloppa-ai-fixes-base/maps') / (name + '.bsp')).read_bytes())
        new = lumps((ROOT / 'maps' / (name + '.bsp')).read_bytes())
        assert old[0][1:] == new[0][1:] and old[1] == new[1]
    report = dict(complete=True, final_matches=finals,
                  simulated_match_minutes=sum(r['seconds'] for r in finals) / 60,
                  baseline_matches=baseline,
                  prior_ctf_baseline=[r for r in read(ROOT / 'docs/validation/ai-priority-balance.json')['matches'] if r['mode'] == 'ctf'],
                  water=water_summary, navigation=nav, koth_access=access,
                  koth_supplies=supplies, koth_geometry=geometry,
                  regressions=regressions, current_workspace_integration=integration,
                  current_workspace_koth_access=integration_access,
                  frozen_runtime_inputs=inputs, current_owned_inputs={n: sha(ROOT / n) for n in owned + assets},
                  frozen_match_cache_inputs={n: sha(PROJECT / n) for n in assets if n.endswith('.scn')},
                  current_spawn_function_sha256=hashlib.sha256(spawn(ROOT / 'deathmatch/arena.gd').encode()).hexdigest(),
                  package=dict(path=str(package), sha256=sha(package), verified_entries=assets, published=False),
                  raw_evidence_sha256=evidence,
                  limits=['Exploratory eight-bot local trials; no human win-rate, network or headset-performance inference.',
                          'Two CTF/IF seeds with swapped rosters; one KOTH seed with swapped rosters. Mirrors are paired, not independent samples.',
                          'The final match matrix was serial; other isolated diagnostics overlapped. Timing is not a performance benchmark.',
                          'Guided water/access tests exercise physical traversal without enemy fire; natural Assault matches did not select the water entrance.',
                          'Solstice side bias and low CTF capture throughput remain; no weapon damage, objective health or hill radius was changed.',
                          'The runtime was frozen for matches. Shared-workspace connection/TF-state and presentation-cache edits were preserved; spawn-function equality, three integration suites, and all 37 KOTH starts were checked separately against the current workspace.'])
    target = ROOT / 'docs/validation/ai-balance-fixes.json'
    target.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(dict(complete=True, matches=len(finals), minutes=report['simulated_match_minutes'],
                         ctf_takes=sum(r['flag_takes'] for r in finals), ctf_captures=sum(r['captures'] for r in finals),
                         koth_starts=37, weapon_routes=224, water_routes=4, guided_navigation=6)))


if __name__ == '__main__':
    main()
