"""Make Escape Velocity's 64-bar loop; --install selects the asset for Titanball.
The original finite audition remains intact. Requires numpy/FFmpeg.
"""
import argparse,hashlib,json,shutil,subprocess,wave
import numpy as np
import compose_escape_velocity as score
ROOT=score.ROOT;OUT=score.OUT;MUSIC=ROOT/'deathmatch/audio/music';RATE=score.RATE

def write(path,x):
    with wave.open(str(path),'wb') as f:
        f.setparams((2,2,RATE,0,'NONE','not compressed'));f.writeframes(np.rint(np.clip(x,-1,1)*32767).astype('<i2').tobytes())
def decode(path):
    return np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-ar',str(RATE),'-ac','2','-f','f32le','-']),dtype='<f4').reshape(-1,2)
def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--install',action='store_true');args=parser.parse_args()
    mixed=score.compose(loop=True);assert np.isfinite(mixed).all()
    # Remove any residual sub-millisecond endpoint DC step without silencing
    # the boundary or changing the musical length/downbeat.
    width=round(.003*RATE);step=mixed[0]-mixed[-1]
    mixed[-width:]+=np.linspace(0,1,width)[:,None]*step
    raw=OUT/'loop-unmastered.wav';write(raw,mixed*.90/max(1,float(np.max(np.abs(mixed)))))
    measured=score.measure(raw)
    norm='loudnorm=I=-19:TP=-3:LRA=11:linear=true'+''.join(':'+k+'='+measured[v] for k,v in [('measured_I','input_i'),('measured_TP','input_tp'),('measured_LRA','input_lra'),('measured_thresh','input_thresh'),('offset','target_offset')])
    master=OUT/'Escape-Velocity-Loop.wav';dest=OUT/'Escape-Velocity-Loop.ogg'
    # Tiny codec-edge ramps remove oversampling/Vorbis boundary ringing; the
    # beat and musical phrase continue without an outro or perceptible pause.
    norm+=f',afade=t=in:d=0.003,afade=t=out:st={len(mixed)/RATE-.003:.9f}:d=0.003'
    subprocess.run(['ffmpeg','-y','-v','error','-i',str(raw),'-af',norm,'-ar',str(RATE),'-c:a','pcm_s16le',str(master)],check=True)
    subprocess.run(['ffmpeg','-y','-v','error','-i',str(master),'-af','afade=t=in:d=0.008','-c:a','libvorbis','-q:a','5','-metadata','title=Escape Velocity - Titanball','-metadata','artist=FPSloppa original music','-metadata','comment=Original CC0 composition; 64-bar seamless loop',str(dest)],check=True)
    audio=decode(dest);stats=score.measure(dest)
    seam=float(np.max(np.abs(audio[0]-audio[-1])))
    durations=len(audio)/RATE
    assert abs(durations-score.BARS*4*score.BEAT)<1/RATE
    assert np.isfinite(audio).all() and np.max(np.abs(audio))<1
    assert seam<.003 and float(stats['input_tp'])<=-2 and abs(float(stats['input_i'])+19)<.5
    # Keep a short audition of the exact end -> beginning transition.
    boundary=OUT/'loop-boundary.wav';write(boundary,np.concatenate([audio[-6*RATE:],audio[:6*RATE]]))
    subprocess.run(['ffmpeg','-y','-v','error','-i',str(boundary),'-c:a','libvorbis','-q:a','5',str(OUT/'loop-boundary.ogg')],check=True)
    row={'key':'tb','stem':'escape_velocity','title':'Escape Velocity','name':'Escape Velocity','bpm':score.BPM,'bars':score.BARS,'duration':durations,'bytes':dest.stat().st_size,'ogg_bytes':dest.stat().st_size,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'target_lufs':-19,'source_format':'recorded-sample-arrangement','source_file':'escape_velocity.score.json','sample_rate':RATE,'generator':'tools/generate_tb_music.py --install','loop':True,'loop_offset':0,'loop_step':seam,'measured_lufs':float(stats['input_i']),'true_peak_dbtp':float(stats['input_tp']),'license':'CC0-1.0','events':score.EVENTS}
    (OUT/'loop.score.json').write_text(json.dumps(row,indent=2)+'\n')
    if args.install:
        shutil.copy2(dest,MUSIC/'escape_velocity.ogg')
        (MUSIC/'escape_velocity.score.json').write_text(json.dumps(row,indent=2)+'\n')
        rows=json.loads((MUSIC/'scores.json').read_text());rows=[r for r in rows if r['key']!='tb'];rows.append({k:v for k,v in row.items() if k!='events'})
        (MUSIC/'scores.json').write_text(json.dumps(rows,indent=2)+'\n')
    print(json.dumps({k:v for k,v in row.items() if k!='events'},indent=2),flush=True)
if __name__=='__main__':main()
