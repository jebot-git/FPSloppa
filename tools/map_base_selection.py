"""Curate base catalog/rotations; optional and player-owned files are never deleted."""
from pathlib import Path
import json,hashlib,re
ROOT=Path(__file__).resolve().parents[1]
QUAKE=['qsrc_dm'+str(i) for i in range(1,8)]
CC=['cc_hyperborea','cc_psychofuge','cc_ghostquarter','cc_basement']
CTF=['ctf_tideworks','ctf_crucible','ctf_confluence','ctf_deepvault','ctf_crownreach','ctf_skyfracture']
def update():
 p=ROOT/'deathmatch/maps/manifest.json';rows=json.loads(p.read_text());new_ids=QUAKE+CTF;rows=[r for r in rows if r['id'] not in new_ids]
 for r in rows:
  if re.fullmatch('lqdm[0-9]+',r['id']):r.update(distribution='optional',expansion='librequake',modes=['dm','tdm','ig','ft','cc','ctf'])
  elif r['id'].startswith('dm_'):r.update(distribution='optional',expansion='community')
  else:r['distribution']='base'
 for id in QUAKE:
  src=ROOT/'maps/Quake/sources/adapted'/(id+'.map');title=re.search(r'"message"\s+"([^"]+)"',src.read_text())[1]
  rows.append({'id':id,'title':title,'distribution':'base','modes':['dm','tdm','ig','ft'],'path':'res://maps/'+id+'.bsp','scene':'res://maps/cache/'+id+'.scn','sha256':hashlib.sha256((ROOT/'maps'/(id+'.bsp')).read_bytes()).hexdigest()})
 for id in CTF:
  m=json.loads((ROOT/'maps/CTFStudies'/id/'manifest.json').read_text())
  def q(p):return [-p[1]/32,p[2]/32-.7,-p[0]/32]
  red,blue=map(q,m['flags']);rows.append({'id':id,'title':m['title'].split(' | ')[0],'distribution':'base','modes':['ctf'],'path':'res://maps/'+id+'.bsp','scene':'res://maps/cache/'+id+'.scn','sha256':m['sha256'],'objectives':{'red':red,'blue':blue,'hill':[(red[i]+blue[i])/2 for i in range(3)]}})
 p.write_text(json.dumps(rows,indent=2)+'\n')
 for mode in ['dm','tdm','ig','ft']:(ROOT/'maps'/(mode+'_maplist.txt')).write_text('\n'.join(QUAKE)+'\n')
 (ROOT/'maps/cc_maplist.txt').write_text('\n'.join(CC)+'\n');(ROOT/'maps/ctf_maplist.txt').write_text('\n'.join(CTF)+'\n')
if __name__=='__main__':update()
