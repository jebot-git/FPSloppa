"""Run a CQ master or worker host from a small INI-style .cfg file."""
import argparse
import asyncio
import configparser
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time
from . import config
from .local import private, ready


def commands(path):
    parser=configparser.ConfigParser(interpolation=None);parser.read(path)
    row=parser['cq'];root=Path(row['state']).resolve();root.mkdir(parents=True,exist_ok=True)
    cluster=Path(row['cluster']).resolve();settings=config.read(cluster)
    binary=Path(row['binary']).resolve()
    if not binary.is_file():raise ValueError('Missing console worker binary')
    result=[];districts=[]
    if row['role']=='master':
        index=row.getint('index',0)
        # This private verifier is read only by the master, never worker/client JSON.
        settings['moderator_password_hash']=row.get('moderator_password_hash','').strip()
        runtime=root/'master-runtime.json';temporary=root/('master-runtime-'+str(os.getpid())+'.tmp')
        config.write_private(temporary,settings);temporary.replace(runtime);cluster=runtime
        command=[sys.executable,'-m','tools.district_cluster','coordinator','--config',str(cluster),
                 '--index',str(index),'--database',str(root/'control.sqlite'),
                 '--status-file',str(root/'www/index.html')]
        if row.get('etcd'):command+=['--etcd',*row['etcd'].split()]
        if row.get('content_listen'):
            command+=['--content-listen',row['content_listen'],'--content-root',str(root/'vrm'),
                      '--worker-binary',str(binary)]
        result.append(('master',command))
    elif row['role']=='workers':
        districts=row['districts'].split()
        if not districts or not set(districts)<=settings['districts'].keys():raise ValueError('Invalid district inventory')
        regions=sorted({settings['districts'][d]['gateway'] for d in districts})
        for region in regions:
            # Regional ownership is indivisible: one gateway serves <=4 workers.
            if any(d not in districts for d,r in settings['districts'].items() if r['gateway']==region):
                raise ValueError('Assign all districts in a region to the same worker host')
            result.append((region,[sys.executable,'-m','tools.district_cluster','gateway','--config',str(cluster),'--name',region,'--wait-lease']))
            address=settings['gateways'][region]['address'];edge=root/(region+'-edge.json')
            routes={f"{g['address'][0]}:{g['address'][1]}":[g['address'][0],g['address'][1]+100] for g in settings['gateways'].values()}
            private(edge,dict(backend=address,listen=[address[0],address[1]+100],routes=routes))
            result.append((region+'-edge',[str(binary),'--','--cq-service','edge','--config',str(edge)]))
        for district in districts:
            r=settings['districts'][district];worker=root/(district+'.json')
            private(worker,dict(district=district,map_slot=r['map_slot'],asset_id=r['asset_id'],
                address=settings['gateways'][r['gateway']]['address'],token=settings['worker_tokens'][district],state_dir=str(root/'workers'/district)))
            result.append((district,[str(binary),'--','--asset-root',str(binary.parent),'--experimental-cq','--cq-district-maps','--cq-worker',str(r['map_slot']),'--cluster-worker',str(worker)]))
    else:raise ValueError('Role must be master or workers; mode and weapons are fixed to CQ/UT99')
    return settings,root,districts,result


def run(path):
    settings,root,districts,rows=commands(path)
    processes=[];logs=[];markers=[]
    def stop(*_args):raise KeyboardInterrupt
    previous=signal.signal(signal.SIGTERM,stop)
    try:
        for name,command in rows:
            path=root/(name+'.log');log=path.open('a');logs.append(log)
            marker='CLUSTER_READY coordinator' if name=='master' else 'CLUSTER_ENET_READY' if name.endswith('-edge') else 'CLUSTER_READY gateway' if name.startswith('g') else 'CLUSTER_WORKER_READY'
            markers.append((path,log.tell(),marker))
            processes.append((name,subprocess.Popen(command,stdout=log,stderr=subprocess.STDOUT,env=dict(os.environ,XDG_DATA_HOME=str(root/'profile')))))
        # Readiness requires fresh process markers and a reachable coordinator
        # (or the local gateway view). Systemd restarts failed frontends.
        asyncio.run(ready(settings,districts,processes,180,markers))
        print('CQ_SERVICE_READY',flush=True)
        while True:
            for name,process in processes:
                if process.poll() is not None:raise RuntimeError(f'{name} exited; see {root}')
            time.sleep(.5)
    finally:
        signal.signal(signal.SIGTERM,previous)
        for _,process in reversed(processes):
            if process.poll() is None:process.terminate()
        deadline=time.monotonic()+8
        for _,process in reversed(processes):
            try:process.wait(timeout=max(.01,deadline-time.monotonic()))
            except subprocess.TimeoutExpired:process.kill();process.wait()
        for log in logs:log.close()


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('cfg',type=Path);args=parser.parse_args()
    try:run(args.cfg)
    except KeyboardInterrupt:pass
