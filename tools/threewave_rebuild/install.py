"""Register the six authored CTF maps while preserving other catalog entries."""
from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parents[2]
def main():
    path=ROOT/'deathmatch/maps/manifest.json';rows=json.loads(path.read_text());ids=[]
    maps=sorted((json.loads(p.read_text()) for p in (ROOT/'maps/CTFStudies').glob('ctf_*/manifest.json')),key=lambda r:r['original_reference'])
    assert len(maps)==6
    for m in maps:
        key=m['id'];digest=hashlib.sha256((ROOT/'maps'/(key+'.bsp')).read_bytes()).hexdigest();assert digest==m['sha256'];ids.append(key)
        def point(p):return [-p[1]/32,p[2]/32-.7,-p[0]/32]
        row={'id':key,'modes':['ctf'],'objectives':{'red':point(m['flags'][0]),'blue':point(m['flags'][1])},'path':'res://maps/'+key+'.bsp','scene':'res://maps/cache/'+key+'.scn','sha256':digest,'title':m['title']}
        old=next((r for r in rows if r['id']==key),None)
        if old:old.update(row)
        else:rows.append(row)
    path.write_text(json.dumps(rows,indent=2)+'\n')
    path=ROOT/'maps/ctf_maplist.txt';other=[s for s in path.read_text().splitlines() if s and not s.startswith('#') and s not in ids]
    path.write_text('# CTF rotation: authored original-series studies.\n'+'\n'.join(ids+other)+'\n')
    print('Registered',', '.join(ids))
if __name__=='__main__':main()
