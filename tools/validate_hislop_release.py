"""Join the exported HiSlop AS dedicated server with the exported Linux client."""
from pathlib import Path
import json,subprocess,tempfile,time
ROOT=Path(__file__).resolve().parents[1]
BUILDS=ROOT.parent/'Builds'
OUT=ROOT/'test-results'
with tempfile.TemporaryDirectory(prefix='hislop-release-') as temp:
    cfg=Path(temp)/'as.cfg'
    cfg.write_text('set sv_gametype "as"\nset sv_gametypes "as"\nmap "as_hislop"\nset as_maplist ""\nset net_ip "127.0.0.1"\nset net_port "28891"\nset timelimit "7"\n')
    with (OUT/'hislop-binary-server.log').open('w') as serverlog, (OUT/'hislop-binary-client.log').open('w') as clientlog:
        server=subprocess.Popen([str(BUILDS/'Server/FPSloppaServer.x86_64'),'--','--config',str(cfg)],stdout=serverlog,stderr=subprocess.STDOUT)
        try:
            deadline=time.monotonic()+30
            while time.monotonic()<deadline and server.poll() is None and 'DM_HOST_READY' not in (OUT/'hislop-binary-server.log').read_text():time.sleep(.1)
            client=subprocess.run([str(BUILDS/'Linux/FPSloppa.x86_64'),'--xr-mode','off','--audio-driver','Dummy','--max-fps','60','--','--quit-after-seconds','10','--connect','127.0.0.1','--port','28891'],stdout=clientlog,stderr=subprocess.STDOUT,timeout=60)
            st=(OUT/'hislop-binary-server.log').read_text();ct=(OUT/'hislop-binary-client.log').read_text()
            checks={'client_exit':client.returncode==0,'server_alive':server.poll() is None,'joined':'joined the arena' in st,'as_config':'gametype=as' in st,'default_maplist':'rotation=["as_hislop"]' in st,'client_map':'MAP_READY as_hislop' in ct,'no_runtime_errors':'ERROR:' not in st+ct}
            report={'passed':all(checks.values()),'checks':checks}
            (OUT/'hislop-binary-result.json').write_text(json.dumps(report,indent=2)+'\n')
            print(json.dumps(report,indent=2))
            raise SystemExit(0 if report['passed'] else 1)
        finally:
            server.terminate();server.wait(timeout=10)
