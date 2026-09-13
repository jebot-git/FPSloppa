"""Sample one explicitly selected test process; never inspect other processes' data."""
import argparse
import json
import os
from pathlib import Path
import time

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('pid',type=int)
parser.add_argument('output',type=Path)
parser.add_argument('--seconds',type=int,default=1800)
args=parser.parse_args()
ticks=os.sysconf('SC_CLK_TCK');previous=None
with args.output.open('w',buffering=1) as log:
    until=time.monotonic()+args.seconds
    while time.monotonic()<until:
        try:
            proc=Path('/proc')/str(args.pid)
            stat=(proc/'stat').read_text().rsplit(')',1)[1].split()
            fields=dict(line.split(':',1) for line in (proc/'status').read_text().splitlines() if ':' in line)
            now=time.monotonic();cpu=(int(stat[11])+int(stat[12]))/ticks
            row=dict(time=time.time(),pid=args.pid,state=stat[0],rss_kib=int(fields['VmRSS'].split()[0]),
                hwm_kib=int(fields['VmHWM'].split()[0]),threads=int(fields['Threads']),fds=len(list((proc/'fd').iterdir())),
                cpu_percent=(cpu-previous[1])/(now-previous[0])*100 if previous else None)
            previous=(now,cpu)
            # Socket drop counters are scoped to this process's socket inodes.
            inodes=set()
            for fd in (proc/'fd').iterdir():
                try:
                    target=fd.readlink().as_posix()
                    if target.startswith('socket:['):inodes.add(target[8:-1])
                except OSError:pass
            row['udp_drops']=0
            for table in ['udp','udp6']:
                for line in (proc/'net'/table).read_text().splitlines()[1:]:
                    values=line.split()
                    if values[9] in inodes:row['udp_drops']+=int(values[-1])
            log.write(json.dumps(row)+'\n')
        except (OSError,KeyError):break
        time.sleep(1)
