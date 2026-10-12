"""Conservative, offline VRM feasibility probe. Never overwrites an input avatar.

Cache + fetch only: keep all vertices, every attribute/morph stream, primitive
boundaries, node/mesh/material indices and all extension JSON. Appended buffers
deliberately favour inspectability over disk size; this is not a production packer.
Needs NumPy and a locally built upstream meshoptimizer shared library.
"""
import argparse,copy,ctypes,hashlib,json,struct,subprocess,time
from collections import Counter
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/meshoptimizer'
SIZES={5120:1,5121:1,5122:2,5123:2,5125:4,5126:4}
COMPONENTS={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
DTYPES={5120:'i1',5121:'u1',5122:'<i2',5123:'<u2',5125:'<u4',5126:'<f4'}
def load(path):
    raw=path.read_bytes();size=struct.unpack_from('<I',raw,12)[0]
    return json.loads(raw[20:20+size]),raw[28+size:]
def save(path,doc,binary):
    blob=json.dumps(doc,separators=(',',':')).encode();blob+=b' '*(-len(blob)%4)
    binary+=b'\0'*(-len(binary)%4)
    path.write_bytes(struct.pack('<III',0x46546c67,2,28+len(blob)+len(binary))+struct.pack('<II',len(blob),0x4e4f534a)+blob+struct.pack('<II',len(binary),0x004e4942)+binary)
def read(doc,binary,index):
    a=doc['accessors'][index];assert 'sparse' not in a,'Sparse accessors need a separate expansion path'
    v=doc['bufferViews'][a['bufferView']];assert v.get('buffer',0)==0
    width=SIZES[a['componentType']]*COMPONENTS[a['type']]
    return np.ndarray((a['count'],width),dtype='u1',buffer=binary,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',width),1)).copy()
def add(doc,binary,source,rows,target):
    binary+=b'\0'*(-len(binary)%4);offset=len(binary);binary+=rows.tobytes()
    view=len(doc['bufferViews']);doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':rows.nbytes,'target':target})
    accessor=copy.deepcopy(source);accessor['bufferView']=view;accessor.pop('byteOffset',None)
    index=len(doc['accessors']);doc['accessors'].append(accessor);return index
class CacheStats(ctypes.Structure):
    _fields_=[('vertices_transformed',ctypes.c_uint),('warps_executed',ctypes.c_uint),('acmr',ctypes.c_float),('atvr',ctypes.c_float)]
def optimize(path,library):
    doc,source=load(path);result=copy.deepcopy(doc);binary=bytearray(source);rows=[];checks=0;started=time.monotonic()
    u32=ctypes.POINTER(ctypes.c_uint);library.meshopt_optimizeVertexCache.argtypes=[u32,u32,ctypes.c_size_t,ctypes.c_size_t]
    library.meshopt_optimizeVertexFetchRemap.argtypes=[u32,u32,ctypes.c_size_t,ctypes.c_size_t];library.meshopt_optimizeVertexFetchRemap.restype=ctypes.c_size_t
    library.meshopt_analyzeVertexCache.argtypes=[u32,ctypes.c_size_t,ctypes.c_size_t,ctypes.c_uint,ctypes.c_uint,ctypes.c_uint];library.meshopt_analyzeVertexCache.restype=CacheStats
    pointer=lambda array:array.ctypes.data_as(u32)
    for mi,mesh in enumerate(doc['meshes']):
        for pi,p in enumerate(mesh['primitives']):
            assert p.get('mode',4)==4 and 'indices' in p
            count=doc['accessors'][p['attributes']['POSITION']]['count']
            idx_a=doc['accessors'][p['indices']];indices=np.frombuffer(read(doc,source,p['indices']).tobytes(),dtype=DTYPES[idx_a['componentType']]).astype('<u4');assert len(indices)%3==0 and indices.max()<count
            reordered=indices.copy();transparent=doc['materials'][p['material']].get('alphaMode','OPAQUE')=='BLEND'
            if not transparent:library.meshopt_optimizeVertexCache(pointer(reordered),pointer(indices),len(indices),count)
            remap=np.empty(count,dtype='<u4');used=library.meshopt_optimizeVertexFetchRemap(pointer(remap),pointer(reordered),len(indices),count)
            # Keep unreferenced vertices too: no bounds/stream count change.
            unreferenced=np.flatnonzero(remap==0xffffffff);remap[unreferenced]=np.arange(used,count,dtype='<u4');inverse=np.argsort(remap)
            assert Counter(map(tuple,indices.reshape(-1,3)))==Counter(map(tuple,inverse[remap[reordered]].reshape(-1,3)));checks+=1
            final=remap[reordered];dest=result['meshes'][mi]['primitives'][pi]
            streams=[(p['attributes'],dest['attributes'])]+list(zip(p.get('targets',[]),dest.get('targets',[])))
            for original,target in streams:
                for semantic,index in original.items():
                    values=read(doc,source,index);assert len(values)==count
                    optimized=values[inverse];assert np.array_equal(optimized[remap],values);checks+=1
                    target[semantic]=add(result,binary,doc['accessors'][index],optimized,34962)
            scalar=copy.deepcopy(idx_a);scalar['componentType']=5125;scalar['min']=[int(final.min())];scalar['max']=[int(final.max())]
            dest['indices']=add(result,binary,scalar,final.view('u1').reshape(-1,4),34963)
            before=library.meshopt_analyzeVertexCache(pointer(indices),len(indices),count,16,32,256)
            after=library.meshopt_analyzeVertexCache(pointer(final),len(final),count,16,32,256)
            rows.append({'mesh':mi,'primitive':pi,'vertices':count,'triangles':len(indices)//3,'morph_targets':len(p.get('targets',[])),'transparent_order_preserved':transparent,'acmr_before':before.acmr,'acmr_after':after.acmr,'transforms_before':before.vertices_transformed,'transforms_after':after.vertices_transformed})
    # No application references change: VRM 0.x/1.0 JSON is kept verbatim.
    for key in ['nodes','skins','materials','textures','images','extensions','extensionsUsed','extensionsRequired','animations','scenes','scene']:
        assert result.get(key)==doc.get(key);checks+=1
    result['buffers'][0]['byteLength']=len(binary)
    output=OUT/(path.stem+'-conservative.vrm');save(output,result,binary)
    return {'model':path.name,'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'output_sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'source_bytes':path.stat().st_size,'output_bytes':output.stat().st_size,'checks':checks,'processing_seconds':time.monotonic()-started,'surfaces':rows,'simulated_transforms_before':sum(r['transforms_before'] for r in rows),'simulated_transforms_after':sum(r['transforms_after'] for r in rows)}
def cache_only(path,library):
    # Patch index bytes in a local copy. All original JSON and vertex/morph bytes
    # remain byte-identical, and alpha-blended primitives retain triangle order.
    doc,binary=load(path);raw=bytearray(path.read_bytes());allowed=np.zeros(len(raw),dtype=bool)
    base=28+struct.unpack_from('<I',raw,12)[0];checks=0;surfaces=0
    references=Counter(p['indices'] for m in doc['meshes'] for p in m['primitives'])
    for mesh in doc['meshes']:
        for p in mesh['primitives']:
            if doc['materials'][p['material']].get('alphaMode','OPAQUE')=='BLEND' or references[p['indices']]!=1:continue
            accessor=doc['accessors'][p['indices']];count=doc['accessors'][p['attributes']['POSITION']]['count']
            values=np.frombuffer(read(doc,binary,p['indices']).tobytes(),dtype=DTYPES[accessor['componentType']]).astype('<u4');out=np.empty_like(values)
            pointer=lambda array:array.ctypes.data_as(ctypes.POINTER(ctypes.c_uint))
            library.meshopt_optimizeVertexCache(pointer(out),pointer(values),len(values),count)
            assert Counter(map(tuple,values.reshape(-1,3)))==Counter(map(tuple,out.reshape(-1,3)));checks+=1
            view=doc['bufferViews'][accessor['bufferView']];offset=base+view.get('byteOffset',0)+accessor.get('byteOffset',0)
            width=SIZES[accessor['componentType']];stride=view.get('byteStride',width);packed=out.astype(DTYPES[accessor['componentType']]).tobytes()
            for i in range(len(out)):
                raw[offset+i*stride:offset+i*stride+width]=packed[i*width:(i+1)*width];allowed[offset+i*stride:offset+i*stride+width]=True
            surfaces+=1
    original=np.frombuffer(path.read_bytes(),dtype='u1');changed=np.frombuffer(raw,dtype='u1')
    assert np.array_equal(original[~allowed],changed[~allowed]);checks+=1
    output=OUT/(path.stem+'-cache-only.vrm');output.write_bytes(raw)
    assert load(output)[0]==doc;checks+=1
    return {'output_sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw),'changed_bytes':int(np.count_nonzero(original!=changed)),'optimized_primitives':surfaces,'checks':checks,'all_non_index_bytes_identical':True,'transparent_triangles_unchanged':True}
def packers(path):
    doc,_=load(path);rows=[]
    for repo in ['zeux','infosia']:
        tool=ROOT/('external-tools/meshoptimizer-'+repo+'/gltfpack');input_path=OUT/(path.stem+'.glb');input_path.write_bytes(path.read_bytes())
        output=OUT/(path.stem+'-'+repo+'.glb');command=[str(tool),'-i',str(input_path),'-o',str(output),'-kn','-km','-ke','-noq']
        run=subprocess.run(command,capture_output=True,text=True)
        record={'repository':repo,'returncode':run.returncode,'stderr':run.stderr}
        if run.returncode==0:
            try:
                packed,_=load(output);record.update({'valid_json':True,'extensions':list(packed.get('extensions',{})),'nodes_before':len(doc['nodes']),'nodes_after':len(packed['nodes']),'meshes_before':len(doc['meshes']),'meshes_after':len(packed['meshes'])})
                vrm=packed.get('extensions',{}).get('VRM');record['vrm_present']=vrm is not None
                if vrm:
                    bones=vrm.get('humanoid',{}).get('humanBones',[]);mismatches=[]
                    for bone in bones:
                        index=bone.get('node',-1);old=next((b['node'] for b in doc['extensions']['VRM']['humanoid']['humanBones'] if b['bone']==bone['bone']),-1)
                        original=doc['nodes'][old].get('name') if old>=0 else None
                        actual=packed['nodes'][index].get('name') if 0<=index<len(packed['nodes']) else None
                        if original!=actual:mismatches.append({'bone':bone['bone'],'expected':original,'actual':actual,'index':index})
                    record['humanoid_reference_mismatches']=mismatches
                    record['vrm_extension_identical']=vrm==doc['extensions']['VRM']
            except (ValueError,KeyError) as error:record.update({'valid_json':False,'parse_error':str(error)})
        rows.append(record)
    return rows
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--library',type=Path,default=ROOT/'external-tools/meshoptimizer-zeux/libmeshoptimizer-eval.so');args=parser.parse_args();OUT.mkdir(exist_ok=True,parents=True)
    library=ctypes.CDLL(str(args.library));results=[]
    for name in 'dfg':
        path=ROOT/('vrm/sample_'+name+'.vrm');row=optimize(path,library);row['cache_only']=cache_only(path,library);row['gltfpack']=packers(path);results.append(row);print(name,row['checks'],row['simulated_transforms_before'],row['simulated_transforms_after'],flush=True)
    (OUT/'evaluation.json').write_text(json.dumps({'upstream_commit':subprocess.check_output(['git','-C',str(ROOT/'external-tools/meshoptimizer-zeux'),'rev-parse','HEAD'],text=True).strip(),'fork_commit':subprocess.check_output(['git','-C',str(ROOT/'external-tools/meshoptimizer-infosia'),'rev-parse','HEAD'],text=True).strip(),'scope':'Offline lossless cache/fetch reorder, per-vertex byte checks including every morph stream; simulated cache metrics are not measured GPU timings. Packers tested with named nodes/materials, extras and quantization disabled.','models':results},indent=2)+'\n')
