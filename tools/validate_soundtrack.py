"""Measure rendered scores and verify source provenance. Requires FFmpeg/numpy."""
from pathlib import Path
import hashlib, json, subprocess
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
MUSIC=ROOT/'deathmatch/audio/music'

def main():
    rows=[]; failures=[]
    for score in json.loads((MUSIC/'scores.json').read_text()):
        path=MUSIC/(score['stem']+'.ogg')
        raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-f','f32le','-ar','32000','-ac','2','-'])
        samples=np.frombuffer(raw,dtype='<f4').reshape(-1,2)
        measure=subprocess.run(['ffmpeg','-hide_banner','-i',str(path),'-af','loudnorm=I=-19:TP=-3:LRA=10:print_format=json','-f','null','-'],capture_output=True,text=True,check=True)
        stats=json.JSONDecoder().raw_decode(measure.stderr[measure.stderr.rfind('{'):])[0]
        lufs=float(stats['input_i']);peak=float(stats['input_tp'])
        # Check loop discontinuity in addition to loudness and finite PCM.
        seam=float(np.max(np.abs(samples[-1]-samples[0])))
        duration=len(samples)/32000
        ok=(np.isfinite(samples).all() and abs(duration-score['duration'])<.1
            and abs(lufs-score['target_lufs'])<1.5 and peak<=-2
            and seam<.08 and hashlib.sha256(path.read_bytes()).hexdigest()==score['sha256'])
        row={'mode':score['key'],'seconds':duration,'lufs':lufs,'true_peak_dbtp':peak,'loop_step':round(seam,6),'bytes':path.stat().st_size,'passed':bool(ok)}
        rows.append(row);print(json.dumps(row),flush=True)
        if not ok:failures.append(score['key'])
    for source in json.loads((MUSIC/'samples/vsco-sources.json').read_text()):
        if hashlib.sha256((MUSIC/'samples'/(source['name']+'.wav')).read_bytes()).hexdigest()!=source['prepared_sha256']:
            failures.append('source '+source['name'])
    result={'scores':rows,'runtime_bytes':sum(r['bytes'] for r in rows),'failures':failures}
    dest=ROOT/'test-results/soundtrack-analysis.json';dest.parent.mkdir(exist_ok=True);dest.write_text(json.dumps(result,indent=2)+'\n')
    raise SystemExit(bool(failures))
if __name__=='__main__':main()
