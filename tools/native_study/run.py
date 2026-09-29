"""Run sequential probes; all output/settings live outside user game data."""
from pathlib import Path
import hashlib, json, os, platform, statistics, subprocess, sys

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/native-study'
subprocess.run([sys.executable,str(ROOT/'tools/native_study/prepare.py')],check=True)
env=dict(os.environ,XDG_DATA_HOME='/tmp/fpsloppa-native-study')
base=['godot','--headless','--xr-mode','off','--path',str(ROOT),'--script']
config=['--client-config','/tmp/fpsloppa-native-study.cfg']

def execute(label, command):
    result=subprocess.run(command,cwd=ROOT,env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=60)
    (OUT/(label+'.log')).write_text(result.stdout)
    if result.returncode or 'SCRIPT ERROR' in result.stdout:
        print(result.stdout[-6000:]);raise RuntimeError(label)
    return result.stdout

runs=[]
for label,count,instrumented,extra in [
    ('baseline16a',16,False,[]),('packets16a',16,True,['--packets']),
    ('packets8vr',8,True,['--packets','--vr']),
    ('packets16b',16,True,['--packets']),('baseline16b',16,False,[])]:
    script='test-results/native-study/server.gd' if instrumented else 'deathmatch/tests/server_load_audit.gd'
    output=execute(label,base+[script,'--',str(count),'--ticks','360','--profile']+extra+config)
    row={'label':label,'instrumented':instrumented,'args':extra,'scopes':{}}
    for line in output.splitlines():
        for prefix,key in [('SERVER_LOAD_RESULT ','load'),('SERVER_PROFILE_RESULT ','helpers')]:
            if line.startswith(prefix):row[key]=json.loads(line[len(prefix):])
        if line.startswith('NATIVE_SCOPE '):
            scope=json.loads(line[len('NATIVE_SCOPE '):]);row['scopes'][scope['scope']]=scope
    assert 'load' in row and 'helpers' in row
    row['shutdown_warnings']=[x for x in output.splitlines() if x.startswith(('WARNING:','ERROR:'))]
    runs.append(row);print(label, json.dumps(row['load']),flush=True)
execute('box',base+['tools/native_study/box_probe.gd','--']+config)
compiler=['g++','-O3','-std=c++17','-ffp-contract=off','-Wall','-Wextra','tools/native_study/box_probe.cpp','-o',str(OUT/'box_probe')]
subprocess.run(compiler,cwd=ROOT,check=True)
result=subprocess.run([str(OUT/'box_probe'),str(OUT/'boxes.bin')],check=True,text=True,capture_output=True)
(OUT/'cpp-box.json').write_text(result.stdout)
cpp=json.loads(result.stdout);gd=json.loads((OUT/'gdscript-box.json').read_text())
report={'date':'2026-09-28','machine':platform.platform(),'compiler':subprocess.check_output(['g++','--version'],text=True).splitlines()[0],'compiler_flags':compiler[1:6], 'server':runs,'box':{'gdscript':gd,'cpp':cpp,'median_speed_ratio':statistics.median(gd['milliseconds'])/statistics.median(cpp['milliseconds'])},'client_receipt':'frame-smoothness-2026-09-28.json','limitations':['Native kernel is standalone, without GDExtension calls or data conversion.','Server is a synthetic fixture with no AI, real map complexity or remote network transport.','Instrumented scopes include timer overhead and warmup; nested scopes must not be added together.','Baseline snapshot timing skips packet construction because there are no remote peers.','CPU clocks are not controlled. Client measurements are from the earlier same-day rendered study; no new client native implementation was tested.']}
report['source_sha256']={name:hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in ['deathmatch/arena.gd', 'deathmatch/hit_detection.gd', 'deathmatch/projectile_targets.gd', 'deathmatch/network/codec.gd', 'deathmatch/network/snapshot_codec.gd', 'deathmatch/network/replication.gd', 'deathmatch/avatars/pose.gd', 'deathmatch/avatars/pose_blend.gd']}
(OUT/'results.json').write_text(json.dumps(report,indent=2)+'\n')
print('box median ratio:',report['box']['median_speed_ratio'], 'mismatches:',cpp['mismatches'])
