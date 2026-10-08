#!/usr/bin/env python3
"""Inspect the requested TF2 Classified archive without executing map scripts."""
import collections,hashlib,io,json,lzma,re,struct,zipfile
from pathlib import Path
HERE=Path(__file__).resolve().parent;LOCAL=HERE/'local'
def unpack(raw):
 if raw[:4]!=b'LZMA':return raw
 size,packed=struct.unpack_from('<II',raw,4);props=raw[12:17];v=props[0];lc=v%9;v//=9;lp=v%5;pb=v//5
 assert size<=128_000_000 and packed+17<=len(raw)
 out=lzma.LZMADecompressor(format=lzma.FORMAT_RAW,filters=[{'id':lzma.FILTER_LZMA1,'dict_size':struct.unpack_from('<I',props,1)[0],'lc':lc,'lp':lp,'pb':pb}]).decompress(raw[17:17+packed],max_length=size);assert len(out)==size;return out

def inspect(file):
 raw=file.read_bytes();assert raw[:4]==b'VBSP';version=struct.unpack_from('<i',raw,4)[0];lumps=[]
 for i in range(64):
  offset,length,ver,four=struct.unpack_from('<4i',raw,8+16*i);assert offset>=0 and length>=0 and offset+length<=len(raw)
  lumps.append(unpack(raw[offset:offset+length]))
 text=lumps[0].rstrip(b'\0').decode('latin1');entities=[]
 for block in re.findall(r'\{([^{}]*)\}',text):
  pairs=re.findall(r'"([^"\n]*)"\s*"([^"\n]*)"',block);entities.append(dict(pairs))
 counts=collections.Counter(e.get('classname','') for e in entities)
 objectives=[e for e in entities if e.get('classname') in ['item_teamflag','func_capturezone','team_control_point','trigger_capture_area','tf_logic_domination','tf_logic_hybrid_ctf','tf_logic_koth','tf_logic_territory_control','tf_logic_fourteam','tf_logic_dm']]
 spawns=collections.Counter(e.get('TeamNum','?') for e in entities if e.get('classname')=='info_player_teamspawn')
 packed=[]
 if lumps[40]:
  with zipfile.ZipFile(io.BytesIO(lumps[40])) as archive:packed=[i.filename for i in archive.infolist()]
 names=[lumps[43][at:].split(b'\0',1)[0].decode('latin1') for (at,) in struct.iter_unpack('<i',lumps[44])]
 present={p.lower().replace('\\','/') for p in packed};external=[n for n in names if 'materials/'+n.lower()+'.vmt' not in present]
 (LOCAL/(file.stem+'.entities.json')).write_text(json.dumps(entities,indent=2)+'\n')
 return {'name':file.stem,'source_sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw),'format':'Source VBSP','version':version,'entities':dict(counts),'spawn_teams':dict(spawns),'objective_entities':objectives,'material_count':len(names),'materials_not_in_pak':len(external),'external_material_examples':external[:12],'pak_entries':len(packed),'displacements':len(lumps[26])//176,'brushes':len(lumps[18])//12,'faces':len(lumps[7])//56,'status':'not_installed','blockers':['Current importer requires Quake BSP29; Source VBSP geometry, brush collision, displacements and material/lightmap structures need a dedicated converter.','Source game logic needs explicit translation to supported native TF objectives; silently replacing it with two-flag CTF would change the maps.','Source base-game materials and model dependencies are not all embedded in the archive.']}

def main():
 archive=LOCAL/'source.zip';raw=archive.read_bytes();assert hashlib.md5(raw).hexdigest()=='6980ba399bb57483bccbbcc71e426298'
 result={'source':'https://gamebanana.com/mods/712767','title':'Team Fortress 30th Anniversary Maps Archive','submitter':'Kalashnikov1947','download':'https://gamebanana.com/dl/1804759','archive_sha256':hashlib.sha256(raw).hexdigest(),'archive_bytes':len(raw),'maps':[inspect(p) for p in sorted(LOCAL.glob('*.bsp'))]}
 (HERE/'inspection.json').write_text(json.dumps(result,indent=2)+'\n')
 for r in result['maps']:print(r['name'],r['format'],r['version'],'teams',r['spawn_teams'],'materials',r['material_count'],'external',r['materials_not_in_pak'],'objectives',collections.Counter(e['classname'] for e in r['objective_entities']))
if __name__=='__main__':main()
