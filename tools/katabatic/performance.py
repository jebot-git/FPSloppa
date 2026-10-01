#!/usr/bin/env python3
"""Isolated Katabatic CPU attribution and AI ablations; never patches game sources."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import shutil
import statistics
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
METHODS = {
    'deathmatch/arena.gd': ['_server_tick', '_record_history', '_send_snapshot', '_update_projectiles'],
    'deathmatch/bots.gd': ['tick', 'perceive', 'plan', 'combat', 'steer'],
    'deathmatch/bot_ai/navigation.gd': ['path', 'update_jump_links'],
    'deathmatch/bot_ai/tribes.gd': ['goals', 'path', 'steer', 'steer_route', 'precision_steer'],
    'deathmatch/bot_ai/tribes_routes.gd': ['path', 'attach', 'clear'],
    'deathmatch/bot_ai/tribes_travel.gd': ['path', 'seconds'],
    'deathmatch/bot_ai/tribes_tactics.gd': ['tick'],
    'deathmatch/bot_ai/tribes_avoidance.gd': ['steer'],
    'deathmatch/modes/tribes.gd': ['tick'],
    'deathmatch/tribes/stations.gd': ['tick'],
    'deathmatch/tribes/fixed_defences.gd': ['tick'],
    'deathmatch/maps/runtime.gd': ['_physics_process'],
    'deathmatch/fighter.gd': ['simulate'],
}

def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p, data): p.write_text(json.dumps(data, indent=2) + '\n')
def stats(a):
    a=sorted(a)
    return dict(mean=statistics.mean(a),median=statistics.median(a),p95=a[int(len(a)*.95)],p99=a[int(len(a)*.99)],maximum=max(a))

def instrument(source, path, methods):
    source=source.replace('\n','\nconst KProfile=preload("res://kat_profile.gd")\n',1)
    for method in methods:
        pattern=rf'^func {method}\((.*)\)(\s*->\s*\w+)?\s*:(.*)$'
        match=re.search(pattern,source,re.M)
        assert match, (path,method)
        params,returns,inline=match.groups();returns=returns or ''
        names=[re.match(r'\s*(\w+)',p).group(1) for p in params.split(',')] if params else []
        call=f'__kat_original_{method}('+','.join(names)+')'
        label=path.removeprefix('deathmatch/').removesuffix('.gd')+'.'+method
        wrapper=f'\nfunc {method}({params}){returns}:\n\tvar kat_start:=Time.get_ticks_usec()\n'
        if returns.strip()=='-> void':
            wrapper+=f'\t{call}\n\tKProfile.add("{label}",Time.get_ticks_usec()-kat_start)\n'
        else:
            wrapper+=f'\tvar kat_result:Variant={call}\n\tKProfile.add("{label}",Time.get_ticks_usec()-kat_start)\n\treturn kat_result\n'
        source=source[:match.start()]+match.group(0).replace('func '+method+'(', 'func __kat_original_'+method+'(',1)+source[match.end():]+wrapper
    return source

def prepare(project, profiled, detailed=False):
    project.mkdir(exist_ok=False)
    for p in ROOT.iterdir():
        if p.name.startswith('.') or p.name in ('Builds','project.godot','deathmatch'):continue
        (project/p.name).symlink_to(p,target_is_directory=p.is_dir())
    # Directory mirror permits changing a few isolated scripts without following symlinks.
    for directory, dirs, files in os.walk(ROOT/'deathmatch'):
        rel=Path(directory).relative_to(ROOT);dest=project/rel;dest.mkdir(parents=True,exist_ok=True)
        for name in files:(dest/name).symlink_to(Path(directory)/name)
    cache=project/'.godot';cache.mkdir()
    for name in ['global_script_class_cache.cfg','uid_cache.bin']:shutil.copy2(ROOT/'.godot'/name,cache/name)
    (cache/'imported').symlink_to(ROOT/'.godot/imported',target_is_directory=True)
    (cache/'extension_list.cfg').write_text('res://addons/fps_native/fps_native.gdextension\nres://addons/twovoip/twovoip.gdextension\n')
    settings=(ROOT/'project.godot').read_text()
    settings=re.sub(r'run/main_scene=.*','run/main_scene="res://kat_driver.tscn"',settings)
    settings=re.sub(r'\[autoload\].*?(?=\[)','',settings,flags=re.S)
    (project/'project.godot').write_text(settings)
    shutil.copy2(ROOT/'Builds/ClientTemplates/linux.x86_64',project/'FPSloppa')
    (project/'kat_profile.gd').write_text('''extends RefCounted
static var us:Dictionary={}
static var calls:Dictionary={}
static var plans:Array=[]
static var queries:Array=[]
static var planning_bot:=0
static func add(label:String,elapsed:int):
 us[label]=int(us.get(label,0))+elapsed
 calls[label]=int(calls.get(label,0))+1
static func reset():us.clear();calls.clear();plans.clear();queries.clear()
static func planned(ai,id:int,elapsed:int):
 add("plan_bot."+str(id),elapsed)
 if elapsed<1000:return
 var b:Dictionary=ai.brains[id];var actor=ai.game.fighters[id]
 plans.append({"id":id,"us":elapsed,"goal":b.goal_key,"position":str(actor.position),"speed":actor.velocity.length(),"path_size":b.path.size(),"step":b.step,"next_point":str(b.path[b.step]) if b.step<b.path.size() else "none"})
static func closest(map:RID,point:Vector3)->Vector3:
 var start:=Time.get_ticks_usec()
 var result:=NavigationServer3D.map_get_closest_point(map,point)
 var elapsed:=Time.get_ticks_usec()-start
 add("engine.closest_point",elapsed)
 if elapsed>=500:queries.append({"kind":"closest","id":planning_bot,"us":elapsed,"start":str(point)})
 return result
static func nav_path(map:RID,from:Vector3,to:Vector3,optimize:bool,layers:int=1)->PackedVector3Array:
 var start:=Time.get_ticks_usec()
 var result:=NavigationServer3D.map_get_path(map,from,to,optimize,layers)
 var elapsed:=Time.get_ticks_usec()-start
 add("engine.nav_get_path",elapsed)
 if elapsed>=500:queries.append({"kind":"path","id":planning_bot,"us":elapsed,"start":str(from),"goal":str(to),"points":result.size(),"reaches_goal":not result.is_empty() and result[-1].distance_to(to)<=2})
 if result.is_empty():calls["engine.nav_empty"]=int(calls.get("engine.nav_empty",0))+1
 return result
static func terrain_path(graph:AStar3D,from:int,to:int)->PackedVector3Array:
 var start:=Time.get_ticks_usec()
 var result:=graph.get_point_path(from,to)
 add("engine.terrain_astar",Time.get_ticks_usec()-start)
 return result
''')
    paths=set(METHODS) if profiled else set()
    paths.add('deathmatch/bots.gd')
    for path in paths:
        source=(ROOT/path).read_text()
        if path=='deathmatch/bots.gd':
            source=source.replace('func tick(delta: float) -> void:\n','func tick(delta: float) -> void:\n\tif Engine.get_meta("kat_ai_disabled",false):return\n')
            source=source.replace('func plan(id: int,brain: Dictionary) -> void:\n','func plan(id: int,brain: Dictionary) -> void:\n\tif Engine.get_meta("kat_planning_disabled",false):return\n')
        if profiled:source=instrument(source,path,METHODS[path])
        if detailed:
            source=source.replace('NavigationServer3D.map_get_closest_point(', 'KProfile.closest(')
            source=source.replace('NavigationServer3D.map_get_path(', 'KProfile.nav_path(')
            source=source.replace('graph.get_point_path(', 'KProfile.terrain_path(graph,')
            if path=='deathmatch/bots.gd':
                source=source.replace('\t__kat_original_plan(id,brain)\n', '\tKProfile.planning_bot=id\n\t__kat_original_plan(id,brain)\n\tKProfile.planning_bot=0\n')
                source=source.replace('\tKProfile.add("bots.plan",Time.get_ticks_usec()-kat_start)\n', '\tKProfile.add("bots.plan",Time.get_ticks_usec()-kat_start)\n\tKProfile.planned(self,id,Time.get_ticks_usec()-kat_start)\n')
        dest=project/path;dest.unlink();dest.write_text(source)
    driver=(ROOT/'deathmatch/tests/bot_soak.gd').read_text()
    driver=driver.replace('extends SceneTree\n','extends Node\nvar root:Window\nconst KProfile=preload("res://kat_profile.gd")\n',1)
    driver=driver.replace('func _initialize():run.call_deferred()','func _ready():\n root=get_tree().root\n run.call_deferred()')
    driver=driver.replace('await physics_frame','await get_tree().physics_frame').replace('await process_frame','await get_tree().process_frame')
    driver=re.sub(r'(?<![\w.])quit\(', 'get_tree().quit(', driver)
    driver=driver.replace('clampi(int(options.get("bots",8)),3,31)','clampi(int(options.get("bots",8)),0,31)')
    driver=driver.replace(' for id in range(-4,-bot_count-1,-1):',
        ' for id in game.players.keys():\n  if id<0 and -id>bot_count:game._peer_left(id)\n for id in range(-4,-bot_count-1,-1):')
    driver=driver.replace(' var profile_tick: bool=', ' var profile_rows:Array=[]\n var loop_begin:=Time.get_ticks_usec()\n var profile_tick: bool=')
    old='''  if profile_tick:
   var began:=Time.get_ticks_usec()
   game._physics_process(1.0/60)
   if game.clock-start>30:ticks.append((Time.get_ticks_usec()-began)/1000.0)'''
    new='''  if profile_tick:
   var now:=Time.get_ticks_usec()
   var loop_ms:=float(now-loop_begin)/1000.0;loop_begin=now
   var background:Dictionary=KProfile.us.duplicate()
   KProfile.reset()
   if options.get("no_plan",false) and game.clock-start>=30:Engine.set_meta("kat_planning_disabled",true)
   if options.get("idle",false) and game.clock-start>=30:
    Engine.set_meta("kat_ai_disabled",true)
    for state in game.players.values():
     state.move=Vector2.ZERO;state.room=Vector3.ZERO;state.swim=Vector3.ZERO;state.last_input=game.clock
     for field in ["fire","alt_fire","offhand_fire","jump","jet_held","jetpack","ski","melee","physical","jump_pending"]:state[field]=false
     state.fire_pending=[];state.fire_queue=[]
   var began:=Time.get_ticks_usec()
   game._physics_process(1.0/60)
   var elapsed:=float(Time.get_ticks_usec()-began)/1000.0
   if game.clock-start>30:
    ticks.append(elapsed)
    profile_rows.append({"time":game.clock-start,"game_ms":elapsed,"loop_ms":loop_ms,"parts_us":KProfile.us.duplicate(),"calls":KProfile.calls.duplicate(),"background_us":background,"plans":KProfile.plans.duplicate(),"queries":KProfile.queries.duplicate()})
   KProfile.reset()'''
    assert old in driver
    driver=driver.replace(old,new)
    driver=driver.replace(' result.physics_backend=', ' result.profile_rows=profile_rows\n result.navigation_polygons=game.bots.region.navigation_mesh.get_polygon_count()\n result.route_points=game.bots.tribes.routes.points.size()\n result.physics_backend=')
    (project/'kat_driver.gd').write_text(driver)
    (project/'kat_driver.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://kat_driver.gd" id="1"]\n[node name="KatabaticCPU" type="Node"]\nscript=ExtResource("1")\n')

def run(project, out, name, bots, idle=False, seconds=90, no_plan=False):
    options=dict(map='ctf_katabatic',mode='st',rules='tribes',bots=bots,idle=idle,seconds=seconds,no_plan=no_plan,
        profile_tick=True,seed=20261001,output=str(out/(name+'.json')))
    print('START',name,flush=True)
    with (out/(name+'.log')).open('w') as log:
        code=subprocess.run([str(project/'FPSloppa'),'--headless','--xr-mode','off','--fixed-fps','60','--',
            json.dumps(options),'--asset-root',str(ROOT),'--client-config','/tmp/fps-katabatic-ablation.cfg','--no-avatar-disk-cache'],
            cwd=project,env=dict(os.environ,XDG_DATA_HOME='/tmp/fps-katabatic-ablation-user'),stdout=log,stderr=subprocess.STDOUT,timeout=240).returncode
    log=(out/(name+'.log')).read_text()
    assert code==0 and not any(s in log for s in ['ERROR:','WARNING:','leaked']), (name,code,log[-2500:])
    data=json.loads((out/(name+'.json')).read_text());rows=data['profile_rows']
    assert data['physics_backend']=='JoltPhysicsDirectSpaceState3D' and len(data['bots'])==bots and data['simulated_seconds']>=seconds
    assert len(rows)>=int((seconds-30)*60)
    labels=sorted({k for row in rows for k in row['parts_us']})
    tail=[r for r in rows if r['game_ms']>=stats([r['game_ms'] for r in rows])['p95']]
    report=dict(case=name,bots=bots,idle=idle,no_plan=no_plan,samples=len(rows),game_ms=stats([r['game_ms'] for r in rows]),
        loop_ms=stats([r['loop_ms'] for r in rows]),polygons=data['navigation_polygons'],route_points=data['route_points'],
        distance=sum(b['distance'] for b in data['bots'].values()),shots=sum(b['shots'] for b in data['bots'].values()),
        parts={k:dict(ms=stats([r['parts_us'].get(k,0)/1000 for r in rows]),calls=sum(r['calls'].get(k,0) for r in rows),
            tail_mean_ms=statistics.mean(r['parts_us'].get(k,0)/1000 for r in tail)) for k in labels},
        background={k:stats([r['background_us'].get(k,0)/1000 for r in rows]) for k in sorted({k for r in rows for k in r['background_us']})})
    print('DONE',name,json.dumps({k:report[k] for k in ['game_ms','loop_ms','distance','shots']}),flush=True)
    return report

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);parser.add_argument('--smoke',action='store_true')
    parser.add_argument('--detail-only',action='store_true')
    args=parser.parse_args();out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
    tag=str(time.time_ns());plain=Path('/tmp/fps-kat-plain-'+tag);profile=Path('/tmp/fps-kat-profile-'+tag)
    if args.detail_only:
        METHODS['deathmatch/bot_ai/navigation.gd']+=['cost','project_local','hazardous']
        METHODS['deathmatch/bots.gd']+=['cover_goals','boost_route']
        METHODS['deathmatch/tribes/stations.gd']+=['recover_pack']
    prepare(plain,False);prepare(profile,True,args.detail_only)
    sources={p.relative_to(ROOT).as_posix():digest(p) for p in (ROOT/'deathmatch').rglob('*.gd')}
    manifest=dict(source_sha256=sources,projects=dict(plain=str(plain),profile=str(profile)),runtime_sha256=digest(plain/'FPSloppa'),
        map_sha256=digest(ROOT/'maps/ctf_katabatic.bsp'),native_sha256=digest(ROOT/'addons/fps_native/bin/libfpsloppa_native.so'),instrumented_methods=METHODS)
    save(out/'manifest.json',manifest)
    reports=[]
    cases=[('profile-smoke',profile,16,False)] if args.smoke else [
        ('full16-a',plain,16,False),('empty-a',plain,0,False),('idle16-a',plain,16,True),('active8-a',plain,8,False),
        ('profile16-a',profile,16,False),('profile16-b',profile,16,False),
        ('active8-b',plain,8,False),('idle16-b',plain,16,True),('empty-b',plain,0,False),('full16-b',plain,16,False)]
    if args.detail_only:cases=[('detail16-a',profile,16,False),('no-plan16-a',plain,16,False),('no-plan16-b',plain,16,False),('detail16-b',profile,16,False)]
    for name,project,bots,idle in cases:
        reports.append(run(project,out,name,bots,idle,35 if args.smoke else 90,name.startswith('no-plan')));save(out/'summary.json',reports)
    for p,sha in sources.items():assert digest(ROOT/p)==sha, 'Production source changed: '+p
    print('COMPLETE',out,flush=True)

if __name__=='__main__':main()
