"""Check native avatar preparation and bot AI; optionally run isolated A/B benchmarks."""
from pathlib import Path
import argparse
import json
import os
import subprocess
import remaining

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'test-results/native-avatar-bots'
PARITY=['native_preparation','native_bots','native_acceleration']
REGRESSIONS=['bot_humanization','bot_weapons','bot_traversal','bot_tactics','bot_underpass','bot_assault','bot_teamplay','bot_objective_roles','bot_map_triggers','bot_map_transport','cs16_bots','defusal_bots','defusal_bot_behavior','bot_movement','frame_smoothness','death_animation','render_motion']


def run(label,script,flags=(),rendered=False,accelerate=False):
    command=['godot',*([] if rendered else ['--headless']),*(['--fixed-fps','60'] if accelerate else []),'--xr-mode','off','--path',str(ROOT),'--script',script,'--',*flags,'--client-config','/tmp/fps-avatar-bots.cfg']
    result=subprocess.run(command,cwd=ROOT,env=dict(os.environ,XDG_DATA_HOME='/tmp/fps-avatar-bots-data'),text=True,capture_output=True,timeout=480)
    output=result.stdout+result.stderr
    (OUT/(label+'.log')).write_text(output)
    if result.returncode or 'SCRIPT ERROR' in output or 'FAIL ' in output:
        raise RuntimeError(label+' failed; see '+str(OUT/(label+'.log')))
    reports={}
    for line in output.splitlines():
        if '_RESULT ' in line:
            prefix,payload=line.split('_RESULT ',1)
            reports[prefix]=json.loads(payload)
    print(label,'PASS',flush=True)
    return reports


def prepare_benchmarks():
    remaining.OUT=OUT;remaining.PREFIX='res://test-results/native-avatar-bots/'
    remaining.server()
    source=remaining.read('tools/native_study/remaining_server.gd').replace('res://test-results/remaining-native/',remaining.PREFIX)
    before=source.index('\t# Separate controlled firing workload:')
    after=source.index('\tgame.disconnect_game();game.free();await process_frame;quit()',before)
    source=source[:before]+'\tprint("BOT_BENCH_RESULT ",JSON.stringify(report))\n'+source[after:]
    (OUT/'server.gd').write_text(source)
    source=remaining.read('tools/avatar_lod/frametime_study.gd').replace('test-results/frametime-study','test-results/native-avatar-bots')
    (OUT/'avatars.gd').write_text(source)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--regressions',action='store_true')
    parser.add_argument('--bench',choices=['bots','avatars','both'])
    parser.add_argument('--bench-only',action='store_true')
    args=parser.parse_args();OUT.mkdir(parents=True,exist_ok=True)
    if not args.bench_only:
        reports={}
        for script in PARITY+(REGRESSIONS if args.regressions else []):
            reports[script]=run(script,'deathmatch/tests/'+script+'.gd',accelerate=script in REGRESSIONS and script!="render_motion")
        if args.regressions:
            for script in ['bot_humanization','bot_traversal','defusal_bot_behavior','frame_smoothness']:
                reports[script+'-fallback']=run(script+'-fallback','deathmatch/tests/'+script+'.gd',['--gdscript-bots','--gdscript-preparation'],accelerate=True)
        (OUT/'checks.json').write_text(json.dumps(reports,indent=2)+'\n')
    if args.bench:
        prepare_benchmarks();reports={}
        for kind in (['bots','avatars'] if args.bench=='both' else [args.bench]):
            reports[kind]={}
            for label,reference in [('reference-a',True),('native-a',False),('native-b',False),('reference-b',True)]:
                flags=['--gdscript-'+('bots' if kind=='bots' else 'preparation')] if reference else []
                path='server.gd' if kind=='bots' else 'avatars.gd'
                report=run(kind+'-'+label,'res://test-results/native-avatar-bots/'+path,flags,rendered=kind=='avatars')
                if kind=='avatars':report=json.loads((OUT/'avatars.json').read_text())
                reports[kind][label]=report
                (OUT/(kind+'-'+label+'.json')).write_text(json.dumps(report,indent=2)+'\n')
        (OUT/'benchmarks.json').write_text(json.dumps(reports,indent=2)+'\n')


if __name__=='__main__':main()
