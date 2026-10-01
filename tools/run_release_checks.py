#!/usr/bin/env python3
"""Run release regression checks with isolated user settings and JSON evidence."""
from pathlib import Path
import argparse, json, os, subprocess, tempfile, time
ROOT=Path(__file__).resolve().parents[1]
TESTS='native_acceleration native_codec native_network_packing native_bots native_rewind native_shot_history native_avatar_channels native_springs frame_smoothness render_motion cs16_accuracy cs16_mag_pull defusal defusal_bot_behavior foveation client_preferences network_delivery avatar_runtime_cache avatar_surface_compile menu_navigation bhaptics_profile bhaptics_native effect_resources weapon_audio_levels weapon_actions weapon_presentation tribes_image_enhancer tribes_arsenal cs16_sights cs16_art weapon_setup climax_music mode_audio music release_scope'.split()
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('tests',nargs='*',default=TESTS)
    parser.add_argument('--resume',action='store_true',help='Keep successful checks from this release run')
    args=parser.parse_args()
    version=(ROOT/'VERSION').read_text().strip()
    out=ROOT/'test-results'/('release-'+version);out.mkdir(parents=True,exist_ok=True)
    reports=json.loads((out/'checks.json').read_text()) if args.resume and (out/'checks.json').exists() else []
    reports=[r for r in reports if r['passed']]
    missing=[n for n in args.tests if not (ROOT/'deathmatch/tests'/(n+'.gd')).is_file()]
    if missing:raise RuntimeError('Unknown tests: '+', '.join(missing))
    for name in args.tests:
        if any(r['test']==name for r in reports):continue
        script=ROOT/'deathmatch/tests'/(name+'.gd')
        if not script.is_file():raise RuntimeError('Unknown test: '+name)
        start=time.monotonic();log=out/(name+'.log')
        with tempfile.TemporaryDirectory(prefix='fps-release-'+name+'-') as temp:
            env=dict(os.environ,XDG_CONFIG_HOME=temp+'/config',XDG_DATA_HOME=temp+'/data')
            if name=='bhaptics_native':env['DBUS_SYSTEM_BUS_ADDRESS']='unix:path=/tmp/fpsloppa-bhaptics-unavailable.sock'
            command=[os.environ.get('GODOT_BIN','godot'),'--headless','--xr-mode','off','--path',str(ROOT),'--script','res://deathmatch/tests/'+name+'.gd','--','--client-config',temp+'/client.cfg']
            if name in {'music','climax_music'}:
                command=command[:command.index('--')+1]+[temp+'/music',str(ROOT/'deathmatch/audio/music/please_hold.ogg'),temp+'/music-result.json','--client-config',temp+'/client.cfg']
            try:
                with log.open('w') as stream:code=subprocess.run(command,stdout=stream,stderr=subprocess.STDOUT,env=env,timeout=240).returncode
            except subprocess.TimeoutExpired:code=124
        text=log.read_text();errors=[line for line in text.splitlines() if line.startswith('FAIL ') or 'SCRIPT ERROR' in line or 'Parse Error' in line]
        results=[]
        for line in text.splitlines():
            if ' {' not in line:continue
            try:row=json.loads(line[line.index('{'):])
            except json.JSONDecodeError:continue
            if isinstance(row,dict) and 'failures' in row:results.append(row)
        report=dict(test=name,exit=code,passed=code==0 and not errors and all(not r['failures'] for r in results),seconds=round(time.monotonic()-start,2),checks=max(sum(line.startswith('PASS ') for line in text.splitlines()),sum(int(r.get('checks',0)) for r in results)),results=results,errors=errors,log=str(log.relative_to(ROOT)))
        reports.append(report);print(name,'PASS' if report['passed'] else 'FAIL',report['checks'],flush=True)
        (out/'checks.json').write_text(json.dumps(reports,indent=2)+'\n')
    return 0 if all(r['passed'] for r in reports) else 1
if __name__=='__main__':raise SystemExit(main())
