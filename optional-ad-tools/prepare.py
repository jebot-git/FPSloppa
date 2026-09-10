"""Prepare local-only AD arena candidates. Geometry and embedded art retain AD rights."""
from pathlib import Path
import argparse,collections,hashlib,json,re,struct,sys
from archive import entries
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'optional-threewave-tools'))
from convert import wad_textures,donor
MAX_BYTES=25_000_000

def entities(raw):
 return [dict(re.findall(r'"([^"\n]+)"\s*"([^"\n]*)"',block)) for block in re.findall(r'\{[^{}]*\}',raw.decode('latin1'))]
def entity_bytes(rows):
 return ('\n'.join('{\n'+'\n'.join('"'+str(k).replace('"','')+'" "'+str(v).replace('"','')+'"' for k,v in row.items())+'\n}' for row in rows)+'\n\0').encode('latin1','replace')
def unpack(raw):return [raw[o:o+n] for o,n in [struct.unpack_from('<II',raw,4+i*8) for i in range(15)]]
def pack(version,lumps,rgb=None):
 out=bytearray(124);struct.pack_into('<I',out,0,version)
 for i,data in enumerate(lumps):
  out.extend(b'\0'*((-len(out))%4));struct.pack_into('<II',out,4+i*8,len(out),len(data));out.extend(data)
 if rgb:
  out.extend(b'\0'*((-len(out))%4));start=len(out);out.extend(b'BSPX'+struct.pack('<I',1)+b'RGBLIGHTING'.ljust(24,b'\0')+struct.pack('<II',start+40,len(rgb))+rgb)
 return out

