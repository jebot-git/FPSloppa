"""Sequential, bounded CC bot comparisons; same seed, normal combat and physics."""
from pathlib import Path
import argparse,subprocess,json,os,time
ROOT=Path(__file__).resolve().parents[2]
def main():
 p=argparse.ArgumentParser();p.add_argument('--phase',choices=['before','after'],required=True);p.add_argument('--seconds',type=int,default=180);a=p.parse_args();out=ROOT/'test-results/cc'/a.phase;out.mkdir(exist_ok=True);results=[]
 for source,dest in [('lqdm3','cc_hyperborea'),('lqdm4','cc_psychofuge'),('lqdm6','cc_ghostquarter'),('lqdm7','cc_basement')]:
  id=source if a.phase=='before' else dest;result=out/(id+'.json');options={'map':id,'mode':'cc','rules':'doom','seconds':a.seconds,'seed':7129,'profile_tick':True,'output':str(result)}
  with (out/(id+'.log')).open('w') as f:
   began=time.monotonic();r=subprocess.run(['godot','--headless','--xr-mode','off','--fixed-fps','60','--path',str(ROOT),'--script','res://deathmatch/tests/bot_soak.gd','--',json.dumps(options)],env={**os.environ,'XDG_DATA_HOME':'/tmp/fpsloppa-cc-bench'},stdout=f,stderr=subprocess.STDOUT,timeout=360)
  errors=[l for l in (out/(id+'.log')).read_text().splitlines() if l.startswith(('ERROR:','SCRIPT ERROR:'))];assert r.returncode==0 and not errors,(id,r.returncode,errors)
  d=json.loads(result.read_text());bots=list(d['bots'].values());events=d['events'];row={'id':id,'seconds':d['simulated_seconds'],'wall_seconds':round(time.monotonic()-began,2),'chainsaw_kills':sum('CHAINSAW' in e['text'] for e in events),'hunger_deaths':sum('CIRCUS HUNGER' in e['text'] for e in events),'first_combat_kill':next((e['time'] for e in events if 'CHAINSAW' in e['text']),None),'damage':d['damage'],'max_stall':max(b['max_stall'] for b in bots),'stationary_pct':100*sum(b['stationary_seconds'] for b in bots)/max(1,sum(b['active_seconds'] for b in bots)),'tick_p50_ms':d['physics_p50_ms'],'tick_p95_ms':d['physics_p95_ms']};results.append(row);(out/'summary.json').write_text(json.dumps(results,indent=2)+'\n');print(json.dumps(row),flush=True)
if __name__=='__main__':main()
