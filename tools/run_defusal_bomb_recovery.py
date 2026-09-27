"""Real ENet bomb recovery: fatal damage, another T's Use, replication, plant."""
from pathlib import Path
import os,subprocess,time
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'test-results/defusal'
processes=[];logs=[]
try:
    for role in ['server','carrier','rescuer','defender']:
        log=(OUT/f'bomb-recovery-network-{role}.log').open('w');logs.append(log)
        env=dict(os.environ,XDG_CONFIG_HOME='/tmp/fpsloppa-recovery-'+role,XDG_DATA_HOME='/tmp/fpsloppa-recovery-'+role)
        proc=subprocess.Popen(['godot','--headless','--xr-mode','off','--path',str(ROOT),'--script','deathmatch/tests/defusal_bomb_recovery_network.gd','--',role],cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT)
        processes.append((role,proc));time.sleep(.7)
    for role,proc in processes:
        proc.wait(timeout=65);content=(OUT/f'bomb-recovery-network-{role}.log').read_text()
        print(role,proc.returncode,'\n'.join(content.splitlines()[-15:]),flush=True)
        assert proc.returncode==0 and f'DE_RECOVERY_NETWORK_RESULT {role} []' in content and 'SCRIPT ERROR' not in content
finally:
    for _,proc in processes:
        if proc.poll() is None:proc.terminate()
    for log in logs:log.close()
