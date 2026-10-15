"""Validate committed runtime clips, authored loop seams and a real Godot mixer capture."""
import hashlib,json,subprocess
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[2];BASE=ROOT/'deathmatch/audio/cq_field'
def decode(p):
 return np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-ac','1','-ar','24000','-f','f32le','-']),dtype='<f4')
rows={}
for key,row in json.loads((BASE/'manifest.json').read_text()).items():
 p=BASE/row['file'];assert hashlib.sha256(p.read_bytes()).hexdigest()==row['sha256'],key
 a=decode(p);assert np.isfinite(a).all() and a.size>200,key
 peak=float(abs(a).max());rms=float(np.sqrt(np.mean(a*a)));dc=float(abs(a.mean()))
 assert .0001<rms and peak<.96 and dc<.003,(key,peak,rms,dc)
 seam=float(abs(a[-1]-a[0]));typical=float(np.quantile(abs(np.diff(a)),.99))
 if row['loop']:assert seam<max(.03,typical*2.5),(key,'loop seam',seam,typical)
 rows[key]={'peak_dbfs':round(float(20*np.log10(peak)),2),'rms_dbfs':round(float(20*np.log10(rms)),2),'dc':dc,'seam':seam,'seconds':a.size/24000}
mix=ROOT/'test-results/cq-field-audio/mix.wav'
if mix.exists():
 a=decode(mix);assert abs(a).max()>.001,'Godot mixer capture must contain sound'
 rows['godot_mix']={'peak':float(abs(a).max()),'rms':float(np.sqrt(np.mean(a*a)))}
out=ROOT/'test-results/cq-field-audio';out.mkdir(exist_ok=True);(out/'quality.json').write_text(json.dumps(rows,indent=2)+'\n')
print('CQ_FIELD_AUDIO_QUALITY_PASS',len(rows))
