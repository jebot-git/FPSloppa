"""One master, four independently launched district servers, delayed private links.

This is a same-machine transport/authority feasibility test, not a physical multi-host benchmark.
"""
import argparse, asyncio, json, os, secrets, signal, socket, subprocess, sys, time
from pathlib import Path
from external_config import create

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from rcon import command

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--binary', type=Path, default=ROOT / 'Builds/CQExternal/FPSloppaServer.x86_64')
p.add_argument('--latency-ms', type=float, default=0, help='Added round-trip delay on each master/worker connection')
p.add_argument('--name', default='external-local')
p.add_argument('--failure', action='store_true', help='After successful routes, kill a district and check fail-closed behavior')
p.add_argument('--respawn', action='store_true', help='Require each real client to die and complete master-authorized respawn')
args = p.parse_args()
if not 0 <= args.latency_ms <= 500:
    p.error('Latency must be 0–500 ms')
OUT = ROOT / 'test-results/cq-gateway' / args.name
OUT.mkdir(parents=True, exist_ok=True)
children = []; handles = []; bridges = []; tasks = set(); metrics = {}; report = {}


def free_port():
    with socket.socket() as s:
        s.bind(('127.0.0.1', 0))
        return s.getsockname()[1]


def spawn(name, argv):
    f = (OUT / f'{name}.log').open('w'); handles.append(f)
    proc = subprocess.Popen(argv, cwd=ROOT, stdout=f, stderr=subprocess.STDOUT,
                            env=dict(os.environ, XDG_DATA_HOME=str(OUT / 'profiles' / name)), start_new_session=True)
    children.append(proc)
    return proc


async def until(predicate, seconds=60):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if predicate():return
        await asyncio.sleep(.05)
    raise TimeoutError('Test condition did not complete')


async def forward(reader, writer, key):
    queue = asyncio.Queue(maxsize=32)  # At most 2 MiB buffered in either direction.
    async def read():
        while data := await reader.read(65536):
            metrics[key] = metrics.get(key, 0) + len(data)
            await queue.put((time.monotonic() + args.latency_ms / 2000, data))
        await queue.put((time.monotonic(), b''))
    task = asyncio.create_task(read())
    try:
        while True:
            due, data = await queue.get()
            if not data:return
            await asyncio.sleep(max(0, due-time.monotonic()))
            writer.write(data);await writer.drain()
    finally:
        task.cancel();await asyncio.gather(task, return_exceptions=True)


async def bridge(reader, writer, zone, master_port):
    upstream = None; relays=[]
    try:
        remote, upstream = await asyncio.open_connection('127.0.0.1', master_port)
        for w in [writer, upstream]:w.get_extra_info('socket').setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        a = asyncio.create_task(forward(reader, upstream, f'{zone}:to_master'))
        b = asyncio.create_task(forward(remote, writer, f'{zone}:to_worker'))
        relays=[a,b]
        done, pending = await asyncio.wait(relays, return_when=asyncio.FIRST_COMPLETED)
        for t in pending:t.cancel()
        await asyncio.gather(a,b,return_exceptions=True)
    except (ConnectionError, OSError):pass
    finally:
        for relay in relays:relay.cancel()
        await asyncio.gather(*relays,return_exceptions=True)
        writer.close()
        if upstream:upstream.close()


