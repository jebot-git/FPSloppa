"""Remix existing licensed CC0 field edits into a finite building-collapse cue."""
from pathlib import Path
import hashlib,json,subprocess
ROOT=Path(__file__).resolve().parents[2]
AUDIO=ROOT/'deathmatch/audio/cq_field'
recipe='[0:a]asplit=3[a][b][c];[a]asetrate=15600,aresample=24000,lowpass=f=1800,volume=0.65[x];[b]asetrate=19200,aresample=24000,adelay=240,lowpass=f=2600,volume=0.45[y];[c]adelay=650,lowpass=f=3600,volume=0.3[z];[1:a]lowpass=f=350,volume=0.18,afade=t=in:d=0.08[r];[x][y][z][r]amix=inputs=4:normalize=0,atrim=duration=3.5,afade=t=out:st=2.2:d=1.3,alimiter=limit=0.79:level=false[out]'
subprocess.run(['ffmpeg','-v','error','-y','-i',str(AUDIO/'ordnance_impact.wav'),'-i',str(AUDIO/'thunder.wav'),'-filter_complex',recipe,'-map','[out]','-ar','24000','-ac','1','-c:a','pcm_s16le',str(AUDIO/'building_collapse.wav')],check=True)
manifest=json.loads((AUDIO/'manifest.json').read_text())
manifest['building_collapse']={'file':'building_collapse.wav','sources':['sea_cannon_hit_cannon_1','sea_cannon_hit_1','sea_cannon_hit_wall_no_splash','thunder'],'loop':False,'seconds':3.5,'rate':24000,'channels':1,'sha256':hashlib.sha256((AUDIO/'building_collapse.wav').read_bytes()).hexdigest(),'recipe':recipe,'edit':'Layered slowed masonry-like impacts, staggered debris transients and filtered thunder rumble; 3.5s finite tail. CC0 derivatives.'}
(AUDIO/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
