"""Repeat native parity/regressions; optionally benchmark the integrated paths."""
from pathlib import Path
import argparse, json, os, shutil, subprocess
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/native-implementation'

def prepare_server():
    prefix='res://test-results/native-implementation/'
    arena=(ROOT/'deathmatch/arena.gd').read_text().replace('if not multiplayer.get_peers().is_empty():\n\t\tvar packets:', 'if true:\n\t\tvar packets:')
    (OUT/'arena.gd').write_text(arena)
    (OUT/'profiled_arena.gd').write_text((ROOT/'deathmatch/tests/profiled_arena.gd').read_text().replace('res://deathmatch/arena.gd',prefix+'arena.gd'))
    fixture=(ROOT/'deathmatch/tests/server_load_audit.gd').read_text().replace('res://deathmatch/tests/profiled_arena.gd',prefix+'profiled_arena.gd')
    fixture=fixture.replace('func run():','func run():\n\tseed(20260928)')
    fixture=fixture.replace('\troot.add_child(g);Fixture.setup(g)','\tif args.has("--legacy-network"):g.replication=preload("res://deathmatch/tests/native_network_packing.gd").Legacy.new()\n\troot.add_child(g);Fixture.setup(g)')
    fixture=fixture.replace('var times: Array=[];', 'var combined: Array=[];var times: Array=[];')
    fixture=fixture.replace('\t\tvar before:=Time.get_ticks_usec();g._server_tick', '\t\tvar tick_start:=Time.get_ticks_usec()\n\t\tvar before:=Time.get_ticks_usec();g._server_tick')
    fixture=fixture.replace('\t\tif args.has("--memory") and tick%300==0:', '\t\tif tick>=120:combined.append((Time.get_ticks_usec()-tick_start)/1000.)\n\t\tif args.has("--memory") and tick%300==0:')
    fixture=fixture.replace('\ttimes.sort();snapshots.sort()', '\tcombined.sort()\n\tprint("COMBINED_RESULT ",JSON.stringify({"p50_ms":combined[combined.size()/2],"p95_ms":combined[int(combined.size()*.95)],"max_ms":combined.back(),"mean_ms":combined.reduce(func(a,b):return a+b,0.)/combined.size()}))\n\ttimes.sort();snapshots.sort()')
    (OUT/'server.gd').write_text(fixture)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bench',action='store_true',help='Also run paired server and rendered-avatar benchmarks')
    args=parser.parse_args();OUT.mkdir(parents=True,exist_ok=True)
    env=dict(os.environ,XDG_DATA_HOME='/tmp/fpsloppa-native')
    def run(label,script,flags=(),render=False):
        command=['godot',*([] if render else ['--headless']),'--xr-mode','off','--path',str(ROOT),'--script',script,'--',*flags,'--client-config','/tmp/fps-native.cfg']
        result=subprocess.run(command,cwd=ROOT,env=env,text=True,capture_output=True,timeout=120)
        text=result.stdout+result.stderr;(OUT/(label+'.log')).write_text(text)
        if result.returncode or 'SCRIPT ERROR' in text or 'FAIL ' in text:raise RuntimeError(label+' failed; see '+str(OUT/(label+'.log')))
        print(label,'PASS',flush=True);return text
    checks=[]
    for script in ['deathmatch/tests/native_acceleration.gd','deathmatch/tests/native_network_packing.gd','deathmatch/tests/hit_detection.gd','deathmatch/tests/projectile_targets.gd','deathmatch/tests/projectile_ordering.gd','deathmatch/tests/frame_smoothness.gd','deathmatch/tests/replication_protocol.gd','deathmatch/tests/de_cover.gd','tools/avatar_lod/test_animation.gd']:
        run(Path(script).stem,script);checks.append({'script':script,'ok':True})
    (OUT/'checks.json').write_text(json.dumps(checks,indent=2)+'\n')
    if not args.bench:return
    prepare_server();reports=[]
    for label,flags in [('reference-a',['--gdscript-projectiles','--legacy-network']),('native-a',[]),('native-b',[]),('reference-b',['--gdscript-projectiles','--legacy-network'])]:
        text=run('server-'+label,'test-results/native-implementation/server.gd',['16','--ticks','360','--profile',*flags]);row={'label':label}
        for line in text.splitlines():
            for prefix,key in [('SERVER_LOAD_RESULT ','load'),('SERVER_PROFILE_RESULT ','helpers'),('COMBINED_RESULT ','combined')]:
                if line.startswith(prefix):row[key]=json.loads(line[len(prefix):])
        reports.append(row)
    (OUT/'server.json').write_text(json.dumps(reports,indent=2)+'\n')
    for label,flags in [('reference',['--gdscript-poses']),('native',[])]:
        run('avatars-'+label,'tools/avatar_lod/frametime_study.gd',flags,render=True)
        shutil.copy2(ROOT/'test-results/frametime-study/avatars.json',OUT/('avatars-'+label+'.json'))
if __name__=='__main__':main()
