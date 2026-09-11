"""Master the public-domain Mega Destruction XM for the existing AS music bus."""
from pathlib import Path
import hashlib,json,subprocess
ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'docs/audio/assault/mega_destruction.xm'
out=ROOT/'deathmatch/audio/music/mega_destruction.ogg'
assert source.read_bytes().startswith(b'Extended Module: ')
url='https://modarchive.org/index.php?request=view_by_moduleid&query=50252'
filters='highpass=f=45,lowpass=f=14000,afade=t=in:d=0.02,afade=t=out:st=156.77:d=0.03'
base=['ffmpeg','-nostdin','-hide_banner','-i',str(source)]
measure=subprocess.run(base+['-af',filters+',loudnorm=I=-19:TP=-3:LRA=10:print_format=json','-f','null','-'],capture_output=True,text=True,check=True)
stats=json.JSONDecoder().raw_decode(measure.stderr[measure.stderr.rfind('{'):])[0]
normal='loudnorm=I=-19:TP=-3:LRA=10:linear=true:measured_I={input_i}:measured_TP={input_tp}:measured_LRA={input_lra}:measured_thresh={input_thresh}:offset={target_offset}'.format(**stats)
subprocess.run(base+['-y','-af',filters+','+normal,'-ar','44100','-ac','2','-c:a','libvorbis','-q:a','5','-metadata','title=Mega Destruction','-metadata','artist=Zilly Mike','-metadata','license=Public Domain (Mod Archive attribution)','-metadata','comment='+url,str(out)],check=True)
duration=float(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','default=nw=1:nk=1',str(out)],text=True))
row={'key':'as','stem':'mega_destruction','title':'Mega Destruction','artist':'Zilly Mike','duration':duration,'target_lufs':-19,'bytes':out.stat().st_size,'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'source_format':'XM','license':'Public Domain','source_url':url,'processing':'Original instrumentation; 45 Hz high-pass, 14 kHz low-pass, short loop-edge fades, two-pass loudness master, 44.1 kHz stereo Vorbis quality 5'}
(out.with_suffix('.score.json')).write_text(json.dumps(row,indent=2)+'\n')
manifest=out.parent/'scores.json';scores=json.loads(manifest.read_text());scores=[s for s in scores if s['key']!='as'];scores.append(row);manifest.write_text(json.dumps(scores,indent=2)+'\n')
print(json.dumps(row,indent=2))
