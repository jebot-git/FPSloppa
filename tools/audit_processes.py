"""Run one regression in its own process group; sample memory and verify cleanup.
Linux /proc and child-subreaper auditing. Never terminates pre-existing processes.
Usage: python3 tools/audit_processes.py --timeout 180 NAME -- COMMAND ...
"""
from pathlib import Path
import argparse,ctypes,json,os,signal,subprocess,time
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'test-results/performance-audit';OUT.mkdir(parents=True,exist_ok=True)
def processes():
    result={}
    for folder in Path('/proc').glob('[0-9]*'):
        try:
            raw=(folder/'stat').read_text();end=raw.rfind(')');fields=raw[end+2:].split();pid=int(folder.name)
            result[pid]={'pid':pid,'comm':raw[raw.find('(')+1:end],'state':fields[0],'ppid':int(fields[1]),'pgrp':int(fields[2]),'start_ticks':int(fields[19]),'rss_kib':int(fields[21])*os.sysconf('SC_PAGE_SIZE')//1024,'cpu_ticks':int(fields[11])+int(fields[12]),'threads':int(fields[17])}
        except (OSError,ValueError,IndexError):pass
    return result
def relevant(p):return 'godot' in p['comm'].lower() or p['comm'].lower().startswith(('entryway','fpsloppa')) or p['state']=='Z'
def main():
    parser=argparse.ArgumentParser();parser.add_argument('name');parser.add_argument('--timeout',type=float,default=180);parser.add_argument('command',nargs=argparse.REMAINDER)
    # Options precede NAME to avoid ambiguity with the child command.
    args=parser.parse_args();cmd=args.command
    if cmd and cmd[0]=='--':cmd=cmd[1:]
    baseline=processes()
    if not cmd:
        data=[p for p in baseline.values() if relevant(p)];(OUT/(args.name+'.json')).write_text(json.dumps(data,indent=2));print(json.dumps(data));return
    assert ctypes.CDLL(None).prctl(36,1,0,0,0)==0,'Cannot enable child subreaper'
    samples=[];known=set();timeout=False;forced=[]
    started=time.monotonic()
    with (OUT/(args.name+'.log')).open('w') as log:
        proc=subprocess.Popen(cmd,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
        try:
            while True:
                table=processes();family={proc.pid}
                for _ in range(8):family.update(pid for pid,p in table.items() if p['ppid'] in family or (p['ppid']==os.getpid() and pid!=proc.pid and pid not in baseline))
                owned=[p for pid,p in table.items() if pid in family or p['pgrp']==proc.pid];known.update(p['pid'] for p in owned)
                for p in owned:
                    try:p['fds']=len(list(Path('/proc',str(p['pid']),'fd').iterdir()))
                    except OSError:p['fds']=0
                samples.append({'seconds':round(time.monotonic()-started,3),'processes':owned})
                if proc.poll() is not None:break
                if time.monotonic()-started>args.timeout:timeout=True;break
                time.sleep(.25)
        finally:
            before_cleanup=processes();left=[p for pid,p in before_cleanup.items() if pid!=proc.pid and (pid in known or p['pgrp']==proc.pid)]
            if proc.poll() is None or any(p['state']!='Z' for p in left):
                forced=[p['pid'] for p in left if p['state']!='Z']
                try:os.killpg(proc.pid,signal.SIGTERM)
                except ProcessLookupError:pass
                try:proc.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    os.killpg(proc.pid,signal.SIGKILL);proc.wait(timeout=5)
            proc.wait()
            # Reap only children adopted from this test, after the direct child is reaped.
            reaped=[];deadline=time.monotonic()+3
            while True:
                try:
                    pid,status=os.waitpid(-1,os.WNOHANG)
                    if pid:reaped.append({'pid':pid,'status':status});continue
                    if time.monotonic()<deadline:time.sleep(.1);continue
                except ChildProcessError:pass
                break
    final=processes();survivors=[p for pid,p in final.items() if pid in known and pid not in baseline]
    report={'command':cmd,'exit_code':proc.returncode,'timeout':timeout,'seconds':round(time.monotonic()-started,3),'peak_family_rss_kib':max(sum(p['rss_kib'] for p in s['processes']) for s in samples),'children_left_at_exit':left,'forced_cleanup':forced,'adopted_children_reaped':reaped,'survivors':survivors,'samples':samples}
    (OUT/(args.name+'.json')).write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k not in ('samples','command')}),flush=True)
    raise SystemExit(1 if timeout or proc.returncode or survivors or forced else 0)
if __name__=='__main__':main()
