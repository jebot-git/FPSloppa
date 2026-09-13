"""Validate authenticated atomic match selection on the actual console build."""
import importlib.util
import json
from pathlib import Path
import secrets
import subprocess
import tempfile
import time

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('rcon',ROOT/'tools/rcon.py')
rcon=importlib.util.module_from_spec(spec);spec.loader.exec_module(rcon)
secret=secrets.token_hex(24)
out=ROOT/'test-results/remote-all-modes/rcon-validation.log'
with tempfile.TemporaryDirectory(prefix='fpsloppa-match-rcon-') as tmp:
    config=Path(tmp)/'server.cfg'
    config.write_text(f'set net_ip 127.0.0.1\nset net_port 28984\nset rcon_port 28985\nset rcon_password "{secret}"\nset sv_gametypes "dm cc"\nset dm_maplist qsrc_dm3\nset cc_maplist cc_basement\n')
    with out.open('w') as log:
        process=subprocess.Popen([str(ROOT/'Builds/RemoteAllModes/FPSloppaServer.x86_64'),'--','--config',str(config)],stdout=log,stderr=subprocess.STDOUT)
        try:
            deadline=time.monotonic()+30
            while 'SERVER_CONFIG' not in out.read_text() and time.monotonic()<deadline and process.poll() is None:time.sleep(.1)
            assert process.poll() is None and 'SERVER_CONFIG' in out.read_text(),out.read_text()[-2000:]
            def call(text):return rcon.command('127.0.0.1',28985,secret,text)
            for text in ['match dm qsrc_dm3 invalid','match tf qsrc_dm3 quake','match dm cc_basement doom','match dm qsrc_dm3 doom extra']:
                assert 'error' in call(text),text
            assert call('match dm qsrc_dm3 quake')['ok'];time.sleep(.3)
            assert call('status')['weapon_rules']=='quake'
            assert call('match dm qsrc_dm3 ut99')['ok'];time.sleep(.3)
            status=call('status');assert status['weapon_rules']=='ut99' and status['map']=='qsrc_dm3',status
            assert call('match cc cc_basement quake')['ok'];time.sleep(.3)
            status=call('status');assert status['mode']=='cc' and status['map']=='cc_basement' and status['weapon_rules']=='doom',status
            assert 'SCRIPT ERROR:' not in out.read_text() and 'ERROR:' not in out.read_text(),out.read_text()[-2500:]
        finally:
            process.terminate()
            try:process.wait(timeout=10)
            except subprocess.TimeoutExpired:process.kill();process.wait()
print('RCON_MATCH_PASS invalid_arguments_rejected same_map_rules_changed fixed_loadout_preserved')
