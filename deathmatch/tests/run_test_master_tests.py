"""Validate dedicated-hosted test master startup, self-registration and cleanup."""
import argparse
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import time
import urllib.request

ROOT=Path(__file__).resolve().parents[2]

def port(kind):
    with socket.socket(socket.AF_INET,kind) as peer:
        peer.bind(('127.0.0.1',0));return peer.getsockname()[1]

def listing(number):
    try:
        with urllib.request.urlopen(f'http://127.0.0.1:{number}/v1/servers',timeout=.5) as response:
            return json.load(response)['servers']
    except OSError:return []

def wait(predicate,timeout):
    end=time.monotonic()+timeout
    while time.monotonic()<end:
        if predicate():return True
        time.sleep(.15)
    return False

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--server',type=Path)
    args=parser.parse_args()
    logs=ROOT/'test-results/test-master';logs.mkdir(parents=True,exist_ok=True)
    reports=[]
    with tempfile.TemporaryDirectory(prefix='fpsloppa-test-master-') as temporary:
        folder=Path(temporary);assets=folder/'assets'
        for row in json.loads((ROOT/'deathmatch/assets/base_manifest.json').read_text())['files']:
            if row['path']=='maps/qsrc_dm1.bsp' or row['path'].startswith('vrm/'):
                target=assets/row['path'];target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(ROOT/row['path'],target)
        for forced in [False,True]:
            label='forced' if forced else 'graceful'
            env=dict(os.environ,XDG_DATA_HOME=str(folder/label));env.pop('FPSLOPPA_MASTER_TOKEN',None)
            master_port=port(socket.SOCK_STREAM);game_port=port(socket.SOCK_DGRAM);query_port=port(socket.SOCK_DGRAM)
            cfg=folder/(label+'.cfg')
            cfg.write_text(f'set net_ip 127.0.0.1\nset net_port {game_port}\nset sv_query_port {query_port}\n'
                           f'set sv_master_test 1\nset sv_master_test_port {master_port}\nset dm_maplist qsrc_dm1\nset sv_voice 0\n')
            command=([str(args.server.resolve())] if args.server else [os.environ.get('GODOT_BIN') or shutil.which('godot'),'--headless','--xr-mode','off','--audio-driver','Dummy','--path',str(ROOT)])
            command+=['--log-file',str(logs/(label+'-engine.log')),'--','--server','--config',str(cfg),'--asset-root',str(assets)]
            if not forced:command+=['--quit-after-seconds','12']
            with (logs/(label+'.log')).open('w') as output:
                process=subprocess.Popen(command,env=env,stdout=output,stderr=subprocess.STDOUT)
                try:
                    assert wait(lambda:'"http_status":200' in (logs/(label+'.log')).read_text() or process.poll() is not None,10),(logs/(label+'.log')).read_text()
                    rows=listing(master_port)
                    assert process.poll() is None and len(rows)==1,(logs/(label+'.log')).read_text()
                    assert rows[0]['game_port']==game_port and rows[0]['query_port']==query_port and rows[0]['id']=='local-test'
                    if forced:process.kill()
                    process.wait(timeout=15)
                    assert forced or process.returncode==0
                    def closed():
                        try:
                            with socket.create_connection(('127.0.0.1',master_port),timeout=.2):return False
                        except OSError:return True
                    assert wait(closed,5),'Test master survived dedicated exit'
                    runtime=folder/label/'godot/app_userdata/FPSloppa/master-test'
                    assert wait(lambda:not list(runtime.glob('*')),5),'Temporary master state was not cleaned'
                    text=(logs/(label+'.log')).read_text()
                    assert 'TEST_MASTER_READY' in text and 'SCRIPT ERROR:' not in text and 'ERROR:' not in text,text
                    reports.append({'case':label,'registered':True,'master_stopped':True,'temporary_state_removed':True})
                finally:
                    if process.poll() is None:process.kill();process.wait(timeout=5)
    (logs/'results.json').write_text(json.dumps(reports,indent=2)+'\n')
    print('TEST_MASTER_PASS',json.dumps(reports))

if __name__=='__main__':main()
