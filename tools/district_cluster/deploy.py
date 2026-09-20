"""Prepare/apply a CQ VPS deployment from .cfg. Preparation is entirely local."""
import argparse
import base64
import configparser
import copy
import ipaddress
import json
import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
from . import config

ROOT=Path(__file__).resolve().parents[2]
INSTALL='/opt/fpsloppa-cq'
STATE='/var/lib/fpsloppa-cq'


def district_list(text):
    result=[]
    for part in text.split():
        if re.fullmatch(r'd\d\d-d\d\d',part):
            first,last=part.split('-');result += [f'd{i:02}' for i in range(int(first[1:]),int(last[1:])+1)]
        elif re.fullmatch(r'd\d\d',part):result.append(part)
        else:raise ValueError('District syntax is d00 or d00-d11')
    if len(set(result))!=len(result) or not result:raise ValueError('Empty or duplicate district assignment')
    return result


def read(path):
    parser=configparser.ConfigParser(interpolation=None)
    with Path(path).open() as file:parser.read_file(file)
    cluster=dict(parser['cluster']);nodes={}
    subnet=ipaddress.ip_network(cluster['subnet']);clients=ipaddress.ip_network(cluster['client_subnet'])
    if subnet.version!=4 or clients.version!=4 or subnet.prefixlen!=24 or clients.prefixlen!=24 or subnet.overlaps(clients):
        raise ValueError('Use two separate private IPv4 /24 subnets')
    if not config.private_host(str(subnet.network_address)) or not config.private_host(str(clients.network_address)):raise ValueError('Private subnets required')
    for section in parser.sections():
        if section=='cluster':continue
        role,name=section.split()
        if role not in ('master','workers','ingress') or not re.fullmatch('[a-z][a-z0-9_-]{0,20}',name) or name in nodes:raise ValueError('Invalid role or unique node name')
        row=dict(parser[section]);row['role']=role
        if not re.fullmatch(r'[a-z_][a-z0-9_-]*@[0-9.]+',row['ssh']):raise ValueError('SSH must be USER@IPv4')
        ipaddress.IPv4Address(row['public_ip']);ipaddress.IPv4Address(row['ssh'].split('@')[1])
        if ipaddress.ip_address(row['private_ip']) not in subnet or row['private_ip'] in (str(subnet.network_address),str(subnet.broadcast_address)):raise ValueError('Node address outside mesh subnet')
        if role=='workers':row['districts']=district_list(row['districts'])
        nodes[name]=row
    if len({r['private_ip'] for r in nodes.values()})!=len(nodes):raise ValueError('Private addresses must be unique')
    masters=[k for k,r in nodes.items() if r['role']=='master'];ingress=[k for k,r in nodes.items() if r['role']=='ingress']
    if len(masters) not in (1,3) or len(ingress)!=1:raise ValueError('Configure one or three masters and one VPN ingress')
    assignments=[d for r in nodes.values() if r['role']=='workers' for d in r['districts']]
    if sorted(assignments)!=[f'd{i:02}' for i in range(81)]:raise ValueError('Assign all 81 districts exactly once')
    for row in nodes.values():
        if row['role']=='workers':
            groups={int(d[1:])//4 for d in row['districts']}
            expected={f'd{i:02}' for i in range(81) if i//4 in groups}
            if set(row['districts'])!=expected:raise ValueError('Keep each region of four districts on one worker host')
    if not 1<=int(cluster.get('test_clients',16))<=128:raise ValueError('Use 1–128 client VPN profiles')
    return cluster,nodes,masters,ingress[0]


def keypair():
    private=subprocess.check_output(['openssl','genpkey','-algorithm','X25519','-outform','DER'])
    public=subprocess.check_output(['openssl','pkey','-inform','DER','-pubout','-outform','DER'],input=private)
    return dict(private=base64.b64encode(private[-32:]).decode(),public=base64.b64encode(public[-32:]).decode())


def text(path,value,mode=0o600):
    path.parent.mkdir(parents=True,exist_ok=True);path.write_text(value);path.chmod(mode)


def installer(role,ha=False):
    return '''#!/bin/sh
set -eu
# Debian 12/13 or Ubuntu 24.04, run through the configured SSH account with sudo.
if [ "$(id -u)" -ne 0 ]; then exec sudo sh "$0"; fi
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y python3 libstdc++6 wireguard-tools nftables rsync chrony'''+(' etcd-server etcd-client' if ha else '')+'''
id fpsloppa-cq >/dev/null 2>&1 || useradd --system --home /var/lib/fpsloppa-cq --shell /usr/sbin/nologin fpsloppa-cq
install -d -m 750 -o fpsloppa-cq -g fpsloppa-cq /var/lib/fpsloppa-cq
install -m 600 config/wg-cq.conf /etc/wireguard/wg-cq.conf
systemctl enable --now chrony
systemctl enable wg-quick@wg-cq
systemctl restart wg-quick@wg-cq
'''+('''printf 'net.ipv4.ip_forward=1\n' > /etc/sysctl.d/90-cq-forward.conf
sysctl -p /etc/sysctl.d/90-cq-forward.conf
''' if role=='ingress' else '')+'''
# This table closes only CQ service ports on non-VPN interfaces. It does not
# replace the host's firewall or change SSH access.
nft delete table inet cq_guard 2>/dev/null || true
nft -f config/firewall.nft
install -m 644 config/firewall.nft /etc/cq-firewall.nft
install -m 644 config/cq-firewall.service /etc/systemd/system/cq-firewall.service
systemctl daemon-reload
systemctl enable cq-firewall
'''+('''chown -R root:fpsloppa-cq /opt/fpsloppa-cq
chmod -R g+rX,o-rwx /opt/fpsloppa-cq
chmod 750 /opt/fpsloppa-cq/server/FPSloppaServer.x86_64
'''+('''install -m 644 config/cq-etcd.service /etc/systemd/system/cq-etcd.service
systemctl daemon-reload
systemctl enable --now cq-etcd
install -m 644 config/cq-etcd-defrag.service /etc/systemd/system/cq-etcd-defrag.service
install -m 644 config/cq-etcd-defrag.timer /etc/systemd/system/cq-etcd-defrag.timer
systemctl daemon-reload
systemctl enable --now cq-etcd-defrag.timer
''' if ha else '')+'''install -m 644 config/cq.service /etc/systemd/system/cq.service
systemctl daemon-reload
systemctl enable cq
systemctl restart cq
''' if role!='ingress' else '')


def prepare(inventory,output,binary_dir):
    cluster,nodes,masters,ingress=read(inventory)
    output=Path(output).resolve();output.mkdir(parents=True,exist_ok=True);output.chmod(0o700)
    secret_path=output/'secrets.json'
    if secret_path.exists():secrets=json.loads(secret_path.read_text())
    else:secrets=dict(cluster=config.campaign(int(cluster.get('base_port',41000))),keys={})
    secrets['cluster'].setdefault('campaign_id',hashlib.sha256(secrets['cluster']['client_token'].encode()).hexdigest()[:32])
    settings=copy.deepcopy(secrets['cluster']);port=int(cluster.get('base_port',41000))
    settings['coordinators']=[[nodes[k]['private_ip'],port] for k in masters]
    for name,row in nodes.items():
        if name not in secrets['keys']:secrets['keys'][name]=keypair()
        if row['role']=='workers':
            for d in row['districts']:
                gateway=settings['districts'][d]['gateway']
                settings['gateways'][gateway]['address']=[row['private_ip'],port+10+int(gateway[1:])]
    client_net=ipaddress.ip_network(cluster['client_subnet'])
    clients={f'client{i:03}':str(client_net.network_address+i+2) for i in range(int(cluster.get('test_clients',16)))}
    for name in clients:
        if name not in secrets['keys']:secrets['keys'][name]=keypair()
    text(secret_path,json.dumps(secrets,indent=2)+'\n')
    endpoints=[f"http://{nodes[k]['private_ip']}:2379" for k in masters]
    report=dict(campaign='CQ',loadout='UT99',districts=81,players=128,district_capacity=16,
                worker_processes=81,regional_gateways=21,enet_facades=21,
                worker_vps=sum(r['role']=='workers' for r in nodes.values()),master_vps=len(masters),ingress_vps=1,total_vps=len(nodes),
                status_url=f"http://{nodes[masters[0]]['private_ip']}:8080/",nodes={})
    binary_dir=Path(binary_dir).resolve()
    for name,row in nodes.items():
        folder=output/name;folder.mkdir(exist_ok=True)
        wg=f"[Interface]\nAddress = {row['private_ip']}/24\nListenPort = 51820\nPrivateKey = {secrets['keys'][name]['private']}\nMTU = 1380\n"
        for other,peer in nodes.items():
            if other==name:continue
            allowed=peer['private_ip']+'/32'+(', '+cluster['client_subnet'] if other==ingress else '')
            wg+=f"\n[Peer]\nPublicKey = {secrets['keys'][other]['public']}\nAllowedIPs = {allowed}\nEndpoint = {peer['public_ip']}:51820\nPersistentKeepalive = 25\n"
        if name==ingress:
            for client,ip in clients.items():wg+=f"\n[Peer]\nPublicKey = {secrets['keys'][client]['public']}\nAllowedIPs = {ip}/32\n"
        text(folder/'config/wg-cq.conf',wg)
        tcp_ports=sorted({2379,2380,8080,port,*range(port+10,port+31)})
        udp_ports=list(range(port+110,port+131))
        firewall='table inet cq_guard {\n chain input { type filter hook input priority -5; policy accept;\n  iifname != "wg-cq" iifname != "lo" tcp dport { '+', '.join(map(str,tcp_ports))+' } drop\n  iifname != "wg-cq" iifname != "lo" udp dport { '+', '.join(map(str,udp_ports))+' } drop\n }\n}\n'
        if row['role']=='master':
            firewall=firewall.replace('policy accept;\n', 'policy accept;\n  iifname != "lo" ip saddr != { '+', '.join(nodes[k]['private_ip'] for k in masters)+' } tcp dport { 2379, 2380 } drop\n',1)
        if row['role']=='ingress':
            firewall=firewall[:-2]+(' chain forward { type filter hook forward priority -5; policy accept;\n'
                '  iifname "wg-cq" ip saddr '+cluster['client_subnet']+' udp dport { '+', '.join(map(str,udp_ports))+' } accept\n'
                '  iifname "wg-cq" ip saddr '+cluster['client_subnet']+' tcp dport 8080 accept\n'
                '  iifname "wg-cq" ip saddr '+cluster['client_subnet']+' drop\n }\n}\n')
        text(folder/'config/firewall.nft',firewall)
        text(folder/'config/cq-firewall.service','[Unit]\nDescription=CQ private service firewall\nBefore=cq.service cq-etcd.service\n[Service]\nType=oneshot\nExecStart=/usr/sbin/nft -f /etc/cq-firewall.nft\nRemainAfterExit=yes\n[Install]\nWantedBy=multi-user.target\n')
        if row['role']!='ingress':
            private_settings=copy.deepcopy(settings)
            if row['role']=='workers':
                own={settings['districts'][d]['gateway'] for d in row['districts']}
                private_settings['admin_token']='0'*64
                private_settings['local_gateways']=sorted(own)
                private_settings['worker_tokens']={d:v for d,v in settings['worker_tokens'].items() if d in row['districts']}
                for key in private_settings['gateways']:
                    if key not in own:private_settings['gateways'][key]['token']='0'*64
            text(folder/'config/cluster.json',json.dumps(private_settings,indent=2)+'\n')
            cfg=f"[cq]\nrole = {'master' if row['role']=='master' else 'workers'}\ncluster = config/cluster.json\nstate = {STATE}\nbinary = server/FPSloppaServer.x86_64\n"
            if row['role']=='workers':cfg+='districts = '+' '.join(row['districts'])+'\n'
            else:
                cfg+=f"index = {masters.index(name)}\n"
                if name==masters[0]:cfg+=f"content_listen = {row['private_ip']}:8080\n"
                if len(masters)==3:cfg+='etcd = '+' '.join(endpoints)+'\n'
            text(folder/'config/node.cfg',cfg)
            text(folder/'config/cq.service',f'''[Unit]
Description=CQ {'master' if row['role']=='master' else 'district workers'}
Wants=network-online.target wg-quick@wg-cq.service
After=network-online.target wg-quick@wg-cq.service cq-firewall.service
[Service]
User=fpsloppa-cq
Group=fpsloppa-cq
WorkingDirectory={INSTALL}
ExecStart=/usr/bin/python3 -m tools.district_cluster.service config/node.cfg
Restart=on-failure
RestartSec=8
KillMode=mixed
TimeoutStopSec=15
LimitNOFILE=65536
UMask=0077
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths={STATE}
[Install]
WantedBy=multi-user.target
''')
            destination=folder/'tools/district_cluster';destination.mkdir(parents=True,exist_ok=True)
            for source in (ROOT/'tools/district_cluster').glob('*.py'):shutil.copy2(source,destination/source.name)
            (folder/'server').mkdir(exist_ok=True)
            for filename in ('FPSloppaServer.x86_64','FPSloppaServer.pck','GODOT-LICENSE.txt','GODOT-COPYRIGHT.txt','ASSET_CREDITS.md'):
                shutil.copy2(binary_dir/filename,folder/'server'/filename)
            shutil.copytree(binary_dir/'licenses',folder/'server/licenses',dirs_exist_ok=True)
            for filename in ('README.txt','Makkon_License.txt'):
                target=folder/'server/licenses/Makkon'/filename
                target.parent.mkdir(parents=True,exist_ok=True)
                shutil.copy2(ROOT/'maps/Makkon'/filename,target)
            if row['role']=='workers':
                files=['maps/CQDistricts/manifest.json','maps/CampaignDistricts/manifest.json']
                for d in row['districts']:
                    files += [f'maps/CampaignDistricts/district_{int(d[1:]):02}/{f}' for f in ('district.bsp','collision.scn','navigation.res')]
                for filename in files:
                    target=folder/'server'/filename;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(binary_dir/filename,target)
            if row['role']=='master' and len(masters)==3:
                members=','.join(f"{k}=http://{nodes[k]['private_ip']}:2380" for k in masters)
                text(folder/'config/cq-etcd.service',f'''[Unit]
Description=CQ durable quorum member
After=network-online.target wg-quick@wg-cq.service cq-firewall.service
[Service]
User=fpsloppa-cq
ExecStart=/usr/bin/etcd --name {name} --data-dir {STATE}/etcd --listen-client-urls http://{row['private_ip']}:2379 --advertise-client-urls http://{row['private_ip']}:2379 --listen-peer-urls http://{row['private_ip']}:2380 --initial-advertise-peer-urls http://{row['private_ip']}:2380 --initial-cluster {members} --initial-cluster-token cq-{settings['campaign_id']} --quota-backend-bytes 8589934592 --auto-compaction-mode revision --auto-compaction-retention 1000
Restart=on-failure
RestartSec=3
[Install]
WantedBy=multi-user.target
''')
            if row['role']=='master' and len(masters)==3:
                text(folder/'config/cq-etcd-defrag.service',f'[Unit]\nDescription=Compact physical CQ etcd database\nAfter=cq-etcd.service\n[Service]\nType=oneshot\nEnvironment=ETCDCTL_API=3\nExecStart=/usr/bin/etcdctl --endpoints=http://{row["private_ip"]}:2379 defrag\n')
                text(folder/'config/cq-etcd-defrag.timer',f'[Unit]\nDescription=Staggered CQ etcd defrag\n[Timer]\nOnCalendar=*-*-* *:{10+20*masters.index(name):02}:00\nPersistent=false\n[Install]\nWantedBy=timers.target\n')
        text(folder/'install.sh',installer(row['role'],row['role']=='master' and len(masters)==3),0o700)
        report['nodes'][name]=dict(role=row['role'],ssh=row['ssh'],private_ip=row['private_ip'],districts=row.get('districts',[]))
    for name,ip in clients.items():
        text(output/'clients'/(name+'.conf'),f"[Interface]\nPrivateKey = {secrets['keys'][name]['private']}\nAddress = {ip}/32\nMTU = 1380\n\n[Peer]\nPublicKey = {secrets['keys'][ingress]['public']}\nEndpoint = {nodes[ingress]['public_ip']}:51820\nAllowedIPs = {cluster['subnet']}\nPersistentKeepalive = 25\n")
        entry=settings['gateways'][settings['districts']['d40']['gateway']]['address']
        text(output/'clients'/(name+'.json'),json.dumps(dict(address=[entry[0],entry[1]+100],district='d40',token=settings['client_token'],campaign_id=settings['campaign_id'],team=int(name[-3:])%2,name=name,
            content_url=report['status_url'].rstrip('/'),identity_file=f'user://cq_{settings["campaign_id"]}_{name}.json'),indent=2)+'\n')
    text(output/'plan.json',json.dumps(report,indent=2)+'\n')
    return report


def apply(output,names):
    output=Path(output).resolve();plan=json.loads((output/'plan.json').read_text())
    for name in names or plan['nodes']:
        row=plan['nodes'][name];host=row['ssh']
        subprocess.run(['ssh',host,'sudo mkdir -p '+INSTALL+' && (command -v rsync >/dev/null || (sudo apt-get update && sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y rsync))'],check=True)
        # Existing installations are root-owned, including their subdirectories.
        subprocess.run(['rsync','-az','--rsync-path=sudo rsync','--chmod=Du=rwx,Dgo=,Fu=rw,Fgo=','--',str(output/name)+'/',host+':'+INSTALL+'/'],check=True)
        subprocess.run(['ssh',host,'cd '+INSTALL+' && sudo sh install.sh'],check=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['prepare','apply']);parser.add_argument('--cfg',type=Path,default=ROOT/'deploy/cq/live.cfg')
    parser.add_argument('--output',type=Path,required=True);parser.add_argument('--binary-dir',type=Path,default=ROOT/'Builds/CQLive');parser.add_argument('--nodes',nargs='+')
    args=parser.parse_args()
    if args.action=='prepare':
        plan=prepare(args.cfg,args.output,args.binary_dir)
        print(json.dumps({k:v for k,v in plan.items() if k!='nodes'},indent=2))
    else:apply(args.output,args.nodes)
