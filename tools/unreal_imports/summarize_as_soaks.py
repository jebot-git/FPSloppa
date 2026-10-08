from pathlib import Path
import json
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];rows=[]
for map in json.loads((HERE/'as-installed.json').read_text()):
 p=ROOT/'test-results/as-imports'/(map['id']+'-soak.json');d=json.loads(p.read_text())
 rows.append({'id':map['id'],'bsp_sha256':map['sha256'],'seconds':d['simulated_seconds'],'bots':len(d['bots']),'maximum_stage_observed':d['as_stage'],'shots':sum(d['weapons'].values()),'max_stall':max(r['max_stall'] for r in d['bots'].values()),'counts':d['counts'],'receipt':str(p.relative_to(ROOT))})
(HERE/'as-live-bots.json').write_text(json.dumps({'maps':rows,'note':'90-second combat smoke tests are separate from objective/routing acceptance. Low or zero stage progress is reported explicitly; these are not demonstrations of balanced full matches.'},indent=2)+'\n')
print([(r['id'],r['maximum_stage_observed'],r['shots']) for r in rows])
