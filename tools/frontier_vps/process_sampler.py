"""Sample candidate authority CPU by thread, memory and owned UDP receive drops."""
import argparse,json,os,time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--resident',action='store_true');p.add_argument('--binary',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--seconds',type=int,default=400);a=p.parse_args()
binary=str(a.binary.resolve());a.output.parent.mkdir(parents=True,exist_ok=True);previous={};clock_ticks=os.sysconf('SC_CLK_TCK');deadline=time.monotonic()+a.seconds
with a.output.open('w',buffering=1) as out:
 while time.monotonic()<deadline:
  now=time.monotonic()
  for proc in Path('/proc').iterdir():
   if not proc.name.isdigit():continue
   try:
    args=(proc/'cmdline').read_bytes().split(b'\0')
    if not args or args[0].decode()!=binary:continue
    resident_server=a.resident and b'--role' in args and args[args.index(b'--role')+1:args.index(b'--role')+2]==[b'server']
    if b'--server' not in args and not resident_server:continue
    status={r.split(':',1)[0]:r.split(':',1)[1].strip() for r in (proc/'status').read_text().splitlines() if ':' in r}
    threads={}
    for task in (proc/'task').iterdir():
     data=(task/'stat').read_text().rsplit(')',1)[1].split();ticks=int(data[11])+int(data[12]);key=(proc.name,task.name)
     old=previous.get(key);threads[task.name]={'ticks':ticks,'cpu_percent':100*(ticks-old[1])/clock_ticks/(now-old[0]) if old else None};previous[key]=(now,ticks)
    inodes=set()
    for fd in (proc/'fd').iterdir():
     try:
      value=os.readlink(fd)
      if value.startswith('socket:['):inodes.add(value[8:-1])
     except OSError:pass
    drops=0;sockets=[]
    for name in ['udp','udp6']:
     for line in (proc/'net'/name).read_text().splitlines()[1:]:
      fields=line.split()
      if len(fields)>12 and fields[9] in inodes:
       drops+=int(fields[-1]);queues=fields[4].split(':');sockets.append({'port':int(fields[1].split(':')[-1],16),'tx_queue':int(queues[0],16),'rx_queue':int(queues[1],16),'drops':int(fields[-1])})
    out.write(json.dumps({'time':time.time(),'pid':int(proc.name),'rss_kib':int(status['VmRSS'].split()[0]),'hwm_kib':int(status['VmHWM'].split()[0]),'udp_drops':drops,'threads':threads,'sockets':sockets})+'\n')
   except (OSError,ValueError,KeyError):continue
  time.sleep(max(0,1-(time.monotonic()-now)))
