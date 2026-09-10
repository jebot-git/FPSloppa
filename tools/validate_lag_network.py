"""Real ENet gameplay through a deterministic bidirectional UDP impairment proxy.
Latency values are RTT; each direction receives half unless explicitly asymmetric.
"""
from pathlib import Path
import argparse, subprocess, time, socket, selectors, random, heapq, threading, json, os
ROOT=Path(__file__).resolve().parents[1]
class Proxy:
 def __init__(self,rtt,jitter=0,loss=0,up=None):
  self.rng=random.Random(4817);self.sel=selectors.DefaultSelector();self.queue=[];self.serial=0;self.stop=False;self.counts={'received':0,'dropped':0,'delivered':0,'duplicated':0};self.jitter=jitter/1000;self.loss=loss
  self.delays=[(rtt/2 if up is None else up)/1000,(rtt/2 if up is None else rtt-up)/1000]
  for port in [27788,27789]:
   front=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);front.bind(('127.0.0.1',port));front.setblocking(False)
   back=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);back.bind(('127.0.0.1',0));back.setblocking(False)
   link={'front':front,'back':back,'client':None}
   self.sel.register(front,selectors.EVENT_READ,(link,0));self.sel.register(back,selectors.EVENT_READ,(link,1))
 def run(self):
  while not self.stop:
   for key,_ in self.sel.select(.001):
    try:data,address=key.fileobj.recvfrom(65535)
    except BlockingIOError:continue
    link,direction=key.data
    if direction==0:link['client']=address
    destination=('127.0.0.1',27787) if direction==0 else link['client']
    if destination is None:continue
    self.counts['received']+=1
    if self.rng.random()<self.loss:self.counts['dropped']+=1;continue
    delay=max(0,self.delays[direction]+self.rng.uniform(-self.jitter,self.jitter));self.serial+=1
    item=(time.monotonic()+delay,self.serial,link['back' if direction==0 else 'front'],destination,data);heapq.heappush(self.queue,item)
    if self.loss and self.rng.random()<.005:
     self.serial+=1;heapq.heappush(self.queue,(item[0]+.005,self.serial,*item[2:]));self.counts['duplicated']+=1
   while self.queue and self.queue[0][0]<=time.monotonic():
    _,_,sock,destination,data=heapq.heappop(self.queue);sock.sendto(data,destination);self.counts['delivered']+=1
  for key in list(self.sel.get_map().values()):key.fileobj.close()
  self.sel.close()
def main():
 p=argparse.ArgumentParser();p.add_argument('--rtt',type=int);p.add_argument('--resume',action='store_true');p.add_argument('--jitter',type=float,default=0);p.add_argument('--loss',type=float,default=0);a=p.parse_args()
 matrix=[(a.rtt,a.jitter,a.loss,None)] if a.rtt else [(x,0,0,None) for x in [20,40,60,80,100]]+[(50,10,.01,None),(100,15,.02,None),(100,5,.01,20)]
 godot=os.environ.get('GODOT_BIN','/home/blux/.local/bin/Godot_v4.7.2-stable_linux.x86_64');folder=ROOT/'test-results'/'lag';folder.mkdir(parents=True,exist_ok=True);results=json.loads((folder/'summary.json').read_text()) if a.resume and (folder/'summary.json').exists() else []
 for rtt,jitter,loss,up in matrix:
  if a.resume and any((row['rtt_ms'],row['jitter_ms'],row['loss'],row['uplink_ms'])==(rtt,jitter,loss,up) for row in results):continue
  name=f'{rtt}ms-j{jitter}-loss{loss}-up{up}';proxy=Proxy(rtt,jitter,loss,up);thread=threading.Thread(target=proxy.run);thread.start();processes=[];logs=[];row={'rtt_ms':rtt,'jitter_ms':jitter,'loss':loss,'uplink_ms':up,'roles':[]}
  try:
   for role in ['server','shooter','target']:
    path=folder/f'{name}-{role}.log';log=path.open('w');logs.append(log)
    proc=subprocess.Popen([godot,'--headless','--xr-mode','off','--path',str(ROOT),'--script','res://deathmatch/tests/lag_network.gd','--',role],stdout=log,stderr=subprocess.STDOUT);processes.append((role,proc,path))
    if role=='server':time.sleep(1)
   for role,proc,path in processes:
    proc.wait(timeout=55);text=path.read_text();records=[x.removeprefix('LAG_NETWORK_RESULT ') for x in text.splitlines() if x.startswith('LAG_NETWORK_RESULT ')]
    if not records or proc.returncode or 'SCRIPT ERROR' in text or 'ERROR:' in text:raise RuntimeError(f'{name} {role}: {text[-4000:]}')
    row['roles'].append(json.loads(records[-1]))
   row['proxy']=proxy.counts;results.append(row);(folder/(f'summary-{a.rtt}ms.json' if a.rtt else 'summary.json')).write_text(json.dumps(results,indent=2));print('PASS',name,json.dumps(row),flush=True)
  finally:
   for _,proc,_ in processes:
    if proc.poll() is None:proc.terminate();proc.wait(timeout=5)
   proxy.stop=True;thread.join(timeout=5)
   for log in logs:log.close()
if __name__=='__main__':main()
