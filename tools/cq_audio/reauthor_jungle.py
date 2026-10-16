"""Mix user-provided CC0 tropical recordings into quiet, seamless stereo beds.
Requires ffmpeg + numpy. Cache the five WAVs listed in jungle_mix.json under
 tools/audio-sources/cq-field. --stems prepares Audacity-ready unity-gain layers;
 --master-dir consumes Audacity exports. Without it, the pinned gains reproduce
 the mix in code. Originals remain untouched; no synthesized ambience is used.
"""
from pathlib import Path
import argparse,hashlib,json,subprocess,wave
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'deathmatch/audio/cq_field';CACHE=ROOT/'tools/audio-sources/cq-field'
RECIPE=Path(__file__).with_name('jungle_mix.json')
RATE=24000;MASTER_SECONDS=128;LOOP_SECONDS=120;CROSSFADE=8

def decode(path,start=0,length=None,filters=None):
 args=['ffmpeg','-v','error','-ss',str(start),'-i',str(path)]
 if length is not None:args+=['-t',str(length)]
 if filters:args+=['-af',filters]
 args+=['-ar',str(RATE),'-ac','2','-f','f32le','-']
 audio=np.frombuffer(subprocess.check_output(args),dtype='<f4').reshape(-1,2).copy()
 if not len(audio) or not np.isfinite(audio).all():raise ValueError('Invalid audio: '+str(path))
 return audio

def loop(audio,seconds):
 n=int(seconds*RATE)
 if len(audio)<n*3:raise ValueError('Too little audio for loop overlap')
 theta=np.arange(n,dtype=np.float32)/n*np.pi/2
 blend=audio[-n:]*np.cos(theta)[:,None]+audio[:n]*np.sin(theta)[:,None]
 return np.concatenate([audio[n:-n],blend])

def write_wav(path,audio):
 path.parent.mkdir(parents=True,exist_ok=True)
 with wave.open(str(path),'wb') as f:
  f.setnchannels(2);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(np.rint(np.clip(audio,-1,1)*32767).astype('<i2').tobytes())

def stems(source_dir=CACHE):
 recipe=json.loads(RECIPE.read_text());result={}
 for key,row in recipe['sources'].items():
  source=source_dir/row['file']
  if not source.exists():raise FileNotFoundError('Supply the original user WAV: '+str(source))
  if hashlib.sha256(source.read_bytes()).hexdigest()!=row['sha256']:raise ValueError('Source changed: '+str(source))
  a=decode(source,row['start'],row['seconds'],f"highpass=f={row['highpass']}:p=2,lowpass=f=9000:p=2")
  a-=a.mean(axis=0)
  a*=min(10**(-26/20)/max(float(np.sqrt(np.mean(a*a))),1e-9),.55/max(float(abs(a).max()),1e-9))
  a=loop(a,row['overlap']);a=np.roll(a,int(row['phase']*RATE),axis=0)
  a=np.tile(a,(int(np.ceil(MASTER_SECONDS*RATE/len(a))),1))[:MASTER_SECONDS*RATE]
  result[key]=a
 return recipe,result

def prepare_stems(target,source_dir=CACHE):
 recipe,layers=stems(source_dir)
 for key,a in layers.items():write_wav(target/(key+'.wav'),a)
 (target/'recipe.json').write_text(json.dumps(recipe,indent=2)+'\n')
 print('AUDACITY_STEMS',target)

def build(master_dir=None,source_dir=CACHE):
 recipe,layers=stems(source_dir);manifest=json.loads((OUT/'manifest.json').read_text())
 for period,mix in recipe['mixes'].items():
  key='forest_'+period
  if master_dir is not None:a=decode(master_dir/(key+'.wav'))
  else:
   a=np.zeros((MASTER_SECONDS*RATE,2),dtype=np.float32)
   for layer in mix['layers']:a+=layers[layer['source']] * 10**(layer['gain_db']/20)
  if abs(len(a)/RATE-MASTER_SECONDS)>.01:raise ValueError('Expected 128-second Audacity export')
  a=loop(a,CROSSFADE);a-=a.mean(axis=0)
  a*=min(10**(mix['rms_dbfs']/20)/max(float(np.sqrt(np.mean(a*a))),1e-9),.22/max(float(abs(a).max()),1e-9))
  intermediate=CACHE/'edited/jungle'/(key+'.wav');write_wav(intermediate,a)
  target=OUT/(key+'.ogg')
  subprocess.run(['ffmpeg','-v','error','-y','-i',str(intermediate),'-c:a','libvorbis','-q:a','4',str(target)],check=True)
  decoded=decode(target)
  manifest[key]={'file':target.name,'sources':[l['source'] for l in mix['layers']],'loop':True,'seconds':len(decoded)/RATE,'rate':RATE,'channels':2,'peak_dbfs':float(20*np.log10(abs(decoded).max())),'rms_dbfs':float(20*np.log10(np.sqrt(np.mean(decoded*decoded)))),'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'edit':'User-selected CC0 WAV source set; rooster-bearing Costa Rican layer excluded, band-limited, level-matched excerpts, equal-power source overlaps, pinned multitrack gains, 8 s equal-power end/start overlap, DC removal, quiet peak/RMS trim; recipe tools/cq_audio/jungle_mix.json','layers':mix['layers'],'recipe_sha256':hashlib.sha256(RECIPE.read_bytes()).hexdigest()}
 (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 sources=[s for s in json.loads((OUT/'sources.json').read_text()) if s['id']!='original_cq_jungle_20261015' and s['id'] not in recipe['sources']]
 for key,row in recipe['sources'].items():
  sources.append({k:row[k] for k in ['author','license','page','file','sha256']}|{'id':key,'source_quality':'User-provided original WAV; CC0 license declared by user.'})
 (OUT/'sources.json').write_text(json.dumps(sources,indent=2)+'\n')
 print('JUNGLE_FIELD_MIX_COMPLETE',LOOP_SECONDS,'seconds per loop')

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--stems',type=Path);p.add_argument('--master-dir',type=Path);p.add_argument('--source-dir',type=Path,default=CACHE);args=p.parse_args()
 if args.stems:prepare_stems(args.stems,args.source_dir)
 else:build(args.master_dir,args.source_dir)
