"""Keep ordinary base rotations independent of the separately installed expansion."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[2]
rows=[r for r in json.loads((ROOT/'deathmatch/maps/manifest.json').read_text()) if r.get('distribution','base')=='base']
for mode in ['dm','tdm','ig','if','ft','cc','ctf','koth','as','tf','tb','de','st']:
 names=[r['id'] for r in rows if mode in r['modes'] or mode=='if' and 'ig' in r['modes']]
 (ROOT/'maps'/(mode+'_maplist.txt')).write_text('\n'.join(names)+'\n')