async def main():
    port, master_port, rcon_port = free_port(), free_port(), free_port()
    proxy_ports = {z:free_port() for z in range(4)}
    inventory = create(OUT / ('private-'+secrets.token_hex(4)), list(range(4)), master_port, proxy_ports)
    password = secrets.token_hex(24)
    config = OUT / 'server.cfg'
    config.write_text(f'set sv_gametype cq\nset sv_gametypes cq\nset sv_cq_backend districts\nset sv_cq_worker_limit 4\nset sv_cq_maxclients 64\nset sv_cq_bot_fill 0\nset sv_voice 0\nset sv_lobby 0\nset sv_votes 0\nset net_ip 127.0.0.1\nset net_port {port}\nset rcon_port {rcon_port}\nset rcon_password "{password}"\n')
    config.chmod(0o600)
    def ctl(text):return command('127.0.0.1', rcon_port, password, text)
    master = spawn('master', [str(args.binary.resolve()), '--', '--experimental-cq', '--config', str(config), '--cq-external-workers', str(inventory)])
    await until(lambda:'SERVER_CONFIG' in (OUT/'master.log').read_text())
    for z in range(4):
        def connected(reader, writer, zone=z):
            task=asyncio.create_task(bridge(reader,writer,zone,master_port));tasks.add(task);task.add_done_callback(tasks.discard)
        bridges.append(await asyncio.start_server(connected,'127.0.0.1',proxy_ports[z]))
    workers = [spawn(f'worker-{z}', [str(args.binary.resolve()), '--', '--experimental-cq', '--cq-worker', str(z), '--worker-session-file', str(inventory.parent/f'worker-{z}.json')]) for z in range(4)]
    await until(lambda:(OUT/'master.log').read_text().count('CQ_WORKER_READY')==4)
    initial = await asyncio.to_thread(ctl,'status')
    assert initial['cq_backend']['placement']=='external'
    assert set(initial['cq_backend']['worker_pids'].values())=={w.pid for w in workers}
    report['independent_worker_pids'] = [w.pid for w in workers]
    start=time.monotonic(); counters_at_start=metrics.copy()
    clients=[]
    for i in range(2):
        clients.append(spawn(f'client-{i}', ['godot','--headless','--xr-mode','off','--path',str(ROOT),'--script','res://tools/cq_gateway/client.gd','--','--experimental-cq','--host','127.0.0.1','--test-port',str(port),'--hold-seconds','20',*(['--respawn'] if args.respawn else [])]))
        await asyncio.sleep(.3)
    await until(lambda:all('CQ_ROUTE ' in (OUT/f'client-{i}.log').read_text() for i in range(2)),120)
    status=await asyncio.to_thread(ctl,'status');report['before_restart']=status['cq_backend']
    assert status['time_remaining'] < initial['time_remaining'], 'Master match clock did not advance'
    report['master_clock_advanced']=True
    assert report['before_restart']['stats']['transfers']>=4
    assert report['before_restart']['stats']['stale_inputs']>=2
    if args.respawn:
        assert report['before_restart']['district_capacity']==16
        assert max(report['before_restart']['occupancy'])<=16
    report['restart']=await asyncio.to_thread(ctl,'restart')
    await asyncio.sleep(3)
    report['after_restart']=(await asyncio.to_thread(ctl,'status'))['cq_backend']
    assert report['after_restart']['epoch']==report['before_restart']['epoch']+1
    assert all(a['phase']=='active' for a in report['after_restart']['actors'])
    await until(lambda:all(c.poll() is not None for c in clients),35)
    report['clients']=[]
    for i,c in enumerate(clients):
        text=(OUT/f'client-{i}.log').read_text()
        assert c.returncode==0 and 'SCRIPT ERROR' not in text,text[-3000:]
        result=json.loads(next(x.removeprefix('CQ_GATEWAY_CLIENT ') for x in text.splitlines() if x.startswith('CQ_GATEWAY_CLIENT ')))
        route=json.loads(next(x.removeprefix('CQ_ROUTE ') for x in text.splitlines() if x.startswith('CQ_ROUTE ')))
        assert not result['failures'] and result['handoffs']>=4
        assert route['roster']==2 and len(route['visible'])==1
        report['clients'].append(dict(result=result,route=route))
    report['sample_seconds']=time.monotonic()-start
    report['bytes_by_link']={key:value-counters_at_start.get(key,0) for key,value in metrics.items()}
    if args.failure:
        workers[0].kill()
        await until(lambda:master.poll() is not None,10)
        assert master.returncode==3
        await until(lambda:all(w.poll() is not None for w in workers),20)
        report['worker_loss_master_exit']=master.returncode
        report['other_workers_exit_on_master_loss']=True
    report['added_worker_rtt_ms']=args.latency_ms;report['ok']=True
    print(json.dumps(report,indent=2),flush=True)


async def run():
    try:await main()
    finally:
        for b in bridges:b.close()
        for t in list(tasks):t.cancel()
        await asyncio.gather(*list(tasks),return_exceptions=True)
        for b in bridges:await b.wait_closed()
        for proc in children:
            if proc.poll() is None:os.killpg(proc.pid,signal.SIGTERM)
        for proc in children:
            try:proc.wait(timeout=5)
            except subprocess.TimeoutExpired:os.killpg(proc.pid,signal.SIGKILL);proc.wait()
        for f in handles:f.close()
        (OUT/'result.json').write_text(json.dumps(report,indent=2)+'\n')

asyncio.run(run())
