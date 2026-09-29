"""Verify the native compact codec and shot-local rewind; optionally benchmark networking."""
from pathlib import Path
import argparse
import json
import os
import subprocess

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/native-network-rewind'


def run(label,script,flags=()):
    command=['godot','--headless','--xr-mode','off','--path',str(ROOT),'--script',script,'--',*flags,'--client-config','/tmp/fps-native-two.cfg']
    result=subprocess.run(command,cwd=ROOT,env=dict(os.environ,XDG_DATA_HOME='/tmp/fps-native-two'),text=True,capture_output=True,timeout=180)
    output=result.stdout+result.stderr
    (OUT/(label+'.log')).write_text(output)
    if result.returncode or 'SCRIPT ERROR' in output or 'FAIL ' in output:
        raise RuntimeError(label+' failed; see '+str(OUT/(label+'.log')))
    reports={}
    for line in output.splitlines():
        for prefix in ['NATIVE_CODEC_RESULT ','NATIVE_REWIND_RESULT ','NATIVE_SHOT_HISTORY_RESULT ','REMAINING_RESULT ','NATIVE_NETWORK_RESULT ']:
            if line.startswith(prefix):reports[prefix.strip()]=json.loads(line[len(prefix):])
    print(label,'PASS',flush=True)
    return reports


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--bench',action='store_true')
    parser.add_argument('--bench-only',action='store_true')
    args=parser.parse_args();OUT.mkdir(parents=True,exist_ok=True)
    reports={}
    if not args.bench_only:
        scripts=['native_codec','native_rewind','native_shot_history','native_acceleration','replication_protocol','native_network_packing','lag_reliability','cs16_penetration','cs16_accuracy','de_cover','hit_detection','projectile_targets','projectile_ordering','combat','fortress']
        for script in scripts:reports[script]=run(script,'deathmatch/tests/'+script+'.gd')
        for script in ['replication_protocol','lag_reliability','cs16_penetration','combat']:
            reports[script+'-fallback']=run(script+'-fallback','deathmatch/tests/'+script+'.gd',['--gdscript-codec','--gdscript-projectiles'])
        (OUT/'checks.json').write_text(json.dumps(reports,indent=2)+'\n')
    if args.bench or args.bench_only:
        reports={}
        for label,flags in [('reference-a',['--gdscript-codec']),('native-a',[]),('native-b',[]),('reference-b',['--gdscript-codec'])]:
            reports[label]=run(label,'tools/native_study/remaining_network.gd',flags)
        (OUT/'network.json').write_text(json.dumps(reports,indent=2)+'\n')


if __name__=='__main__':main()
