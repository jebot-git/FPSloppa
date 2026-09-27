"""Audit/fix persisted texture import policy. Run --fix before Godot --editor --import.
Fresh imports inherit project.godot's texture defaults. Existing .import files
need this migration; checked-in runtime metadata also preserves it on checkout.
"""
from pathlib import Path
import argparse,json,re
ROOT=Path(__file__).resolve().parents[1]
ROOTS=['deathmatch','addons/godot-xr-tools/hands','addons/godot-xr-tools/images','addons/godot-xr-tools/assets','textures']
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--fix',action='store_true');args=ap.parse_args()
    rows=[];missing=[]
    for folder in ROOTS:
        for path in sorted((ROOT/folder).rglob('*.import')):
            text=path.read_text()
            if 'importer="texture"' not in text:continue
            settings=[('mipmaps/generate','true'),('mipmaps/limit','-1')]
            # These shared controller normal maps must renormalize every level.
            # Do not rely on the editor opening a material to auto-detect them.
            if 'godot-xr-tools/hands/textures' in path.as_posix() and path.name.endswith('_normal.png.import'):
                settings.append(('compress/normal_map','1'))
            correct=all(key+'='+value in text for key,value in settings)
            if not correct:
                missing.append(str(path.relative_to(ROOT)))
                if args.fix:
                    for key,value in settings:
                        if re.search('^'+re.escape(key)+'=',text,re.M):text=re.sub('^'+re.escape(key)+'=.*$',key+'='+value,text,flags=re.M)
                        else:text=text.replace('[params]','[params]\n\n'+key+'='+value)
                    path.write_text(text)
            rows.append({'path':str(path.relative_to(ROOT)),'mipmaps':correct or args.fix,'normal_map':len(settings)>2})
    dest=ROOT/'test-results/mipmaps';dest.mkdir(parents=True,exist_ok=True)
    (dest/'imports.json').write_text(json.dumps({'textures':rows,'fixed' if args.fix else 'missing':missing},indent=2)+'\n')
    print(f'{len(rows)} texture imports audited; {len(missing)} '+('fixed' if args.fix else 'missing mip policy'))
    raise SystemExit(bool(missing) and not args.fix)
if __name__=='__main__':main()
