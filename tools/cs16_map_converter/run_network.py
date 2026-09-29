"""Local ENet test with an empty client asset directory; no production server."""
import argparse
import os
import socket
import subprocess
import tempfile
import time
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('map',type=Path);p.add_argument('--output',type=Path,default=ROOT/'test-results/cs16-map-converter');a=p.parse_args()
    output=a.output.resolve();output.mkdir(parents=True,exist_ok=True)
    with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as probe:
        probe.bind(('127.0.0.1',0));port=probe.getsockname()[1]
    processes=[];logs=[]
    with tempfile.TemporaryDirectory(prefix='fps-cs-map-net-') as work:
        try:
            for role in ['server','client']:
                assets=Path(work)/role;assets.mkdir()
                env=dict(os.environ,XDG_CONFIG_HOME=str(assets/'config'),XDG_DATA_HOME=str(assets/'data'))
                log=(output/f'network-{role}.log').open('w');logs.append(log)
                cmd=['godot','--headless','--audio-driver','Dummy','--xr-mode','off','--path',str(ROOT),'--log-file',str(output/f'network-{role}-engine.log'),'--script','deathmatch/tests/cs_map_network.gd','--',role,str(a.map.resolve()),str(port),'--asset-root',str(assets)]
                processes.append(subprocess.Popen(cmd,stdout=log,stderr=subprocess.STDOUT,env=env))
                if role=='server':time.sleep(2)
            for process in processes:process.wait(timeout=70)
            for role,process in zip(['server','client'],processes):
                text=(output/f'network-{role}.log').read_text()
                print(role,process.returncode,'\n'.join(text.splitlines()[-12:]))
                assert process.returncode==0 and f'CS_MAP_NETWORK_RESULT {role} []' in text and 'SCRIPT ERROR:' not in text
        finally:
            for process in processes:
                if process.poll() is None:process.terminate()
            for process in processes:
                try:process.wait(timeout=5)
                except subprocess.TimeoutExpired:process.kill();process.wait()
            for log in logs:log.close()


if __name__=='__main__':main()
