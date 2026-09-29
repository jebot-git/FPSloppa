"""Profile current native/fallback boundaries in DM and ST without editing gameplay."""
from pathlib import Path
import argparse,hashlib,json,os,re,subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/native-current-study'
PREFIX='res://test-results/native-current-study/code/'
CHECKS=['native_preparation','native_bots','native_st_bots','native_acceleration',
 'native_codec','native_network_packing','native_rewind','native_shot_history',
 'st_tribes','tribes_physics','tribes_arsenal','st_targeting','st_vr_inventory',
 'st_vr_reliability','st_equipment_mounts','frame_smoothness','render_motion',
 'controller_tracking','weapon_wheel','cs16_feedback','cs16_vr_reload',
 'defusal_vr','dropped_weapons','shared_hit_feedback']
METHODS={
 'arena':['_server_tick','_collect','_update_projectiles','_trace_reference','_record_history','_update_melee','_configure_tribes','_send_snapshot'],
 'fighter':['simulate','step_up'],
 'hit_detection':['world_fraction','player_fraction'],
 'bots':['tick','perceive','plan','combat','steer','visible','choose_weapon','safe_shot'],
 'bot_ai/navigation':['path','cost','ray','jump_clear'],
 'bot_ai/tribes':['goals','combat','steer','steer_route','precision_steer','tower_approach','route_look','assign_roles'],
 'bot_ai/tribes_routes':['path','attach','nearby','clear'],
 'bot_ai/tribes_travel':['path'],
 'bot_ai/tribes_avoidance':['steer'],
 'bot_ai/tribes_tactics':['tick'],
 'bot_ai/tribes_offense':['tick'],
 'movement/tribes':['simulate','support'],
 'modes/match':['tick','snapshot'],
 'modes/tribes':['tick','snapshot'],
 'tribes/combat':['tick','tick_input','tick_projectile','beam','blast','trace_mines'],
 'tribes/deployables':['tick','trace'],
 'tribes/fixed_defences':['tick'],
 'tribes/stations':['tick','trace'],
 'tribes/base_assets':['tick'],
 'tribes/targeting':['tick','trace'],
 'vehicles/tribes/controller':['tick','trace'],
 'network/replication':['packets','receive','flush'],
}

def instrument(source,path,names):
    wrappers=[]
    for name in names:
        pattern=r'^(static )?func '+name+r'\(([^\n]*)\)(?:\s*->\s*([^:\n]+))?:'
        match=re.search(pattern,source,re.M)
        if not match:raise ValueError(path+': missing '+name)
        declaration=match.group(0);args=match.group(2)
        arguments=','.join(part.strip().split(':')[0].split('=')[0].strip() for part in args.split(',') if part.strip())
        # All chosen arguments use scalar/empty defaults; no comma-bearing defaults.
        body=re.split(r'^func |^static func ',source[match.end():],maxsplit=1,flags=re.M)[0]
        if 'await ' in body:raise ValueError('Async scope: '+path+'.'+name)
        returns=(match.group(3) or '').strip()
        has_result=returns!='void' if returns else bool(re.search(r'\breturn\s+[^\s;#]',body))
        call='study_original_'+name+'('+arguments+')'
        wrapper='\n'+declaration+'\n\tStudy.begin("'+path+'.'+name+'")\n'
        wrapper+='\tvar study_result'+(': '+returns if returns else ': Variant')+'='+call+'\n' if has_result else '\t'+call+'\n'
        wrapper+='\tStudy.end("'+path+'.'+name+'")\n'
        if has_result:wrapper+='\treturn study_result\n'
        wrappers.append(wrapper)
        source=source[:match.start()]+declaration.replace('func '+name+'(','func study_original_'+name+'(')+source[match.end():]
    return source+'\nconst Study=preload("res://tools/native_study/study_scopes.gd")\n'+''.join(wrappers)

