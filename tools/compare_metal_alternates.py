"""Build matched-level soundtrack A/B previews and audit the rendered alternatives."""
from pathlib import Path
import hashlib,json,subprocess,tempfile,wave
import numpy as np
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'docs/audio/metal-alternates';RATE=44100

def measure(path):
 r=subprocess.run(['ffmpeg','-hide_banner','-i',str(path),'-af','loudnorm=I=-19:TP=-3:LRA=10:print_format=json','-f','null','-'],capture_output=True,text=True,check=True)
 return json.JSONDecoder().raw_decode(r.stderr[r.stderr.rfind('{'):])[0]
def pcm(path):
 return np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-f','f32le','-ac','2','-ar',str(RATE),'-']),dtype='<f4').reshape(-1,2).copy()
def write(path,x):
 with wave.open(str(path),'wb') as f:
  f.setparams((2,2,RATE,0,'NONE','not compressed'));f.writeframes(np.rint(np.clip(x,-1,1)*32767).astype('<i2').tobytes())
def main():
 scores=[s for s in json.loads((OUT/'scores.json').read_text())['scores'] if s['key'] in ['dm','cc','ft']];report=[];chunks=[];timeline=[];at=0
 archive=ROOT/'docs/audio/industrial-originals'
 baseline_root=archive if archive.exists() else ROOT/'deathmatch/audio/music'
 with tempfile.TemporaryDirectory(prefix='fpsloppa-metal-compare-') as td:
  td=Path(td)
  for row in scores:
   path=OUT/(row['stem']+'.ogg');x=pcm(path);stats=measure(path)
   seam=float(np.max(np.abs(x[0]-x[-1])))
   assert np.isfinite(x).all() and abs(len(x)/RATE-row['duration'])<.05
   assert abs(float(stats['input_i'])+19)<1 and float(stats['input_tp'])<-2 and seam<.02
   assert hashlib.sha256(path.read_bytes()).hexdigest()==row['sha256']
   report.append({'track':row['name'],'duration':len(x)/RATE,'lufs':float(stats['input_i']),'true_peak_dbtp':float(stats['input_tp']),'loop_step':seam,'passed':True})
   pairs=[]
   for kind,source in [('A industrial',baseline_root/(row['current']+'.ogg')),('B metal',path)]:
    # Use the same musical passage for equal-duration excerpts. Normalize each
    # excerpt independently, so louder sections cannot win the comparison.
    excerpt=td/'excerpt.wav';dest=td/'matched.wav'
    start=12*4*60/row['bpm']
    subprocess.run(['ffmpeg','-y','-v','error','-ss',str(start),'-i',str(source),'-t','12','-af','afade=t=in:d=0.08,afade=t=out:st=11.88:d=0.12','-ar',str(RATE),'-ac','2',str(excerpt)],check=True)
    m=measure(excerpt);af='loudnorm=I=-19:TP=-3:LRA=10:linear=true'+''.join(':'+k+'='+m[v] for k,v in [('measured_I','input_i'),('measured_TP','input_tp'),('measured_LRA','input_lra'),('measured_thresh','input_thresh'),('offset','target_offset')])
    subprocess.run(['ffmpeg','-y','-v','error','-i',str(excerpt),'-af',af,'-ar',str(RATE),'-ac','2',str(dest)],check=True)
    check=measure(dest);assert abs(float(check['input_i'])+19)<.15
    audio=pcm(dest)
    # Spoken labels are comparison aids, not part of either soundtrack.
    speech=td/'label.wav'
    label=row['key'].upper()+'. '+('Industrial version.' if kind.startswith('A') else 'Metal alternative.')
    subprocess.run(['espeak-ng','-s','155','-a','70','-w',str(speech),label],check=True)
    announce=pcm(speech);announce*=.16/max(np.max(np.abs(announce)),.001)
    block=np.concatenate([announce,np.zeros((int(.25*RATE),2)),audio,np.zeros((int(.6*RATE),2))])
    timeline.append({'start':round(at,2),'mode':row['key'],'version':kind,'music_start':round(at+len(announce)/RATE+.25,2),'excerpt_lufs':float(check['input_i'])});at+=len(block)/RATE
    pairs.append(block);chunks.append(block)
   pair=OUT/(row['key']+'_comparison.ogg');wav=td/'pair.wav';write(wav,np.concatenate(pairs))
   subprocess.run(['ffmpeg','-y','-v','error','-i',str(wav),'-c:a','libvorbis','-q:a','4',str(pair)],check=True)
  preview=ROOT/'test-results/metal-alternates-comparison.wav';preview.parent.mkdir(exist_ok=True)
  write(preview,np.concatenate(chunks))
  subprocess.run(['ffmpeg','-y','-v','error','-i',str(preview),'-c:a','libvorbis','-q:a','4',str(OUT/'comparison.ogg')],check=True)
 baseline=json.loads((OUT/'baseline-hashes.json').read_text())
 for name,sha in baseline.items():assert hashlib.sha256((baseline_root/name).read_bytes()).hexdigest()==sha,name
 for sample in json.loads((OUT/'sources.json').read_text()):assert hashlib.sha256((OUT/'samples'/sample['prepared']).read_bytes()).hexdigest()==sample['prepared_sha256']
 result={'tracks':report,'timeline':timeline,'preview_duration':at,'industrial_baseline_preserved':True,'sample_checksums_verified':True}
 (OUT/'comparison.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