def fill_textures(data,donors):
 count=struct.unpack_from('<i',data)[0];out=bytearray(4+4*count);struct.pack_into('<i',out,0,count);report=[]
 for i in range(count):
  offset=struct.unpack_from('<i',data,4+i*4)[0]
  if offset<0:
   name='missing'+str(i);source=donors['med_csl_brk7_2'];row=bytearray(source);row[:16]=name.encode().ljust(16,b'\0');report.append({'slot':i,'replacement':'med_csl_brk7_2','reason':'absent texture'})
  else:
   name=data[offset:offset+16].split(b'\0')[0].decode('latin1');w,h,*mips=struct.unpack_from('<6I',data,offset+16)
   if w<1 or h<1 or w>2048 or h>2048:raise ValueError('Invalid texture dimensions')
   if all(m>=40 and offset+m+max(1,w>>j)*max(1,h>>j)<=len(data) for j,m in enumerate(mips)):
    row=data[offset:offset+max(m+max(1,w>>j)*max(1,h>>j) for j,m in enumerate(mips))]
   else:
    source_name=donor(name);source=donors[source_name];sw,sh=struct.unpack_from('<II',source,16);row=bytearray(40);row[:16]=name.encode().ljust(16,b'\0');struct.pack_into('<II',row,16,w,h)
    for j in range(4):
     struct.pack_into('<I',row,24+j*4,len(row));at=struct.unpack_from('<I',source,24+j*4)[0];dw,dh=max(1,w>>j),max(1,h>>j);sx,sy=max(1,sw>>j),max(1,sh>>j)
     row.extend(source[at+(y*sy//dh)*sx+x*sx//dw] for y in range(dh) for x in range(dw))
    report.append({'slot':i,'name':name,'replacement':source_name,'reason':'external texture pixels'})
  struct.pack_into('<i',out,4+i*4,len(out));out.extend(row)
 return out,report

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('archive',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
 content=entries(a.archive);donors=wad_textures(Path(__file__).resolve().parents[1]/'optional-threewave-tools/librequake.wad');manifest=[]
 for name,raw in sorted(content.items()):
  if not name.startswith('maps/') or name.count('/')!=1 or not name.endswith('.bsp'):continue
  stem=Path(name).stem
  if 'test' in stem:continue
  lumps=unpack(raw);original=entities(lumps[0]);version=struct.unpack_from('<I',raw)[0];classes=collections.Counter(e.get('classname','') for e in original)
  report={'id':'ad_arena_'+stem,'source_map':stem,'original_sha256':hashlib.sha256(raw).hexdigest(),'original_bytes':len(raw),'redistributable':False,'classes':dict(classes),'removed':{},'missing_art':[],'status':'candidate'}
  world=original[0].copy();world['message']='AD / '+world.get('message',stem).split('\\n')[0]+' / Arena';world['_fpsloppa_bake']='1';world['_fpsloppa_ad']='1';world['_fpsloppa_atlas']='4096' if len(lumps[8])+len(lumps[7])*2>2400000 else '2048'
  for k in ['wad','sky','skyname','skybox','fog','sounds']:world.pop(k,None)
  kept=[world];points=[];removed=collections.Counter();missing=collections.Counter()
  for e in original[1:]:
   kind=e.get('classname','');model=e.get('model','')
   if 'origin' in e and (kind.startswith(('monster_','item_','weapon_','info_player')) or kind=='path_corner'):
    try:
     point=[float(v) for v in e['origin'].split()]
     if len(point)==3:points.append(point)
    except ValueError:pass
   if model.startswith('*') and kind in ['func_wall','func_illusionary','func_train','func_plat','func_rotate_object','func_detail']:
    row={k:v for k,v in e.items() if k in ['model','origin','angle','angles','alpha']};row['classname']='func_illusionary' if kind=='func_illusionary' else 'func_wall';kept.append(row)
   elif kind.startswith('light'):
    row={k:v for k,v in e.items() if k in ['origin','angle','light','_color','color']};row['classname']='light';kept.append(row)
    if any(s in kind for s in ['candle','flame','torch']):row['_fpsloppa_fixture']='flame2' if 'walltorch' in kind else 'flame'
   else:
    removed[kind]+=1
    for key in ['model','mdl','noise','noise1','noise2']:
     resource=e.get(key,'')
     if resource and not resource.startswith('*') and '/' in resource:missing[resource]+=1
  report['removed']=dict(removed);report['missing_art']=[{'path':k,'instances':v,'policy':'game-native pickup/effects or omitted non-gameplay prop; routes must validate'} for k,v in missing.items()]
  lumps[0]=entity_bytes(kept);lumps[2],report['texture_replacements']=fill_textures(lumps[2],donors)
  # Godot never consumes Quake PVS. Remove it and mark leaf vis offsets unavailable.
  lumps[4]=b'';leaves=bytearray(lumps[10]);stride=44 if version!=29 else 28
  for at in range(0,len(leaves),stride):struct.pack_into('<i',leaves,at+4,-1)
  lumps[10]=leaves
  lit=content.get('maps/'+stem+'.lit',b'');rgb=lit[8:] if lit[:4]==b'QLIT' and len(lit)==8+3*len(lumps[8]) else None
  output=pack(version,lumps,rgb)
  if len(output)>MAX_BYTES:output=pack(version,lumps);report['lighting']='original monochrome bake (RGB omitted to fit cap)'
  else:report['lighting']='embedded original RGB' if rgb else 'original monochrome bake'
  records={1:20,3:12,6:40,7:28 if version!=29 else 20,12:8 if version!=29 else 4,13:4,14:64}
  excessive=[i for i,stride in records.items() if len(lumps[i])//stride>262144]
  if len(output)>MAX_BYTES or excessive:
   report['status']='excluded';report['reason']=f'After removing PVS: {len(output)} bytes; excessive geometry lumps {excessive}. Game limits retained.'
  else:
   dest=a.output/'candidates'/(report['id']+'.bsp');dest.parent.mkdir(exist_ok=True);temporary=dest.with_suffix('.bsp.tmp');temporary.write_bytes(output);temporary.replace(dest)
   (dest.with_suffix('.json')).write_text(json.dumps({'report':report,'points':points},indent=2))
  report['candidate_bytes']=len(output);manifest.append(report);print(report['id'],report['status'],len(output),flush=True)
 for name,data in content.items():
  if name.endswith('.txt') and not name.startswith(('sound/','progs/')):
   notice=a.output/'notices'/name;notice.parent.mkdir(parents=True,exist_ok=True);notice.write_bytes(data)
 for name in ['ad_v1_80_readme.txt','ad_v1_80_credits.txt','ad_v1_80_documentation.txt']:
  if name in content:(a.output/name).write_bytes(content[name])
 (a.output/'inventory.json').write_text(json.dumps({'archive_sha256':hashlib.sha256(a.archive.read_bytes()).hexdigest(),'maps':manifest,'excluded_test_maps':[n for n in content if n.startswith('maps/') and n.count('/')==1 and n.endswith('.bsp') and 'test' in n]},indent=2))
if __name__=='__main__':main()
