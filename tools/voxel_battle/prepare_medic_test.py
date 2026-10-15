"""Prepare an isolated, loopback-only native CQ medic scenario; --check verifies it headlessly.
Default leaves only the local server running and writes an executable run-client.sh.
It never restarts a deployed service or launches VR without --xr.
"""
import argparse,datetime,json,os,shlex,signal,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from build_gameplay_native import require_build

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--port',type=int,default=27779)
    group=p.add_mutually_exclusive_group();group.add_argument('--check',action='store_true');group.add_argument('--xr',action='store_true')
    roles=p.add_mutually_exclusive_group();roles.add_argument('--technician',action='store_true');roles.add_argument('--scout',action='store_true');roles.add_argument('--shocktroop',action='store_true');a=p.parse_args();out=a.output.resolve()
    kind='technician' if a.technician else 'scout' if a.scout else 'shocktroop' if a.shocktroop else 'medic'
    if out.exists() and any(out.iterdir()):p.error('Choose a new or empty output directory.')
    if not 1024<=a.port<=65535:p.error('Invalid local test port.')
    require_build('linux',server=True);out.mkdir(parents=True,exist_ok=True)
    config=(ROOT/'tools/voxel_battle/medic_test.cfg').read_text().replace('local medic test','local '+kind+' test').replace('"27779"',f'"{a.port}"');(out/'server.cfg').write_text(config)
    base=['godot','--path',str(ROOT),'--script',f'res://tools/voxel_battle/{kind}_test.gd']
    server_args=base[:1]+['--headless','--xr-mode','off']+base[1:]+['--','--server','--config',str(out/'server.cfg'),f'--cq-{kind}-test']
    env=os.environ.copy();env['XDG_DATA_HOME']=str(out/'server-data');env['XDG_CACHE_HOME']=str(out/'server-cache')
    with (out/'server.log').open('w') as log:server=subprocess.Popen(server_args,env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
    success=False
    try:
        deadline=time.monotonic()+90
        while 'CQ_RESIDENT_READY' not in (out/'server.log').read_text():
            if server.poll() is not None or time.monotonic()>deadline:raise RuntimeError('Medic test server failed; inspect '+str(out/'server.log'))
            time.sleep(.2)
        client=base[:1]+['--xr-mode','on','--rendering-method','forward_plus']+base[1:]+['--','--connect','127.0.0.1','--port',str(a.port),f'--cq-{kind}-test','--frame-stats','--analytics-output',str(out/'client-gameplay.jsonl')]
        runtime=os.environ.get('XR_RUNTIME_JSON',str(Path.home()/'.local/opt/wivrn-pro/share/openxr/1/openxr_wivrn_pro.json'))
        (out/'run-client.sh').write_text('#!/bin/sh\nexport XR_RUNTIME_JSON='+shlex.quote(runtime)+'\nexec '+shlex.join(client)+' >> '+shlex.quote(str(out/'client.log'))+' 2>&1\n');(out/'run-client.sh').chmod(0o755)
        info={'server_pid':server.pid,'address':f'127.0.0.1:{a.port}','scene':f'res://tools/voxel_battle/{kind}_test.tscn','medic_hp':35,'medic_armour':0,'patient_hp':1,'patient_incapacitated':True,'patient_bleedout_seconds':300,'reset':'F8 or RESET MEDIC TEST in the menu','client_launcher':str(out/'run-client.sh'),'output':str(out)}
        if a.technician:
            for key in ['medic_hp','medic_armour','patient_hp','patient_incapacitated','patient_bleedout_seconds']:info.pop(key,None)
            info.update({'class':'technician','primary_ammo':3,'secondary_ammo':1,'vehicle_hp':40,'reset':'F8 or RESET TECHNICIAN TEST in the menu'})
        if a.scout:
            for key in ['medic_hp','medic_armour','patient_hp','patient_incapacitated','patient_bleedout_seconds']:info.pop(key,None)
            info.update({'class':'scout','primary':'scoped pistol','secondary':'target designator','utility':'cloak','guidance_preview':'allied technician launcher 100 metres behind scout at reset','reset':'F8 or RESET SCOUT TEST in the menu'})
        if a.shocktroop:
            for key in ['medic_hp','medic_armour','patient_hp','patient_incapacitated','patient_bleedout_seconds']:info.pop(key,None)
            info.update({'class':'shocktroop','hp':100,'armour':100,'reset':'F8 or RESET SHOCKTROOP TEST in the menu'})
        if a.check:
            check=base[:1]+['--headless','--xr-mode','off']+base[1:]+['--','--connect','127.0.0.1','--port',str(a.port),f'--cq-{kind}-test',f'--{kind}-test-check',str(out/'check.json'),'--analytics-output',str(out/'client-gameplay.jsonl')]
            with (out/'client.log').open('w') as log:subprocess.run(check,stdout=log,stderr=subprocess.STDOUT,timeout=75,check=True)
            info['check']=json.loads((out/'check.json').read_text());info['server_left_running']=False
        elif a.xr:
            with (out/'client.log').open('w') as log:
                vr_env=os.environ.copy();vr_env['XR_RUNTIME_JSON']=runtime
                child=subprocess.Popen(client,env=vr_env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
            info['client_pid']=child.pid;info['server_left_running']=True
        else:info['server_left_running']=True
        (out/'prepared.json').write_text(json.dumps(info,indent=2)+'\n');print(json.dumps(info));success=True
    finally:
        if a.check or not success:
            if server.poll() is None:
                os.killpg(server.pid,signal.SIGTERM)
                try:server.wait(timeout=8)
                except subprocess.TimeoutExpired:os.killpg(server.pid,signal.SIGKILL);server.wait()
if __name__=='__main__':main()
