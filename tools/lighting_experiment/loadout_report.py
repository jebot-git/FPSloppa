"""Summarize native loadout-lighting captures without altering their lighting."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import hashlib,json
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/weapon-emission-loadouts'
report=json.loads((OUT/'report.json').read_text())
assert not report['failures'],report['failures']
font_path=next(p for p in [Path('/usr/share/fonts/google-noto/NotoSans-Regular.ttf'),Path('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf')] if p.exists())
font=ImageFont.truetype(str(font_path),20)
selected=[('cs16 / M4A1',False),('tribes / PLASMA GUN',True),('tribes / LASER RIFLE',False),('tribes / REPAIR GUN',False),('tribes / HAND GRENADE',True),('tribes / TARGETING LASER',False)]
# Find CS title from the actual arsenal: avoid silently selecting a different gun.
for row in report['weapons']:
 if row['label'].startswith('cs16 / ') and 'M4A1' in row['label']:selected[0]=(row['label'],False)
canvas=Image.new('RGB',(1200,len(selected)*486),'#101820');draw=ImageDraw.Draw(canvas)
for i,(label,impact) in enumerate(selected):
 row=next(r for r in report['weapons'] if r['label']==label)
 stem=row['image'].removesuffix('-on.png')+('-impact' if impact else '')
 for j,mode in enumerate(['off','on']):
  im=Image.open(OUT/(stem+'-'+mode+'.png')).convert('RGB').resize((600,450),Image.Resampling.LANCZOS)
  canvas.paste(im,(j*600,i*486+36))
  draw.text((j*600+12,i*486+5),label+(' impact' if impact else '')+' / light '+mode,font=font,fill='white')
canvas.save(OUT/'comparison.jpg',quality=94)
summary=dict(date='2026-09-27',passed=True,weapon_cases=len(report['weapons']),graphical_checks=len(report['checks']),failures=[],effect_limit=report['effect_limit'],gpu=report['gpu'],renderer=report['renderer'],constraints='Existing shared two-source shader cap, 64 candidate cap, BSP/moving-brush occlusion and fail-dark traversal remain unchanged.',unchanged_files={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in ['deathmatch/lighting/weapon_pool.gd','deathmatch/lighting/weapon_light.gdshaderinc']},artifacts='test-results/weapon-emission-loadouts/')
regression=(OUT/'weapon-variants.log').read_text()
variant=json.loads(next(line.removeprefix('VARIANTS_RESULT ') for line in regression.splitlines() if line.startswith('VARIANTS_RESULT ')))
assert not variant['failures'] and 'SCRIPT ERROR' not in regression
vr=(OUT/'vr-projectiles.log').read_text()
assert 'PROJECTILE_PRESENTATION_RESULT []' in vr and 'SCRIPT ERROR' not in vr
summary['regressions']={'weapon_rules_and_demos':variant['checks'],'simulated_vr_projectile_presentation':sum(line.startswith('PASS ') for line in vr.splitlines())}
summary['runtime_notes']=['Simulated VR emits the existing PulseAudio microphone shutdown warning after its checks; native runs report ObjectDB cleanup warnings.']
(ROOT/'docs/validation/weapon-emission-loadouts-2026-09-27.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