def prepare():
    OUT.mkdir(parents=True,exist_ok=True)
    sources={str(p.relative_to(ROOT)):p.read_text() for p in (ROOT/'deathmatch').rglob('*') if p.suffix in ['.gd','.tscn','.tres']}
    selected={'deathmatch/'+p+'.gd' for p in METHODS}
    # Copy only the reverse dependency closure so map-created station scripts,
    # mode helpers and arena children all use the same instrumented instances.
    while True:
        more={p for p,s in sources.items() if any('res://'+dep in s for dep in selected)}-selected
        if not more:break
        selected.update(more)
    remap={'res://'+p:PREFIX+p for p in selected}
    for p in sorted(selected):
        s=sources[p];key=p.removeprefix('deathmatch/').removesuffix('.gd')
        if key in METHODS:s=instrument(s,key,METHODS[key])
        if key=='bot_ai/navigation':
            s=s.replace('if NavigationServer3D.map_get_closest_point(map,start).distance_to(start)>2.5:',
                'Study.begin("navigation.engine_closest")\n\tvar study_closest:=NavigationServer3D.map_get_closest_point(map,start)\n\tStudy.end("navigation.engine_closest")\n\tif study_closest.distance_to(start)>2.5:')
            s=s.replace('var result:=NavigationServer3D.map_get_path(map,start,goal,true,3 if allow_jump else 1)',
                'Study.begin("navigation.engine_path")\n\tvar result:=NavigationServer3D.map_get_path(map,start,goal,true,3 if allow_jump else 1)\n\tStudy.end("navigation.engine_path")')
        if key=='movement/tribes':
            s=s.replace('if actor.test_move(actor.global_transform,Vector3.DOWN*.045,contact,.001,true,4):',
                'Study.begin("movement/tribes.engine_support")\n\tvar study_supported:bool=actor.test_move(actor.global_transform,Vector3.DOWN*.045,contact,.001,true,4)\n\tStudy.end("movement/tribes.engine_support")\n\tif study_supported:')
            s=s.replace('var collision: KinematicCollision3D=actor.move_and_collide(travel,false,.001)',
                'Study.begin("movement/tribes.engine_move")\n\t\t\t\tvar collision: KinematicCollision3D=actor.move_and_collide(travel,false,.001)\n\t\t\t\tStudy.end("movement/tribes.engine_move")')
        if key=='hit_detection':
            s=s.replace('if not space.intersect_shape(query,1).is_empty(): return 0.0',
                'Study.begin("hit_detection.engine_overlap")\n\tvar study_contacts:=space.intersect_shape(query,1)\n\tStudy.end("hit_detection.engine_overlap")\n\tif not study_contacts.is_empty():return 0.0')
            s=s.replace('var fractions := space.cast_motion(query)',
                'Study.begin("hit_detection.engine_cast")\n\tvar fractions := space.cast_motion(query)\n\tStudy.end("hit_detection.engine_cast")')
        if key=='arena':s=s.replace('callv("_snapshot",state)', 'set_meta("study_snapshot",state)\n\tcallv("_snapshot",state)')
        if key=='fighter':
            s=s.replace('move_and_slide()','study_engine_slide()')
            s+='\nfunc study_engine_slide() -> bool:\n\tStudy.begin("fighter.engine_slide")\n\tvar result:=move_and_slide()\n\tStudy.end("fighter.engine_slide")\n\treturn result\n'
        s=re.sub(r'res://deathmatch/[^"\s)]+',lambda m:remap.get(m[0],m[0]),s)
        dest=OUT/'code'/p;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(s)
    (OUT/'generated.json').write_text(json.dumps(sorted(selected),indent=2)+'\n')

def run(label,script,flags=(),rendered=False,timeout=240,accelerate=False):
    OUT.mkdir(parents=True,exist_ok=True)
    command=['godot',*([] if rendered else ['--headless']),*(['--fixed-fps','60'] if accelerate else []),'--xr-mode','off','--path',str(ROOT),'--script',script,'--',*flags,'--client-config','/tmp/fps-native-current.cfg']
    with (OUT/(label+'.log')).open('w') as log:
        result=subprocess.run(command,cwd=ROOT,env=dict(os.environ,XDG_DATA_HOME='/tmp/fps-native-current'),stdout=log,stderr=subprocess.STDOUT,timeout=timeout)
    output=(OUT/(label+'.log')).read_text()
    if result.returncode or 'SCRIPT ERROR' in output or 'FAIL ' in output:raise RuntimeError(label+' failed; see '+str(OUT/(label+'.log')))
    for line in output.splitlines():
        if line.startswith('CURRENT_STUDY_RESULT '):
            report=json.loads(line.split(' ',1)[1]);(OUT/(label+'.json')).write_text(json.dumps(report,indent=2)+'\n')
    print(label,'PASS',flush=True)
    return output

