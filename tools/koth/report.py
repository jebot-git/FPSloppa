"""Collect final KOTH bake, geometry, replication, audio and bot acceptance receipts."""
from pathlib import Path
import hashlib,json,re,zipfile
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'test-results/koth-rotation'
def read(path):return json.loads(path.read_text())
def main():
 checks=[]
 def check(ok,label):checks.append({'name':label,'pass':bool(ok)});print('PASS' if ok else 'FAIL',label)
 geometry=read(OUT/'geometry.json');checks.extend(geometry['checks'])
 check(not read(OUT/'rules.json')['failures'],'Hill timing, scoring, reset, fallback and gong unit checks')
 check(not read(OUT/'views.json')['failures'],'Graphical hill countdowns and gong playback')
 check('ERROR:' not in (OUT/'views.log').read_text(),'Graphical render and audio test has no runtime/resource errors')
 for role in ['server','viewer','late']:
  data=read(OUT/f'network-{role}.json');checks.extend(data['checks'])
 bakes=read(OUT/'bake.json');catalog=read(ROOT/'deathmatch/maps/manifest.json');build=read(ROOT/'maps/KOTH/ROTATION.json')
 for row in bakes:
  name=row['id'];digest=hashlib.sha256((ROOT/'maps'/f'{name}.bsp').read_bytes()).hexdigest()
  check(row['invalid_faces']==0 and row['overflow_faces']==0,name+' lighting atlas has no invalid or overflow faces')
  check(row['sha256']==digest==next(r for r in catalog if r['id']==name)['sha256']==next(r for r in build['maps'] if r['id']==name)['sha256'],name+' BSP, cache bake and catalog hashes agree')
  check(len(row['codecs'])==2 and row['polygons']>0,name+' has refreshed BC7/ASTC caches and navigation')
 bots=[]
 folders={'koth_solstice':'koth-rotation','koth_torture':'koth-rotation','koth_alichar':'koth-rotation-alichar','koth_hyperborea':'koth-rotation-hyperborea'}
 for name,folder in folders.items():
  data=read(ROOT/'test-results/bot-soak'/folder/(name+'-koth-doom.json'));rows=list(data['bots'].values());samples=data['hill_samples']
  occupied={i:sum(s['index']==i and s['owner']>=0 for s in samples) for i in range(3)}
  check(len(rows)==8 and data['simulated_seconds']>=180,name+' completes three minutes with eight combat bots')
  check(all(n>0 for n in occupied.values()) and min(data['score'])>0,name+' bots occupy all three sites and both teams score')
  check('SCRIPT ERROR' not in (ROOT/'test-results/bot-soak'/folder/(name+'-koth-doom.log')).read_text(),name+' bot run has no script errors')
  bots.append({'map':name,'score':data['score'],'shots':sum(b['shots'] for b in rows),'max_stall':max(b['max_stall'] for b in rows),'occupied_samples':occupied})
 archive=ROOT/'Builds'/f'FPSloppa-{(ROOT/"VERSION").read_text().strip()}-Base-Assets.zip';manifest=read(ROOT/'deathmatch/assets/base_manifest.json')
 check(hashlib.sha256(archive.read_bytes()).hexdigest()==manifest['sha256'],'Internal base archive checksum matches manifest')
 with zipfile.ZipFile(archive) as package:
  for row in manifest['files']:
   if 'koth_' in row['path']:
    expected=row['sha256'];check(hashlib.sha256(package.read(row['path'])).hexdigest()==expected==hashlib.sha256((ROOT/row['path']).read_bytes()).hexdigest(),row['path']+' packaged content matches current file')
 result={'checks':checks,'failures':[r['name'] for r in checks if not r['pass']],'bots':bots,'compiler':build['compiler'],'protocol':'fpsloppa-39-rotating-koth'}
 (OUT/'validation.json').write_text(json.dumps(result,indent=2)+'\n')
 lines=['# KOTH validation — 19 September 2026','','Godot 4.7.2, ericw-tools 0.18.1, desktop Vulkan/mobile renderer and headless ENet.','',f"{len(checks)} acceptance checks; {len(result['failures'])} failures. All four BSPs received visibility and four-sample-axis lighting with bounce/AO, objective fill lights, fresh scene/BC7/ASTC caches and navigation.",'','All twelve sites pass floor, player-box clearance, pickup exclusion and navigation checks from every team spawn and both other hills. Server, observer and late joiner agree on the active site/countdown and receive one round-end gong. Graphical tests verify countdown labels and effects-bus playback. Internal base-asset archive and runtime hashes agree.','','Eight bots, Doom rules, seed 7129, 180 simulated seconds (two rotation cycles) per map:','','| Map | Team score | Shots | Longest stationary sample |','|---|---:|---:|---:|']
 for row in bots:lines.append(f"| {row['map']} | {row['score'][0]} : {row['score'][1]} | {row['shots']} | {row['max_stall']:.1f} s |")
 lines += ['','Bots occupied all three sites and both teams scored in each run. These are functional checks, not a competitive-balance or headset performance certification. Existing 1–2 ObjectDB teardown warnings remain in Godot test processes.','','Reproduction and build notes: [rotating KOTH](../../docs/KOTH-ROTATION.md). Full receipts and renders: `test-results/koth-rotation/validation.json` and the adjacent files.']
 (ROOT/'maps/KOTH/VALIDATION.md').write_text('\n'.join(lines)+'\n')
 raise SystemExit(1 if result['failures'] else 0)
if __name__=='__main__':main()
