"""Exercise real dedicated binary configuration, admission limits and bad-config exit."""
from pathlib import Path
import subprocess, tempfile, time, json

root=Path(__file__).resolve().parents[2]
binary=root.parent/'Builds/Server/EntrywayServer.x86_64'
godot='/home/blux/.local/bin/Godot_v4.7.2-stable_linux.x86_64'
logs=root/'test-results'
processes=[]; handles=[]
try:
    with tempfile.TemporaryDirectory(prefix='entryway-config-') as temporary:
        cfg=Path(temporary)/'arena.cfg'
        cfg.write_text('sets sv_hostname "Config Test Arena"\nset net_ip 127.0.0.1\nset net_port 28889\nset sv_maxclients 1\nset fraglimit 7\nset timelimit 3\nset sv_voice 0\nmap lqdm2\n')
        for role in ['server','first','extra']:
            handle=(logs/('config_'+role+'.log')).open('w');handles.append(handle)
            cmd=[str(binary),'--','+exec',str(cfg)] if role=='server' else [godot,'--headless','--xr-mode','off','--path',str(root),'--script','res://deathmatch/tests/server_config_client.gd','--',role]
            proc=subprocess.Popen(cmd,stdout=handle,stderr=subprocess.STDOUT);processes.append(proc)
            if role in ['server','first']:
                marker='SERVER_CONFIG' if role=='server' else 'CONFIG_CLIENT_READY'
                end=time.monotonic()+10
                while time.monotonic()<end and marker not in (logs/('config_'+role+'.log')).read_text():
                    if proc.poll() is not None:break
                    time.sleep(.05)
        for proc in processes[1:]:proc.wait(timeout=12)
        passed=all(p.returncode==0 for p in processes[1:]) and processes[0].poll() is None
        contents=(logs/'config_server.log').read_text()
        passed &= 'maxclients=1 voice=false map=lqdm2' in contents and 'ERROR:' not in contents
        cfg.write_text('set sv_maxclients 99\n')
        bad=subprocess.run([str(binary),'--','+exec',str(cfg)],capture_output=True,text=True,timeout=10)
        passed &= bad.returncode==2 and 'out of range' in bad.stderr
        (logs/'server_config_summary.json').write_text(json.dumps({'passed':passed,'bad_config_exit':bad.returncode},indent=2))
        print(contents)
        print('SERVER_CONFIG_TEST',passed,'invalid config exit',bad.returncode)
        raise SystemExit(0 if passed else 1)
finally:
    for proc in processes:
        if proc.poll() is None:proc.terminate();proc.wait(timeout=5)
    for handle in handles:handle.close()
