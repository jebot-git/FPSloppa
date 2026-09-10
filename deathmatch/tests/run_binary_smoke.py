"""Launch real Linux server and graphical PC export, then verify joining."""
from pathlib import Path
import subprocess,time,json
root=Path(__file__).resolve().parents[2]
logs=root/'test-results'
server=root.parent/'Builds/Server/FPSloppaServer.x86_64'
client=root.parent/'Builds/Linux/FPSloppa.x86_64'
with (logs/'binary_server.log').open('w') as server_log,(logs/'binary_client.log').open('w') as client_log:
    proc=subprocess.Popen([str(server),'--','--config',str(root/'server.cfg'),'--asset-root',str(root),'--port','28890'],stdout=server_log,stderr=subprocess.STDOUT)
    try:
        end=time.monotonic()+10
        while time.monotonic()<end and 'DM_HOST_READY' not in (logs/'binary_server.log').read_text():time.sleep(.05)
        result=subprocess.run([str(client),'--xr-mode','off','--audio-driver','Dummy','--quit-after','600','--','--asset-root',str(root),'--connect','127.0.0.1','--port','28890'],stdout=client_log,stderr=subprocess.STDOUT,timeout=60)
        server_text=(logs/'binary_server.log').read_text()
        client_text=(logs/'binary_client.log').read_text()
        passed=result.returncode==0 and 'joined the arena' in server_text and 'ERROR:' not in client_text and 'ERROR:' not in server_text
        (logs/'binary_smoke_summary.json').write_text(json.dumps({'passed':passed,'client_exit':result.returncode,'graphical_linux_client':True},indent=2))
        print(server_text,client_text,'BINARY_SMOKE',passed)
        raise SystemExit(0 if passed else 1)
    finally:
        proc.terminate();proc.wait(timeout=5)
