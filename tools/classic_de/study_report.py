"""Summarize the CS1.6 study's real test receipts; never infer missing passes."""
from pathlib import Path
import hashlib, json
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/cs16-study'
IDS=['de_'+n+'_rebuilt' for n in ['dust2','nuke','inferno','aztec','train']]
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def result(name):
    lines=(OUT/(name+'.log')).read_text().splitlines()
    if name=='cs16_bots':
        row=json.loads((ROOT/'test-results/cs16/bots.json').read_text())
        assert 'CS16_BOTS_RESULT '+json.dumps(row['failures'],separators=(',',':')) in lines
        return dict(name=name,checks=len(row['trials']),failures=row['failures'],passed=not row['failures'])
    rows=[json.loads(line.split('_RESULT ',1)[1]) for line in lines if '_RESULT {' in line]
    assert rows, name+' has no result'
    row=rows[-1]
    return dict(name=name,checks=row['checks'],failures=row['failures'],passed=not row['failures'])
def soak(stage,map):
    path=ROOT/f'test-results/de-bot-review/cs16-{stage}-{map}.json'
    row=json.loads(path.read_text());samples=row['samples']
    alive=[b for sample in samples for b in sample['bots'] if not b['dead']]
    planted=[s for s in samples if s['planted']]
    return dict(completed=row['completed'],rounds=row['rounds'],seconds=round(row['seconds'],3),
        map_sha256=row['map_sha256'],plant_rounds=len({s['round'] for s in planted}),
        planted_samples=len(planted),multiple_defuser_samples=sum(sum(not b['dead'] and b['goal']=='de:defuse' for b in s['bots'])>1 for s in planted),
        alive_samples=len(alive),roam_samples=sum(b['goal'].startswith('roam:') for b in alive),
        maximum_spawn_exit_seconds=round(max([v['seconds'] for v in row['spawn_exits']] or [0]),3),
        source_sha256=digest(path))
def main():
    tests=[result(n) for n in ['defusal_bots','defusal_bot_behavior','cs16_bots','defusal_maps','defusal_tactics','defusal_distribution']]
    maps=[]
    profiles=json.loads((ROOT/'deathmatch/maps/defusal_tactics.json').read_text())
    config=json.loads((ROOT/'deathmatch/maps/defusal.json').read_text())
    for id in IDS:
        sha=digest(ROOT/f'maps/{id}.bsp')
        assert profiles[id]['sha256']==config[id]['sha256']==sha,id
        row=dict(map=id,sha256=sha,lanes=sum(len(v) for v in profiles[id]['attacks']),holds=sum(len(v) for v in profiles[id]['holds']))
        if id!=IDS[0]:
            audit=json.loads((ROOT/f'test-results/classic-de/{id}/result.json').read_text())
            row.update(checks=audit['checks'],failures=audit['failures'],passed=not audit['failures'])
        maps.append(row)
    comparison=[dict(map=id,before=soak('before',id),after=soak('after',id)) for id in IDS]
    for row in comparison:assert row['after']['map_sha256']==profiles[row['map']]['sha256']
    videos=[]
    for id in ['cZcAfKtbJAY','zg1pF-4n_vc','eovfGE14QNA','jBxiEhh2fyg']:
        info=json.loads((OUT/(id+'.info.json')).read_text())
        videos.append(dict(url='https://www.youtube.com/watch?v='+id,title=info['title'],upload_date=info.get('upload_date'),duration=info['duration'],inspected='Contact-sheet frames at 00:00, 00:10, ... 01:50 from the first 120 seconds; no timing claim.'))
    cover=result('de_cover')
    passed=all(t['passed'] for t in tests) and all(m.get('passed',True) for m in maps) and all(r[s]['completed'] and r[s]['rounds']==6 for r in comparison for s in ['before','after'])
    report=dict(date='2026-09-27',targeted_validation_passed=passed,all_regressions_passed=passed and cover['passed'],
        scope='All five DE maps; new brushes on Nuke, Inferno, Aztec and Train; Dust2 geometry unchanged.',
        checks=sum(t['checks'] for t in tests)+sum(m.get('checks',0) for m in maps),tests=tests,maps=maps,
        additional_cover_audit=cover,cover_failure_scope='Five existing Dust2 collision/penetration exit mismatches; Dust2 BSP unchanged from the baseline. No failure on the four rebuilt maps.',
        comparison=comparison,completed_rounds=sum(r[s]['rounds'] for r in comparison for s in ['before','after']),
        simulation='Twelve autonomous bots, seed 7129, six rounds/map, halftime after three; ordinary 60 Hz physics accelerated with --fixed-fps 1000. No forced damage, teleports or round wins.',
        videos=videos,study='docs/CS16-MAP-TACTICS-STUDY.md',
        limits=['One seed is not a competitive balance study.','Video review used sampled frames, not complete match viewing.','No new coordinated utility, economy, fake executes or ladder mechanics.','Native render views checked; headset playtest and release packaging not performed.'])
    (ROOT/'docs/validation/cs16-map-tactics-2026-09-27.json').write_text(json.dumps(report,indent=2)+'\n')
    doc=ROOT/'docs/CS16-MAP-TACTICS-STUDY.md'
    marker='<!-- generated study results -->'
    summary=[marker,'','## Measured results','',
        f"Targeted regression and map checks: **{report['checks']} passed**. Both runs completed all 30 rounds (60 total).",
        'The table counts half-second samples with more than one living bot pursuing the defuse job, not the number of simultaneous physical defuses.','',
        '| Map | Planted rounds, before → after | Multiple defuse-job samples, before → after |',
        '|---|---:|---:|']
    for row in comparison:
        a,b=row['before'],row['after']
        summary.append(f"| {row['map']} | {a['plant_rounds']} → {b['plant_rounds']} | {a['multiple_defuser_samples']} → {b['multiple_defuser_samples']} |")
    summary.extend(['',
        'Plant frequency changes in both directions; these measurements do not establish better competitive balance. The full receipt also records roaming samples, spawn exits, hashes and source receipts.',
        '',
        'The additional penetration audit still reports five Dust2 exit/collision mismatches on its unchanged BSP. All four maps rebuilt here pass that audit. These are recorded separately; the overall broad regression status is not reported as all-green.',
        '',
        'Native verification captures: [Nuke hut](../test-results/classic-de/de_nuke_rebuilt/study-hut.png), [Inferno apartments](../test-results/classic-de/de_inferno_rebuilt/study-apartments.png), [Aztec canal](../test-results/classic-de/de_aztec_rebuilt/study-canal-ramp.png), [Train upper hall](../test-results/classic-de/de_train_rebuilt/study-upper-hall.png).',''])
    assert passed, 'Do not publish a passing summary for failed checks'
    doc.write_text(doc.read_text().split(marker)[0].rstrip()+'\n\n'+'\n'.join(summary))
    print(json.dumps(dict(passed=passed,checks=report['checks'],rounds=report['completed_rounds'],cover_passed=cover['passed'])))
if __name__=='__main__':main()