def checks(resume=False):
    reports=json.loads((OUT/'checks.json').read_text()) if resume and (OUT/'checks.json').exists() else {}
    # Some existing suites expect their report directory to be prepared by a
    # release runner. Create only literal test-results destinations they use.
    for name in CHECKS:
        source=(ROOT/'deathmatch/tests'/ (name+'.gd')).read_text()
        for path in re.findall(r'FileAccess.open\("res://(test-results/[^"\n]+)"',source):
            (ROOT/path).parent.mkdir(parents=True,exist_ok=True)
    for name in CHECKS:
        if resume and name in reports:continue
        rendered=name=='st_vr_inventory'
        output=run('check-'+name,'deathmatch/tests/'+name+'.gd',['--vr-test'] if rendered else [],rendered=rendered,timeout=480,accelerate=name not in ['render_motion','native_preparation','native_bots','native_st_bots','native_acceleration'])
        rows=[]
        for line in output.splitlines():
            if ' {' in line:
                try:row=json.loads(line[line.index('{'):])
                except json.JSONDecodeError:continue
                if isinstance(row,dict) and 'failures' in row:
                    if row['failures']:raise RuntimeError(name+' has failures')
                    rows.append(row)
        reports[name]={'passed':True,'results':rows,'log_sha256':hashlib.sha256(output.encode()).hexdigest()}
        (OUT/'checks.json').write_text(json.dumps(reports,indent=2)+'\n')

def audit():
    base='8b19bd959e7dbf17cba1b201bb9f55d448f87614';checkpoint='07f727c'
    def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
    paths=git('diff','--name-only',base,checkpoint).decode().splitlines()
    current=set(git('ls-tree','-r','--name-only','HEAD').decode().splitlines())
    status={p:'missing' if p not in current else 'unchanged' if git('show',checkpoint+':'+p)==git('show','HEAD:'+p) else 'changed' for p in paths}
    (OUT/'main-path-audit.json').write_text(json.dumps(status,indent=2)+'\n')
    sys.path.insert(0,str(ROOT/'tools'));import build_gameplay_native as build
    libraries={}
    for platform,server in [('linux',False),('linux',True),('windows',False),('android',False)]:
        library=build.require_build(platform,server)
        libraries[platform+('-server' if server else '')]={'current':True,'sha256':hashlib.sha256(library.read_bytes()).hexdigest()}
    result={'head':git('rev-parse','HEAD').decode().strip(),'base':base,'checkpoint':checkpoint,'paths':len(paths),'counts':{kind:list(status.values()).count(kind) for kind in ['unchanged','changed','missing']},'libraries':libraries}
    (OUT/'audit.json').write_text(json.dumps(result,indent=2)+'\n')
    if result['counts']['missing']:raise RuntimeError('Missing main paths')
    print(json.dumps(result,indent=2))

def avatars():
    import remaining
    remaining.OUT=OUT/'avatars';remaining.OUT.mkdir(parents=True,exist_ok=True)
    remaining.PREFIX='res://test-results/native-current-study/avatars/';remaining.avatars()
    script=remaining.OUT/'avatars.gd'
    script.write_text(script.read_text().replace('test-results/remaining-native','test-results/native-current-study/avatars'))
    run('avatars','res://test-results/native-current-study/avatars/avatars.gd',rendered=True)

def main():
    p=argparse.ArgumentParser(description=__doc__)
    for flag in ['prepare','server','projectiles','avatars','checks','audit','control','fallback','resume']:p.add_argument('--'+flag,action='store_true')
    p.add_argument('--map',default='ctf_stonehenge');p.add_argument('--ticks',type=int,default=1200);p.add_argument('--warmup',type=int,default=300);args=p.parse_args()
    OUT.mkdir(parents=True,exist_ok=True)
    if args.prepare:prepare()
    if args.server:
        flags=[args.map,str(args.ticks),str(args.warmup),*(['--control'] if args.control else [])]
        run(args.map+('-control' if args.control else '-scopes'),'tools/native_study/current_server.gd',flags,timeout=360)
    if args.projectiles:run('projectiles-'+('fallback' if args.fallback else 'native'),'tools/native_study/current_projectiles.gd',['--gdscript-projectiles'] if args.fallback else [])
    if args.avatars:avatars()
    if args.checks:checks(args.resume)
    if args.audit:audit()
if __name__=='__main__':main()
