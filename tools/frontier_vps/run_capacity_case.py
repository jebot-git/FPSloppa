#!/usr/bin/env python3
"""One isolated release-package ENet capacity case; never alters a live service."""
import argparse, hashlib, json, os, signal, subprocess, time
from pathlib import Path


def stop(job):
    if job.poll() is None:
        os.killpg(job.pid, signal.SIGTERM)
        try: job.wait(timeout=8)
        except subprocess.TimeoutExpired:
            os.killpg(job.pid, signal.SIGKILL); job.wait()


def sample(pid):
    stat=Path(f'/proc/{pid}/stat').read_text().rsplit(')',1)[1].split()
    status=dict(line.split(':',1) for line in Path(f'/proc/{pid}/status').read_text().splitlines() if ':' in line)
    return {'epoch':time.time(),'cpu_seconds':(int(stat[11])+int(stat[12]))/os.sysconf('SC_CLK_TCK'),'rss_mib':int(status['VmRSS'].split()[0])/1024,'threads':int(status['Threads'])}


def listening(pid,port):
    try:
        owned={f.readlink().as_posix()[8:-1] for f in Path(f'/proc/{pid}/fd').iterdir() if f.is_symlink() and str(f.readlink()).startswith('socket:[')}
        for table in ['udp','udp6']:
            for line in Path('/proc/net/'+table).read_text().splitlines()[1:]:
                fields=line.split()
                if int(fields[1].rsplit(':',1)[1],16)==port and fields[9] in owned:return True
    except (OSError,ValueError):pass
    return False


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--bundle',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    p.add_argument('--players',type=int,required=True);p.add_argument('--hz',type=int,choices=[30,60],default=30)
    p.add_argument('--seconds',type=int,default=120);p.add_argument('--port',type=int,default=27959)
    p.add_argument('--team-limit',type=int,choices=[32,64],default=32)
    p.add_argument('--adaptive-tick',action='store_true')
    p.add_argument('--adaptive-load-delay-us',type=int,choices=[0,14000],default=0)
    p.add_argument('--stress-test',action='store_true');a=p.parse_args()
    if not 1<=a.players<=128 or a.seconds<1:p.error('Invalid workload')
    if a.adaptive_tick and (a.players>64 or a.hz!=60 or a.team_limit!=32):p.error('Adaptive experiment requires <=64 players, 60 Hz initial rate and default team limits')
    if a.adaptive_load_delay_us and (not a.adaptive_tick or a.seconds<80):p.error('Pressure/recovery probe requires adaptive mode and >=80 seconds')
    out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);bundle=a.bundle.resolve()
    manifest=json.loads((bundle/'release-sha256.json').read_text())
    for name,sha in manifest.items():
        f=(bundle/name).resolve()
        if not f.is_relative_to(bundle) or hashlib.sha256(f.read_bytes()).hexdigest()!=sha:raise RuntimeError('Release checksum mismatch: '+name)
    (out/'release-sha256.json').write_text(json.dumps(manifest,indent=2))
    jobs=[];handles=[];samples=[];result={'requested_players':a.players,'requested_hz':a.hz,'experimental_team_limit':a.team_limit,'adaptive_tick':a.adaptive_tick,'injected_delay_us':a.adaptive_load_delay_us,'duration_seconds':a.seconds,'stress':a.stress_test,'bundle':str(bundle),'passed':False}
    base=[str(bundle/'cq-server'),'--headless','--xr-mode','off','--','--resident-suite','--players',str(a.players),'--seconds',str(a.seconds),'--port',str(a.port),'--tick-hz',str(a.hz),'--experimental-team-limit',str(a.team_limit),'--cq-core','--tracked','--jungle-map']+(['--stress-test'] if a.stress_test else [])
    if a.adaptive_tick:base+=['--cq-adaptive-tick','--adaptive-load-delay-us',str(a.adaptive_load_delay_us)]
    try:
        log=(out/'server.log').open('w');handles.append(log)
        server=subprocess.Popen(base+['--role','server','--report',str(out/'server.json')],stdout=log,stderr=subprocess.STDOUT,start_new_session=True);jobs.append(server)
        ready_deadline=time.monotonic()+120
        while not listening(server.pid,a.port):
            if server.poll() is not None:raise RuntimeError('Server startup failed')
            if time.monotonic()>ready_deadline:raise RuntimeError('Server did not bind fixture port')
            time.sleep(.1)
        for first in range(0,a.players,4):
            log=(out/f'clients-{first:03}.log').open('w');handles.append(log)
            jobs.append(subprocess.Popen(base+['--role','clients','--client-count',str(min(4,a.players-first))],stdout=log,stderr=subprocess.STDOUT,start_new_session=True))
        deadline=time.monotonic()+a.seconds+100
        while any(job.poll() is None for job in jobs):
            if time.monotonic()>deadline:raise RuntimeError('Case timed out')
            if server.poll() is None:
                try:samples.append(sample(server.pid))
                except (OSError,KeyError):pass
            if any(job.poll() not in (None,0) for job in jobs):raise RuntimeError('Fixture process failed')
            time.sleep(1)
        clients=[];diagnostics=[]
        for f in out.glob('*.log'):
            for line in f.read_text().splitlines():
                if line.startswith('AUTHORITY_CLIENTS '):clients.append(json.loads(line.split(' ',1)[1]))
                if 'ERROR:' in line or 'WARNING:' in line:diagnostics.append({'file':f.name,'line':line})
        row=json.loads((out/'server.json').read_text());offered=sum(c['total_inputs_sent'] for c in clients)
        result.update(server=row,clients=clients,diagnostics=diagnostics,accepted_fraction=row['native']['accepted']/max(1,offered),exit_codes=[j.returncode for j in jobs])
        failures=[]
        if diagnostics:failures.append('Fixture diagnostics')
        if sum(c['admitted'] for c in clients)!=a.players:failures.append('Incomplete admission')
        if row['players']!=a.players:failures.append('Population gate')
        if a.adaptive_tick:
            ratio=row['simulation_elapsed_seconds']/row['seconds'];result['simulation_wall_ratio']=ratio
            if not .98<=ratio<=1.02 or not row.get('adaptive_tick') or not row.get('by_tick_rate',{}).get('60',{}).get('ticks'):failures.append('Adaptive simulation clock gate')
            transitions=[(t['from'],t['to']) for t in row.get('tick_transitions',[])]
            if a.adaptive_load_delay_us and (transitions.count((60,30))<1 or transitions.count((30,60))<1):failures.append('Pressure fallback/recovery gate')
        elif row['hz']<a.hz*.98 or row['hz']>a.hz*1.02:failures.append('Simulation Hz gate')
        if row['disconnected'] or row['native']['overflow'] or row['native']['projectile_full']:failures.append('Server transport/queue gate')
        for c in clients:
            if c['bad_frames'] or c['disconnected'] or c['minimum_frames']<a.seconds*15 or c['minimum_inputs_sent']<a.seconds*a.hz*.96:failures.append('Client delivery/input gate')
        if result['accepted_fraction']<.9:failures.append('Input acceptance below 90%')
        if row['native']['shots']<a.players or any(int(row.get('shots_by_class_current_life',{}).get(str(role),0))<=0 for role in range(4)):
            failures.append('Insufficient four-class firing workload')
        result['failures']=failures;result['passed']=not failures
    except Exception as error:
        result['error']=str(error)
    finally:
        for job in jobs:stop(job)
        for handle in handles:handle.close()
        (out/'resources.json').write_text(json.dumps(samples,indent=2));(out/'summary.json').write_text(json.dumps(result,indent=2))
    print(json.dumps({'output':str(out),'passed':result['passed'],'error':result.get('error'),'failures':result.get('failures')}),flush=True)
    raise SystemExit(0 if result['passed'] else 1)

if __name__=='__main__':main()
