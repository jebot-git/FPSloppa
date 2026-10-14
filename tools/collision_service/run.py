"""Build and evaluate the isolated native collision rewrite on the real map.

No live server/network changes. Outputs stay under --output; Godot user data
is redirected there. A failed parity gate remains a failed gate in report.json.
"""
import argparse, collections, csv, hashlib, json, math, os, platform, shutil, struct, subprocess
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
SHAPE = struct.Struct('<III20d')
TAIL = struct.Struct('<3dIddi9dI')

def distribution(values):
    if not values: return {}
    values = sorted(values)
    return {'samples': len(values), 'mean': sum(values)/len(values), 'p50': values[len(values)//2],
            'p95': values[int(len(values)*.95)], 'p99': values[int(len(values)*.99)], 'max': values[-1]}

def traces(path):
    data = path.read_bytes()
    if data[:8] != b'CQTRACE2': raise ValueError('trace version mismatch')
    count, = struct.unpack_from('<I', data, 8)
    if len(data) != 12+count*(SHAPE.size+TAIL.size): raise ValueError('trace size mismatch')
    rows=[]
    for i in range(count):
        start = 12+i*(SHAPE.size+TAIL.size)
        s = SHAPE.unpack_from(data, start); t = TAIL.unpack_from(data, start+SHAPE.size)
        rows.append({'kind': s[0], 'start': s[3:6], 'delta': t[:3], 'hit': bool(t[3]),
                     'safe': t[4], 'unsafe': t[5], 'id': t[6], 'normal': t[7:10],
                     'position': t[10:13], 'velocity': t[13:16], 'scenario': t[16]})
    return rows

def compare(query_rows, path, metadata):
    categories=collections.defaultdict(collections.Counter); failures=[]; moves=[]; velocities=[]
    results=list(csv.DictReader(path.open()))
    if len(query_rows)!=len(results): raise ValueError('incomplete native results')
    for i,(q,r) in enumerate(zip(query_rows,results)):
        scenario=metadata['scenarios'][q['scenario']]; c=categories[scenario];c['total']+=1
        hit=r['hit']=='1'; distance=math.sqrt(sum(x*x for x in q['delta']))
        error=0.;reason=None
        if r['converged']!='1':c['unresolved']+=1;reason='unresolved'
        if q['kind']==5:
            error=math.dist(q['position'],[float(r[k]) for k in ['px','py','pz']]);moves.append(error)
            velocity_error=math.dist(q['velocity'],[float(r[k]) for k in ['vx','vy','vz']]);velocities.append(velocity_error)
            if velocity_error>.05:c['velocity_mismatch']+=1;reason=reason or 'velocity'
            if error>.03:c['position_mismatch']+=1;reason=reason or 'position'
            if bool(int(r['grounded']))!=q['hit']:c['support_mismatch']+=1;reason=reason or 'support'
        else:
            if q['hit'] and not hit:c['missed_hit']+=1;reason=reason or 'missed_hit'
            elif not q['hit'] and hit:c['extra_hit']+=1;reason=reason or 'extra_hit'
            elif hit:
                f=float(r['fraction']); low=q['safe'];high=q['safe'] if q['kind']==0 else q['unsafe']
                error=max(low-f,f-high,0)*distance
                if error>.01:c['fraction_mismatch']+=1;reason=reason or 'fraction'
                if q['kind']==0:
                    if q['id']!=-1 and int(r['id'])!=q['id']:c['id_mismatch']+=1;reason=reason or 'id'
                    # Compare contact direction too (including zero inside normals).
                    if math.dist(q['normal'],[float(r[k]) for k in ['nx','ny','nz']])>.02:
                        c['normal_mismatch']+=1;reason=reason or 'normal'
        if reason:
            c['failed']+=1
            failures.append({'index':i,'scenario':scenario,'reason':reason,'error_m':error,
                             'expected_safe':q['safe'],'expected_unsafe':q['unsafe'],
                             'actual_fraction':float(r['fraction']),'expected_hit':q['hit'],'actual_hit':hit,
                             'expected_id':q['id'],'actual_id':int(r['id']),
                             'start':q['start'],'delta':q['delta']})
    return {'pass':not failures,'failed_cases':len(failures),'cases':len(results),
            'by_scenario':dict(categories),'movement_position_error_m':distribution(moves),'movement_velocity_error_m_s':distribution(velocities),'failures':failures}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output',type=Path,default=Path('/tmp/cq-collision-experiment'))
    p.add_argument('--skip-export',action='store_true')
    p.add_argument('--require-parity',action='store_true',help='Exit 1 unless compatibility gates pass (default: complete evaluation, retain failed gates)')
    p.add_argument('--repeats',type=int,default=12)
    p.add_argument('--godot',default='godot')
    a=p.parse_args()
    if not 1 <= a.repeats <= 1000:p.error('--repeats must be 1..1000')
    out=a.output.resolve();out.mkdir(parents=True,exist_ok=True)
    native=ROOT/'tools/collision_service/native'
    def run(command,log,env=None):
        with (out/log).open('w') as f:subprocess.run(list(map(str,command)),cwd=ROOT,env=env,stdout=f,stderr=subprocess.STDOUT,check=True,timeout=180)
    for name in ['tests','suite']:
        run(['g++','-std=c++17','-O3','-ffp-contract=off','-Wall','-Wextra','-Wpedantic',
             '-Wno-mismatched-new-delete','-pthread',native/(name+'.cpp'),'-o',out/name],name+'-build.log')
    run([out/'tests'],'unit.json')
    if not a.skip_export:
        cache=out/'user-data/godot/app_userdata/FPSloppa';cache.mkdir(parents=True,exist_ok=True)
        fingerprint=''.join(hashlib.sha256((ROOT/'tools/voxel_battle'/f'{n}.gd').read_bytes()).hexdigest()
                            for n in ['landscape','architecture','outer_architecture','hydrology','waterways'])
        name='jungle-heightmap-'+hashlib.sha256(fingerprint.encode()).hexdigest()[:16]+'.res'
        existing=Path.home()/'.local/share/godot/app_userdata/FPSloppa'/name
        if existing.exists():shutil.copyfile(existing,cache/name)
        env=dict(os.environ,XDG_DATA_HOME=str(out/'user-data'))
        run([a.godot,'--headless','--xr-mode','off','--path',ROOT,'--script','tools/collision_service/export_suite.gd',
             '--','--world',out/'world.bin','--traces',out/'traces.bin','--metadata',out/'oracle.json'],'oracle.log',env)
        log=(out/'oracle.log').read_text()
        if 'COLLISION_ORACLE ' not in log or 'ERROR:' in log:raise RuntimeError('Oracle incomplete or engine/script error; see oracle.log')
    metadata=json.loads((out/'oracle.json').read_text())
    if len(metadata.get('movement_tick_deltas',[]))!=64 or any(abs(x-1/30)>1e-6 for x in metadata['movement_tick_deltas']):
        raise RuntimeError('Movement oracle must contain 64 real 30 Hz physics ticks')
    query_rows=traces(out/'traces.bin');benchmarks=[];parity=None;stable=True;reference=None
    for batch in [32,64]:
        for workers in [1,2,4]:
            stem=f'batch-{batch}-workers-{workers}';csv_path=out/(stem+'.csv')
            run([out/'suite',out/'world.bin',out/'traces.bin',csv_path,workers,a.repeats,batch],stem+'.json')
            result=json.loads((out/(stem+'.json')).read_text());benchmarks.append(result)
            if parity is None:parity=compare(query_rows,csv_path,metadata)
            data=csv_path.read_bytes()
            if reference is None:reference=data
            else:stable &= data==reference
            print('COLLISION_BATCH',batch,workers,result['by_kind'],flush=True)
    oracle_batches={}
    for batch in [32,64]:
        oracle_batches[str(batch)]={}
        for key,values in metadata['timings'].items():
            samples=values.get('per_query_ms',[])
            oracle_batches[str(batch)][key]=distribution([sum(samples[i:i+batch]) for i in range(0,len(samples)-batch+1,batch)])
    malformed=[]
    world_data=(out/'world.bin').read_bytes();trace_data=(out/'traces.bin').read_bytes()
    width,depth=struct.unpack_from('<II',world_data,8);object_offset=56+4*width*depth
    bad_shape=bytearray(world_data);struct.pack_into('<I',bad_shape,object_offset,4)
    bad_basis=bytearray(world_data);struct.pack_into('<d',bad_basis,object_offset+76,2.)
    bad_heights=bytearray(world_data);struct.pack_into('<f',bad_heights,56,float('nan'))
    for label,data in [('bad-magic',b'notworld'),('truncated',b'CQCOLL1\0'),
                       ('invalid-shape',bad_shape),('invalid-basis',bad_basis),('nonfinite-height',bad_heights),
                       ('excessive-grid',b'CQCOLL1\0'+struct.pack('<IId3dII',0xffffffff,0xffffffff,1,0,0,0,0,0))]:
        file=out/(label+'.bin');file.write_bytes(data)
        process=subprocess.run([str(out/'suite'),str(file),str(out/'traces.bin'),str(out/'invalid.csv'),'1','1','64'],capture_output=True,timeout=10)
        malformed.append({'case':label,'rejected':process.returncode==2})
    # Keep environment/source identity alongside raw timing samples.
    environment={'platform':platform.platform(),'cpu_count':os.cpu_count(),
                 'cpu_model':next((line.split(':',1)[1].strip() for line in Path('/proc/cpuinfo').read_text().splitlines() if line.startswith('model name')),'unknown'),
                 'compiler':subprocess.check_output(['g++','--version'],text=True).splitlines()[0],
                 'engine':(out/'oracle.log').read_text().splitlines()[0],
                 'source_sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()
                                  for p in sorted((ROOT/'tools/collision_service').rglob('*')) if p.is_file() and p.suffix in ['.py','.cpp','.hpp','.gd']}}
    report={'environment':environment,'unit':json.loads((out/'unit.json').read_text()),'oracle':metadata,'parity':parity,
            'parallel_results_identical':stable,'malformed_input':malformed,'benchmarks':benchmarks,
            'oracle_serial_batch_sums_ms':oracle_batches,
            'promotion_pass':parity['pass'] and stable and all(x['rejected'] for x in malformed),
            'not_implemented':['coupled dynamic actor island commit','moving support transport','gameplay water/road integration','live server or client-prediction binding','expanded direct-Jolt gameplay/controller coverage'],
            'production_enabled':False,
            'tolerances':{'ray_distance_m':.01,'ray_normal_vector_distance':.02,'sweep_bracket_slack_m':.01,
                          'movement_position_m':.03,'movement_velocity_m_s':.05,'movement_support':'exact'},
            'limitations':['local CPU kernel/query benchmark; not VPS frametimes','native request preparation is outside hot query timings',
                           'oracle timings include engine query parameter setup','controller oracle covers isolated static slide/snap; authored stair fixtures are native tests',
                           'recovery uses candidate escape directions, not general EPA','performance does not override failed correctness gates'],
            'input_sha256':{n:hashlib.sha256((out/n).read_bytes()).hexdigest() for n in ['world.bin','traces.bin']}}
    report['promotion_pass'] &= not report['not_implemented']
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print('COLLISION_SUITE_RESULT',json.dumps({'unit':report['unit'],'parity_failures':parity['failed_cases'],
                                              'stable':stable,'promotion_pass':report['promotion_pass']}))
    if a.require_parity and (not parity['pass'] or not stable or not all(x['rejected'] for x in malformed)):raise SystemExit(1)
if __name__=='__main__':main()
