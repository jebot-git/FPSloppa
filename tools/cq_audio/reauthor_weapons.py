"""Rebuild CQ weapon reports and a disconnected future-tier bank via Audacity MCP.
Run with the audacity-mcp-server Python (mcp + numpy), Audacity + mod-script-pipe.
Default: prepare isolated layers, author/mix/filter/fade/export in Audacity, encode.
--build: encode already authored masters. --fetch: fetch pinned source previews.
"""
import asyncio, hashlib, json, subprocess, sys, urllib.request, wave
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
CACHE=ROOT/'tools/audio-sources/cq-field'; WORK=CACHE/'weapons'
BASE=ROOT/'deathmatch/audio/cq_field'; RESERVE=ROOT/'tools/cq_audio/tier_reserve'
DOC=ROOT/'docs/audio/cq-weapons-20261015'; RATE=24000
# Layers: source ID (or existing recording), start, duration, playback rate, relative gain.
JOBS={
 'pistol':dict(high=90,low=10000,peak=.72,layers=[('tabasco_existing',0,.3,1,1),('fs_378185',.09,.48,1.05,.22)]),
 'pistol_suppressed':dict(high=160,low=2600,peak=.42,layers=[('tabasco_existing',0,.2,1.12,1),('fs_378185',.09,.24,1.2,.12)]),
 'smg':dict(high=180,low=9000,peak=.64,layers=[('tabasco_existing',0,.14,1.18,1),('fs_531861',.13,.16,1.35,.16)]),
 'carbine':dict(high=130,low=11000,peak=.7,layers=[('fs_466834',0,.43,1,1),('fs_480872',0,.32,1,.22)]),
 'assault':dict(high=170,low=10000,peak=.67,layers=[('fs_466868',0,.25,1.18,.8),('fs_697894',2,.29,1,.4)]),
 'beam':dict(high=70,low=11000,peak=.74,layers=[('fs_531861',.13,.9,.88,.8),('fs_480872',6,.8,.9,.45)]),
 'burst_pistol':dict(high=200,low=10500,peak=.65,layers=[('fs_330293',.31,.44,1.22,.75),('fs_697894',0,.27,1.12,.3)]),
 'energy_impact':dict(high=350,low=8500,peak=.65,layers=[('fs_344809',.03,.26,1.35,1),('fs_330293',8.13,.23,1.5,.18)]),
}
# Remaining distinct takes are prepared, but have no weapon assignment or runtime import.
for i,start in enumerate([3,9,12,15,18,21,24,27],1):
 JOBS[f'reserve_blaster_{i:02}']=dict(high=120,low=11000,peak=.7,layers=[('fs_480872',start,.95,1,1)])
for i,start in enumerate([1.98,3.60,5.21,6.76],1):
 JOBS[f'reserve_plasma_{i:02}']=dict(high=100,low=11000,peak=.7,layers=[('fs_330293',start,.8,1,1)])
JOBS['reserve_heavy_pistol']=dict(high=75,low=9500,peak=.72,layers=[('fs_378185',.09,1.5,1,1)])
JOBS['reserve_pulse']=dict(high=180,low=10500,peak=.65,layers=[('fs_697894',6.49,.34,1,1)])

def rows():return json.loads((Path(__file__).with_name('weapon_sources.json')).read_text())
def source(key):
 if key=='tabasco_existing':return ROOT/'deathmatch/audio/recorded/weapon_2_0.wav'
 return CACHE/next(r['file'] for r in rows() if r['id']==key)
def decode(path):
 return np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-ac','1','-ar',str(RATE),'-f','f32le','-']),dtype='<f4').copy()
def wav(path,a):
 path.parent.mkdir(parents=True,exist_ok=True)
 with wave.open(str(path),'wb') as f:
  f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(np.round(a*32767).astype('<i2').tobytes())
def fetch():
 for row in rows():
  path=CACHE/row['file'];path.parent.mkdir(parents=True,exist_ok=True)
  if not path.exists():path.write_bytes(urllib.request.urlopen(row['download'],timeout=90).read())
  assert hashlib.sha256(path.read_bytes()).hexdigest()==row['sha256'],row['id']
def prepare():
 for name,job in JOBS.items():
  for i,(key,start,seconds,speed,gain) in enumerate(job['layers']):
   a=decode(source(key));a=a[round(start*RATE):round((start+seconds)*RATE)]
   assert len(a)>100,key
   a=np.interp(np.arange(0,len(a),speed),np.arange(len(a)),a);a-=a.mean();a*=.5*gain/max(abs(a).max(),1e-8)
   wav(WORK/'layers'/f'{name}_{i}.wav',a)
