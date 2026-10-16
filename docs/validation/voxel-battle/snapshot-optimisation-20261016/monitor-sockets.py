import json,os,time
from pathlib import Path
root=Path('/home/blux/fpsloppa-cq/validation/snapshots-release-20261016')
with (root/'sockets.jsonl').open('w') as out:
 while Path('/proc/1684148/cmdline').exists() and Path('/proc/1684148/cmdline').read_bytes():
  sockets={r.split()[9]:r.split() for r in Path('/proc/net/udp').read_text().splitlines()[1:]}
  rows=[]
  for p in Path('/proc').iterdir():
   if not p.name.isdigit():continue
   try:
    command=(p/'cmdline').read_bytes().split(b'\0')[0].decode()
    if command not in [str(root/'cq-server'),str(root/'cq-load-client')]:continue
    for fd in (p/'fd').iterdir():
     link=os.readlink(fd)
     if not link.startswith('socket:['):continue
     row=sockets.get(link[8:-1])
     if row:rows.append({'pid':int(p.name),'role':Path(command).name,'address':row[1],'drops':int(row[-1]),'queue':row[4]})
   except (FileNotFoundError,ProcessLookupError,PermissionError):pass
  out.write(json.dumps({'utc':time.time(),'sockets':rows})+'\n');out.flush();time.sleep(1)
