"""Remove RCMD Q2/Q3/Quetoo adaptations from local distribution; retain source work."""
from pathlib import Path
import json,shutil
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
rows=json.loads((HERE/'conversions.json').read_text());retired=[r for r in rows if r['collection'] in ['rcmd_quake2','rcmd_quake3','rcmd_q2w']]
if not retired:raise SystemExit('RCMD adaptations already removed')
ids={r['id'] for r in retired};archive=HERE/'local/retired-adaptations';archive.mkdir(parents=True,exist_ok=True)
(archive/'conversions.json').write_text(json.dumps(retired,indent=2)+'\n')
for row in retired:
 name=row['id'];files=set()
 for base in ['maps','maps/cache','maps/navigation','maps/ArenaImports','test-results/arena-gallery','test-results/arena-imports','test-results/rcmd-textures']:
  files.update((ROOT/base).glob(name+'*'))
 files.update((ROOT/'maps/cache').glob(row['sha256']+'*'))
 for p in sorted(files):
  if not p.exists():continue
  dest=archive/p.relative_to(ROOT);dest.parent.mkdir(parents=True,exist_ok=True)
  if dest.exists():raise RuntimeError('Archive destination exists: '+str(dest))
  shutil.move(str(p),str(dest))
(HERE/'conversions.json').write_text(json.dumps([r for r in rows if r['id'] not in ids],indent=2)+'\n')
p=ROOT/'deathmatch/maps/manifest.json';p.write_text(json.dumps([r for r in json.loads(p.read_text()) if r['id'] not in ids],indent=2)+'\n')
for p in (ROOT/'maps').glob('*maplist.txt'):
 p.write_text('\n'.join(line for line in p.read_text().splitlines() if line.strip() not in ids)+'\n')
for filename in ['preparation.json','texture-validation.json','runtime-fixes.json','live-bots.json']:
 p=HERE/filename
 if not p.exists():continue
 data=json.loads(p.read_text())
 if isinstance(data,list):p.write_text(json.dumps([r for r in data if r.get('id',r.get('map')) not in ids],indent=2)+'\n')
plan=ROOT/'test-results/arena-gallery/plan.json';plan.write_text(json.dumps([r for r in json.loads(plan.read_text()) if r['id'] not in ids],indent=2)+'\n')
(HERE/'distribution-policy.json').write_text(json.dumps({'rcmd':'Native Quake BSP maps only; source adaptations excluded by user request','excluded_ids':sorted(ids),'retained_rcmd':[r['id'] for r in rows if r['collection']=='rcmd_quake1']},indent=2)+'\n')
print('Removed',len(ids),'adaptations; kept',len(rows)-len(ids),'classic arenas')
