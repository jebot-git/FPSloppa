"""Convert separately obtained Quake TF maps for local non-commercial FPSloppa use.
No original TF geometry is included. Do not redistribute resulting BSPs.
"""
from pathlib import Path
import argparse,hashlib,json,zipfile,struct,re
from texture_replace import wad_textures,convert
BASE=Path(__file__).resolve().parent
ALLOWED={'2fort5','well6'}
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('archives',nargs='+',type=Path);p.add_argument('--output',required=True,type=Path);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
 donors=wad_textures(BASE/'librequake.wad');report=[]
 for archive in a.archives:
  with zipfile.ZipFile(archive) as z:
   for entry in z.infolist():
    stem=Path(entry.filename).stem.lower()
    if Path(entry.filename).suffix.lower()!='.bsp' or stem not in ALLOWED:continue
    if entry.file_size>128_000_000:raise SystemExit('BSP exceeds transfer size limit')
    dest=a.output/('tf_original_'+stem+'.bsp')
    if dest.exists():raise SystemExit('Refusing to overwrite '+str(dest))
    raw=z.read(entry);data,textures=convert(raw,donors)
    off,size=struct.unpack_from('<ii',data,4);entities=data[off:off+size].decode('latin1')
    if 'item_tfgoal' not in entities or 'info_player_teamspawn' not in entities:raise SystemExit('Unsupported TF map objective schema')
    # Original deathmatch spawns were not designed for TF and can intersect walls.
    # Replace only those fallback spawn entities with the map's native team spawns.
    blocks=re.findall(r'\{[^{}]*\}',entities);kept=[];spawn_keys=set();fallbacks=[]
    for block in blocks:
     fields=dict(re.findall(r'"([^"\n]+)"\s*"([^"\n]*)"',block));kind=fields.get('classname','')
     if kind=='info_player_deathmatch':continue
     if kind=='info_player_teamspawn':
      key=(fields.get('team_no'),fields.get('origin'),fields.get('angle','0'))
      if key in spawn_keys:continue
      spawn_keys.add(key);fallbacks.append('{\n"classname" "info_player_deathmatch"\n"origin" "'+fields['origin']+'"\n"angle" "'+fields.get('angle','0')+'"\n}')
     kept.append(block)
    payload=('\n'.join(kept+fallbacks)+'\n\0').encode('utf-8')
    struct.pack_into('<ii',data,4,len(data),len(payload));data.extend(payload)
    dest.write_bytes(data)
    notices=[]
    for n in z.infolist():
     if Path(n.filename).suffix.lower()=='.txt' and n.file_size<1_000_000:
      target=a.output/(stem+'-original-'+Path(n.filename).name);target.write_bytes(z.read(n));notices.append(target.name)
    report.append({'id':dest.stem,'original_archive_sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'original_sha256':hashlib.sha256(raw).hexdigest(),'sha256':hashlib.sha256(data).hexdigest(),'textures':textures,'original_notices':notices,'redistributable':False})
    print('LOCAL CONVERSION',dest.name)
 (a.output/'TF-local-conversion.json').write_text(json.dumps(report,indent=2)+'\n')
 (a.output/'tf_maplist.txt').write_text(''.join(row['id']+'\n' for row in report))
if __name__=='__main__':main()
