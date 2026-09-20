import json
import os
import secrets
from pathlib import Path
from .model import topology


def grid(count,base_port=41000):
    if not 4<=count<=64:
        raise ValueError('Use 4–64 districts')
    if type(base_port) is not int or not 1024<=base_port<=65300:
        raise ValueError('Base port must leave room for sixteen backends and ENet facades')
    width=min(8,count)
    rows={}
    for i in range(count):
        links={}
        for j,exit_,entry,yaw in ((i-1,[-124,1,0],[120,1,0],0),(i+1,[124,1,0],[-120,1,0],0),(i-width,[0,1,-124],[0,1,120],0),(i+width,[0,1,124],[0,1,-120],0)):
            if 0<=j<count and (abs(j-i)==width or j//width==i//width):
                links[f'd{j:02}']=dict(exit=exit_,entry=entry,yaw=yaw)
        rows[f'd{i:02}']=dict(gateway=f'g{i//4:02}',map_slot=i%16,links=links,draining=False)
    topology(rows)
    return dict(protocol='fpsloppa-persistent-cluster-1',coordinators=[['127.0.0.1',base_port]],admin_token=secrets.token_hex(32),mesh_token=secrets.token_hex(32),client_token=secrets.token_hex(32),gateways={f'g{i:02}':dict(address=['127.0.0.1',base_port+10+i],token=secrets.token_hex(32)) for i in range(16)},worker_tokens={f'd{i:02}':secrets.token_hex(32) for i in range(64)},districts=rows,waiting_limit=128)


def write_private(path,value):
    path=Path(path)
    path.parent.mkdir(parents=True,exist_ok=True)
    descriptor=os.open(path,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
    with os.fdopen(descriptor,'w') as file:
        json.dump(value,file,indent=2);file.write('\n')


def read(path):
    config=json.loads(Path(path).read_text())
    if config.get('protocol')!='fpsloppa-persistent-cluster-1':raise ValueError('Cluster protocol mismatch')
    topology(config['districts'])
    for address in config['coordinators']+[g['address'] for g in config['gateways'].values()]:
        if not isinstance(address,list) or len(address)!=2 or address[0]!='127.0.0.1' or type(address[1]) is not int or not 1024<=address[1]<=65535:
            raise ValueError('Prototype endpoints must use loopback ports 1024–65535; tunnel between hosts')
    for key in ('admin_token','mesh_token','client_token'):
        if not isinstance(config[key],str) or len(config[key])!=64:raise ValueError('Invalid credential')
    return config
