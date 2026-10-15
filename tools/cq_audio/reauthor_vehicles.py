"""Author Battle at Sea vehicle fire and explosions through Audacity MCP.
Run with mcp + numpy, ffmpeg, Audacity and mod-script-pipe. --build reencodes masters.
Pixabay sources are supplied by the user in the ignored cache; see source manifest.
"""
import asyncio,json,hashlib,sys
from pathlib import Path
import numpy as np
import reauthor_weapons as shared
ROOT=shared.ROOT;BASE=shared.BASE;RATE=shared.RATE
WORK=shared.CACHE/'vehicle';DOC=ROOT/'docs/audio/cq-vehicles-20261015'
JOBS={
 'rocket_tank_launch':dict(high=100,low=10500,peak=.62,layers=[('katyusha',.32,.28,1,1),('sea_cannon_fire_1',0,.13,1.2,.12)]),
 'rocket_tank_travel':dict(high=130,low=9000,peak=.42,layers=[('rocket_travel',.12,1.55,1,1)]),
 'tank_light_fire':dict(high=65,low=10500,peak=.72,layers=[('sea_cannon_fire_1',0,.95,1.12,1),('sea_cannon_hit_cannon_1',0,.3,1.15,.18)]),
 'tank_heavy_fire':dict(high=45,low=9500,peak=.76,layers=[('sea_cannon_fire_1',0,1.2,.82,1),('sea_cannon_hit_cannon_1',0,.5,.9,.3)]),
 'turret_fire':dict(high=100,low=10000,peak=.68,layers=[('sea_cannon_fire_1',0,.7,1.3,1),('sea_cannon_hit_wall_no_splash',0,.25,1.25,.12)]),
 'ordnance_impact':dict(high=40,low=10500,peak=.78,layers=[('sea_cannon_hit_cannon_1',0,2.3,.9,.8),('sea_cannon_hit_1',.01,2.8,1,.45),('sea_cannon_hit_wall_no_splash',0,1.6,.85,.22)]),
}
def rows():return json.loads(Path(__file__).with_name('vehicle_sources.json').read_text())
def configure():
 shared.WORK=WORK;shared.JOBS=JOBS;shared.rows=rows

def build():
 DOC.mkdir(parents=True,exist_ok=True);manifest=json.loads((BASE/'manifest.json').read_text())
 for name,job in JOBS.items():
  master=WORK/f'{name}.wav';a=shared.decode(master);a-=a.mean();a*=job['peak']/max(abs(a).max(),1e-8)
  looped=name=='rocket_tank_travel'
  if looped:
   a=a[2400:-2400];n=2880;w=np.linspace(0,1,n)
   a=np.concatenate([a[n:-n],a[-n:]*(1-w)+a[:n]*w]);a-=a.mean();a*=job['peak']/max(abs(a).max(),1e-8)
  else:
   a[:24]*=np.linspace(0,1,24);a[-24:]*=np.linspace(1,0,24)
  path=BASE/f'{name}.wav';shared.wav(path,a)
  manifest[name]=dict(file=path.name,sources=list(dict.fromkeys(x[0] for x in job['layers'])),loop=looped,seconds=len(a)/RATE,rate=RATE,channels=1,peak_dbfs=float(20*np.log10(abs(a).max())),rms_dbfs=float(20*np.log10(np.sqrt(np.mean(a*a)))),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),master_sha256=hashlib.sha256(master.read_bytes()).hexdigest(),recipe=job,edit='Isolated original OGA/Pixabay layers; Audacity MCP mix, high/low-pass, attack/tail fades, DC removal, normalization; mono 24 kHz PCM16, gain trim; travel loop uses interior crop and 120 ms end-to-start crossfade')
 (BASE/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 sources={r['id']:r for r in json.loads((BASE/'sources.json').read_text())};sources.update({r['id']:r for r in rows()});(BASE/'sources.json').write_text(json.dumps(list(sources.values()),indent=2)+'\n')
 (DOC/'recipes.json').write_text(json.dumps(JOBS,indent=2)+'\n');(DOC/'audacity-mcp-receipt.json').write_bytes((WORK/'mcp-receipt.json').read_bytes())
 reel=[];times=[];cursor=0.
 for name in JOBS:
  a=shared.decode(BASE/f'{name}.wav');times.append(dict(cue=name,start=round(cursor,3)));reel.extend([a*.5,np.zeros(RATE)]);cursor+=len(a)/RATE+1
 shared.wav(DOC/'audition.wav',np.concatenate(reel));(DOC/'timings.json').write_text(json.dumps(times,indent=2)+'\n')
 print('CQ_VEHICLE_AUDIO_BUILD',len(JOBS))
if __name__=='__main__':
 configure()
 if '--fetch' in sys.argv:shared.fetch()
 elif '--build' in sys.argv:build()
 else:shared.fetch();asyncio.run(shared.author());build()
