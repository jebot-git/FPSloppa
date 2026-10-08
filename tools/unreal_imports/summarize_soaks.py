"""Summarize completed live bot runs without treating process success as objective success."""
from pathlib import Path
import json
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
rows=[]
for installed in json.loads((HERE/'installed.json').read_text()):
 name=installed['id'];runs=[]
 for p in sorted((ROOT/'test-results/koth-imports').glob(name+'*soak.json')):
  d=json.loads(p.read_text())
  runs.append({'receipt':str(p.relative_to(ROOT)),'seconds':d['simulated_seconds'],'score':d['score'],'shots':sum(d['weapons'].values()),'damage_events':d['counts'].get('damage',0),'max_stall':max(b['max_stall'] for b in d['bots'].values()),'hill_scoring_observed':sum(d['score'])>0})
 rows.append({'id':name,'runs':runs,'hill_scoring_observed':any(r['hill_scoring_observed'] for r in runs)})
report={'maps':rows,'note':'Route connectivity and live combat are separate checks. A completed soak with zero scores does not establish objective-play quality.'}
(HERE/'live-bots.json').write_text(json.dumps(report,indent=2)+'\n')
print([(r['id'],r['hill_scoring_observed']) for r in rows])
