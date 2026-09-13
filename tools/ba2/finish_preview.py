"""Encode completed BA-2 frames and archive the animation validation receipt."""
import hashlib,json,re,subprocess
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'test-results/ba2/walk'
assert 'BA2_WALK_RENDER_COMPLETE' in (OUT/'render.log').read_text()
frames=sorted((OUT/'frames').glob('*.png'));assert len(frames)==357
checks=json.loads((OUT/'animation-checks.json').read_text());assert checks['pass']
godot=json.loads((OUT/'godot-checks.json').read_text());assert not godot['failures']
glb=json.loads((OUT/'glb-checks.json').read_text())
video=OUT/'BA2-10m-walk-preview.mp4'
overlay="drawtext=text='BA-2 | 10 m | 0.45 m/s':x=16:y=14:fontsize=17:fontcolor=white:box=1:boxcolor=black@0.55:boxborderw=6,drawtext=text='X hinge cannons | body yaw limited to 3 degrees':x=16:y=h-51:fontsize=13:fontcolor=white:box=1:boxcolor=black@0.55:boxborderw=6,drawtext=text='2 s acceleration | 1.8 m figure | 2 m tiles':x=16:y=h-27:fontsize=13:fontcolor=white:box=1:boxcolor=black@0.55:boxborderw=6"
subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-framerate','20','-i',str(OUT/'frames/%04d.png'),'-vf',overlay,'-c:v','libx264','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart',str(video)],check=True)
media=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','stream=codec_name,width,height,nb_frames,r_frame_rate:format=duration','-of','json',str(video)]))
assert media['streams'][0]['nb_frames']=='357'
sheet=Image.new('RGB',(1280,448),(20,24,30));draw=ImageDraw.Draw(sheet)
for i,index in enumerate([132,146,160,174,188,202,216,230]):
    x=(i%4)*320;y=(i//4)*224
    with Image.open(OUT/f'frames/{index:04d}.png') as frame:sheet.paste(frame.convert('RGB').resize((320,200)),(x,y+24))
    draw.text((x+8,y+5),f'{index/20:.2f} seconds',fill='white')
sheet.save(OUT/'gait-review.png')
assets={}
for p in [ROOT/'tools/ba2/animated/BA2-10m-walk.blend',ROOT/'tools/ba2/animated/BA2-10m-walk.glb',video]:
    assets[str(p.relative_to(ROOT))]={'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
assert assets['tools/ba2/animated/BA2-10m-walk.glb']['sha256']==glb['sha256']
source=ROOT/'tools/ba2/source/Quandtum_BA-2_v1_1.zip'
assert hashlib.sha256(source.read_bytes()).hexdigest()=='e73d1d6e52697315405c75dea4d530a6ffa1910288b40e150cda25adb031c893'
report={'status':'authored_animation_prototype','integrated_into_game':False,'assets':assets,'animation':{k:v for k,v in checks.items() if k!='samples'},'godot':godot,'media':media,'limitations':['Authored level floor; no terrain adaptation, physical balance simulation or gameplay collision.','Blender preview; no headset performance test.','Blender workers require interruption after successful completion due to sandbox audio shutdown stall.','Original texture provenance discussion remains recorded in tools/ba2/SOURCES.md.']}
(ROOT/'docs/validation/ba2-walk.json').write_text(json.dumps(report,indent=2)+'\n')
for name in ['docs/BA2-WALK.md','tools/ba2/animated/README.md']:
    p=ROOT/name
    for link in re.findall(r'\]\(([^)]+)\)',p.read_text()):
        if not link.startswith('https:'):assert (p.parent/link).exists(),link
print('BA2_WALK_PREVIEW_AND_RECEIPT_COMPLETE',json.dumps(media))
