"""Build all seven World Leaders faces from a previous converter extraction job.
Uses locally installed BotPack Soldier geometry; does not download base-game files.
"""
import argparse,json
from pathlib import Path
from PIL import Image
from convert import read_mesh,write_avatar
from soldier_ik import build
p=argparse.ArgumentParser();p.add_argument('extraction',type=Path);p.add_argument('--output-dir',type=Path,default=Path('deathmatch/avatars/models/world_leaders'));args=p.parse_args()
d=json.loads(args.extraction.read_text());textures={Path(t).stem:Path(t) for t in d['textures']}
positions,corners,clips,reference=read_mesh(Path(d['mesh']),reference=25)
profile={'left':[[-.22,1.36,0],[-.34,1.14,-.10],[-.33,.97,-.24]],'right':[[.22,1.36,0],[.34,1.14,-.10],[.33,.97,-.24]]}
ik_data=build(positions,corners)
rows=[]
for key,name in [('jong-un','Jong-un'),('judastrump','Judas Trump'),('justintrudeau','Justin Trudeau'),('macron','Macron'),('netanyahu','Netanyahu'),('putin','Putin'),('xi','Xi')]:
    skins={i:Image.open(textures[t]) for i,t in enumerate(['dics1','dics2','dics3','dics4'+key])}
    output=args.output_dir/(key+'.utavatar')
    info=write_avatar(output,positions,corners,skins,clips,'World Leaders · '+name,'EvilGrins (skin); Epic Games (Soldier model)','Original UT99 / skin author terms; no CC0 claim',reference,profile,ik_data)
    info['source']='https://unrealarchive.org/unreal-tournament/skins/W/world-leaders_6ff65135.html'
    info['source_sha1']='6ff651356db4157631a9b0986bfd1eb579f2f602'
    info['path']='res://'+output.as_posix();rows.append(info)
manifest=Path('deathmatch/avatars/models/manifest.json')
existing=json.loads(manifest.read_text()) if manifest.exists() else []
rows += [row for row in existing if row.get('base_model')]
manifest.write_text(json.dumps(rows,indent=2)+'\n');print(json.dumps(rows,indent=2))