async def author():
 from mcp import ClientSession, StdioServerParameters
 from mcp.client.stdio import stdio_client
 prepare();receipt=[];WORK.mkdir(parents=True,exist_ok=True)
 async with stdio_client(StdioServerParameters(command='/home/blux/.local/bin/audacity-mcp')) as (r,w):
  async with ClientSession(r,w) as session:
   await session.initialize()
   async def call(name,args=None):
    result=await session.call_tool(name,args or {})
    data=json.loads(result.content[0].text)
    receipt.append(dict(tool=name,arguments=args or {},result=data))
    (WORK/'mcp-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    if result.isError or not data.get('success'):raise RuntimeError(data)
   # A new empty project preserves any existing user project.
   await call('project_new')
   for name,job in JOBS.items():
    for i in range(len(job['layers'])):await call('project_import_audio',dict(path=str(WORK/'layers'/f'{name}_{i}.wav')))
    await call('select_all')
    if len(job['layers'])>1:await call('track_mix_and_render')
    await call('select_all')
    await call('effect_high_pass_filter',dict(frequency=job['high'],rolloff='dB12'))
    await call('effect_low_pass_filter',dict(frequency=job['low'],rolloff='dB12'))
    duration=max(sec/speed for _,_,sec,speed,_ in job['layers'])
    await call('select_region',dict(start=0,end=.001));await call('effect_fade_in')
    await call('select_region',dict(start=max(.01,duration-.07),end=duration));await call('effect_fade_out')
    await call('select_all');await call('normalize',dict(peak_level_db=-3,remove_dc=True))
    # PCM master is exported from Audacity; encoder only resamples/trims gain.
    await call('project_export_audio',dict(path=str(WORK/f'{name}.wav'),num_channels=1))
    await call('select_all');await call('track_remove')
    print('AUTHORED',name,flush=True)
   # Leave the empty scratch project open: closing the last window can crash
   # this Audacity build after successful exports (all source work is saved).

def build():
 manifest=json.loads((BASE/'manifest.json').read_text());reserve={};sources=rows()
 RESERVE.mkdir(parents=True,exist_ok=True);(RESERVE/'.gdignore').touch();DOC.mkdir(parents=True,exist_ok=True)
 for name,job in JOBS.items():
  master=WORK/f'{name}.wav';a=decode(master);a-=a.mean();a*=job['peak']/max(abs(a).max(),1e-8)
  # Tiny post-resampling fades guarantee click-free PCM edges without lengthening reports.
  n=min(24,len(a)//4);a[:n]*=np.linspace(0,1,n);a[-n:]*=np.linspace(1,0,n)
  path=(RESERVE if name.startswith('reserve_') else BASE)/f'{name}.wav';wav(path,a)
  row=dict(file=path.name,sources=list(dict.fromkeys(x[0] for x in job['layers'])),loop=False,seconds=len(a)/RATE,rate=RATE,channels=1,peak_dbfs=float(20*np.log10(abs(a).max())),rms_dbfs=float(20*np.log10(np.sqrt(np.mean(a*a)))),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),master_sha256=hashlib.sha256(master.read_bytes()).hexdigest(),edit='Isolated single-shot layers; relative gain/playback-rate preparation; Audacity MCP mix, high/low-pass, attack/tail fades, DC removal and normalization; mono 24 kHz PCM16 runtime encoding',recipe=job)
  (reserve if name.startswith('reserve_') else manifest)[name]=row
  print('ENCODED',name,len(a)/RATE)
 (BASE/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 existing=json.loads((BASE/'sources.json').read_text());existing={r['id']:r for r in existing};existing.update({r['id']:r for r in sources});(BASE/'sources.json').write_text(json.dumps(list(existing.values()),indent=2)+'\n')
 (RESERVE/'manifest.json').write_text(json.dumps(reserve,indent=2)+'\n')
 # Repeat reports at actual weapon cadence; no synthetic bursts in runtime files.
 reel=[];timings=[];cursor=0.
 for name,interval,count in [('pistol',.35,3),('pistol_suppressed',.6,3),('smg',.06,12),('carbine',.12,8),('assault',.075,12),('beam',.8,3),('burst_pistol',.12,3),('energy_impact',.4,2)]:
  a=decode(BASE/f'{name}.wav');segment=np.zeros(round((count-1)*interval*RATE)+len(a))
  for i in range(count):j=round(i*interval*RATE);segment[j:j+len(a)]+=a
  timings.append(dict(cue=name,start=round(cursor,3),shots=count,interval=interval,unattenuated_overlap_peak=float(abs(segment).max())))
  reel.extend([segment*.35,np.zeros(RATE)]);cursor+=(len(segment)+RATE)/RATE
 wav(DOC/'runtime-cadence.wav',np.concatenate(reel))
 (DOC/'timings.json').write_text(json.dumps(timings,indent=2)+'\n')
 if (WORK/'mcp-receipt.json').exists():(DOC/'audacity-mcp-receipt.json').write_bytes((WORK/'mcp-receipt.json').read_bytes())
 (DOC/'recipes.json').write_text(json.dumps(JOBS,indent=2)+'\n')
if __name__=='__main__':
 if '--fetch' in sys.argv:fetch()
 elif '--build' in sys.argv:build()
 else:fetch();asyncio.run(author());build()
