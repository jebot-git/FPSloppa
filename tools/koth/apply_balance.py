"""Apply verified spawn/weapon entities without recompiling geometry or lighting."""
from pathlib import Path
import hashlib,json,re,sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/makkon'))
from theme import lumps,repack

def entities(text):
    return re.findall(r'\{[^{}]*\}',text)
def fields(text):
    return dict(re.findall(r'"([^"\n]+)"\s*"([^"\n]*)"',text))
def entity(kind,point):
    origin=(-point[2]*32,-point[0]*32,(point[1]+.7)*32)
    return '{\n"classname" "'+kind+'"\n"origin" "'+' '.join(f'{x:.6f}' for x in origin)+'"\n}'
def change(text,map_id,balance):
    result=[]
    for block in entities(text):
        f=fields(block);kind=f.get('classname','')
        if kind.startswith('info_player_team') or kind in ['info_player_start','info_player_deathmatch']:continue
        if map_id=='koth_solstice' and kind=='weapon_supershotgun' and f.get('origin','').split()[:2]==['432','-1824']:
            block=re.sub(r'"origin"\s*"[^"]+"','"origin" "463.796160 -1869.782085 104.811200"',block)
        result.append(block)
    for i,row in enumerate(balance['starts']):
        point=row['position']
        result += [entity('info_player_deathmatch',point),entity('info_player_team'+str(balance['teams'][i]+1),point)]
    result.append(entity('info_player_start',balance['starts'][0]['position']))
    return '\n'.join(result)+'\n'
def main():
    balances=json.loads((ROOT/'tools/koth/balance.json').read_text())
    catalog=json.loads((ROOT/'deathmatch/maps/manifest.json').read_text());receipts=[]
    for map_id,balance in balances.items():
        path=ROOT/'maps'/(map_id+'.bsp');old=path.read_bytes();parts,extra=lumps(old)
        updated=parts.copy();updated[0]=(change(parts[0].decode('ascii').rstrip('\0'),map_id,balance)+'\0').encode('ascii')
        data=repack(updated,extra);assert lumps(data)[0][1:]==parts[1:] and lumps(data)[1]==extra
        path.write_bytes(data)
        # Generated .map contains brush blocks, so change only point entities.
        source=ROOT/'maps/KOTH/source'/(map_id+'.map');text=source.read_text()
        point_blocks=[b for b in entities(text) if fields(b).get('classname','')!='worldspawn' and '\n(' not in b and not re.search(r'^\s*\(',b,re.M)]
        changed=change('\n'.join(point_blocks),map_id,balance)
        for block in point_blocks:text=text.replace(block,'',1)
        source.write_text(text.rstrip()+'\n'+changed)
        sha=hashlib.sha256(data).hexdigest()
        for row in catalog:
            if row['id']==map_id:row['sha256']=sha;row['size']=len(data)
        receipts.append(dict(map=map_id,before_sha256=hashlib.sha256(old).hexdigest(),sha256=sha,starts=len(balance['starts']),geometry_textures_visibility_lighting_unchanged=True))
    (ROOT/'deathmatch/maps/manifest.json').write_text(json.dumps(catalog,indent=2)+'\n')
    (ROOT/'docs/validation/koth-balance-entities.json').write_text(json.dumps(receipts,indent=2)+'\n')
    print(json.dumps(receipts))
if __name__=='__main__':main()
