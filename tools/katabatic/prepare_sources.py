#!/usr/bin/env python3
"""Fetch pinned Tribes 2 survey inputs and extract geometry (Node 22+ required).

Original inputs/parser stay in local/, outside runtime assets. Render textures
come from the project's existing original Makkon/LibreQuake WAD records.
"""
from pathlib import Path
import hashlib,json,shutil,struct,subprocess,sys,urllib.request
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'tools'))
from makkon.theme import wad_textures

def main():
    local=HERE/'local';local.mkdir(exist_ok=True)
    refs=json.loads((HERE/'references.json').read_text())
    for name,row in refs['files'].items():
        path=local/name
        if not path.exists():
            url=f"https://raw.githubusercontent.com/exogen/t2-mapper/{refs['commit']}/{row['path']}"
            path.write_bytes(urllib.request.urlopen(url,timeout=60).read())
        assert hashlib.sha256(path.read_bytes()).hexdigest()==row['sha256'],name
    script="""import {parseDIF} from './dif.ts';
import {readFileSync,writeFileSync} from 'node:fs';
for (const name of ['sbunk2','svpad','smisc3','stowr6','stowr4']) {
 const b=readFileSync(name+'.dif');
 const d=parseDIF(b.buffer.slice(b.byteOffset,b.byteOffset+b.byteLength)).interiors[0];
 // Retain only geometry and material labels, never original lighting/textures.
 for (const key of ['lightMaps','normalLightMapIndices','alarmLightMapIndices']) delete d[key];
 writeFileSync(name+'.json',JSON.stringify(d));
}
"""
    subprocess.run(['node','--experimental-strip-types','--input-type=module','-'],input=script,text=True,cwd=local,check=True)
    out=ROOT/'maps/Katabatic';out.mkdir(exist_ok=True)
    records=wad_textures((ROOT/'maps/Raindance/raindance.wad').read_bytes())
    records.update(wad_textures((ROOT/'maps/Stonehenge/stonehenge.wad').read_bytes()))
    records.update(wad_textures((ROOT/'maps/KOTH/source/koth-used.wad').read_bytes()))
    raw=records['metal_iron1_01'];records['skip']=b'skip'+bytes(12)+raw[16:]
    names=['skip','snow1','med_rock10b','sky_star','ind_w02_grey1','ind_dp01_grey1','metal_iron1_01','ind_dp01_red1','ind_dp01_blu1']
    wad=bytearray(b'WAD2'+bytes(8));directory=[];sources={}
    provenance=json.loads((HERE/'texture-sources.json').read_text())
    for name in names:
        raw=records[name];directory.append(struct.pack('<iiiBBH16s',len(wad),len(raw),len(raw),68,0,0,name.encode()));wad.extend(raw)
        digest=hashlib.sha256(raw).hexdigest()
        if name=='skip':sources[name]={'source_record':'metal_iron1_01','sha256':digest,'format':'Renamed header; original four mip levels unchanged'}
        else:
            assert provenance[name]['sha256']==digest,name
            sources[name]=provenance[name]
    at=len(wad);wad.extend(b''.join(directory));struct.pack_into('<ii',wad,4,len(directory),at)
    (out/'katabatic.wad').write_bytes(wad);(out/'texture-sources.json').write_text(json.dumps(sources,indent=2)+'\n')
    for name in ['Makkon_License.txt','LibreQuake-COPYING.txt','LibreQuake-CREDITS.txt']:shutil.copyfile(ROOT/'maps/Pressureworks'/name,out/name)
    print('KATABATIC_SOURCES_READY',len(refs['files']),len(names))
if __name__=='__main__':main()
