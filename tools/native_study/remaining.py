"""Profile remaining native candidates using disposable instrumented scripts.

Run --network, --avatars (requires a display), or --server (local ENet socket).
Production scripts and user settings are never modified.
"""
from pathlib import Path
import argparse
import json
import os
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'test-results/remaining-native'
PREFIX = 'res://test-results/remaining-native/'


def read(path):
    return (ROOT / path).read_text()


def write(name, source):
    (OUT / name).write_text(source)


def instrument(source, names):
    source += '\nstatic var remaining_audit: Dictionary={}\n'
    for name, args in names.items():
        match = re.search(r'^(static )?func '+name+r'\((.*)\) -> (\w+):$', source, re.M)
        assert match, name
        declaration = match.group(0)
        result = match.group(3)
        source = source[:match.start()] + declaration.replace('func '+name+'(', 'func audit_original_'+name+'(') + source[match.end():]
        source += '\n'+declaration+'\n\tvar audit_start:=Time.get_ticks_usec()\n'
        call = f'audit_original_{name}({args})'
        source += ('\t'+call if result == 'void' else '\tvar audit_result: '+result+'='+call)+'\n'
        source += '\tvar audit_elapsed:=Time.get_ticks_usec()-audit_start\n'
        source += f'\tif not remaining_audit.has("{name}"):remaining_audit["{name}"]=[0,0]\n'
        source += f'\tremaining_audit["{name}"][0]+=audit_elapsed;remaining_audit["{name}"][1]+=1\n'
        if result != 'void':
            source += '\treturn audit_result\n'
    return source


def avatars():
    for filename in ['pose', 'pose_blend', 'rig', 'visual_loader', 'distance_lod']:
        source = read('deathmatch/avatars/'+filename+'.gd')
        for dependency in ['pose', 'pose_blend', 'rig', 'distance_lod']:
            source = source.replace('res://deathmatch/avatars/'+dependency+'.gd', PREFIX+dependency+'.gd')
        if filename == 'pose_blend':
            source += '\nconst Metrics=preload("res://deathmatch/avatars/animation_metrics.gd")\n'
            source = source.replace('func push(', 'func audit_push(')
            source += '\nfunc push(pose: Dictionary,seconds: float) -> void:\n\tvar started:=Metrics.begin()\n\taudit_push(pose,seconds)\n\tMetrics.end("blend_push",started)\n'
        if filename == 'distance_lod':
            source += '\nconst Metrics=preload("res://deathmatch/avatars/animation_metrics.gd")\n'
            source = source.replace('func _process_modification_with_delta(', 'func audit_modify(')
            source += '\nfunc _process_modification_with_delta(delta: float) -> void:\n\tvar started:=Metrics.begin()\n\taudit_modify(delta)\n\tMetrics.end("distance_modifier",started)\n'
        # Inline timers avoid adding an artificial native proxy boundary.
        lines = []
        for line in source.splitlines():
            label = None
            if re.match(r'\s+native_pose\.', line):
                label = 'native_'+line.strip().split('.')[1].split('(')[0]
            elif 'var hit: Dictionary = rig.get_world_3d().direct_space_state.intersect_ray' in line:
                label = 'floor_ray'
            elif line.startswith('\tgait.update('):
                label = 'gait'
            elif line.startswith('\tvar generic: bool=distance_lod.update'):
                label = 'lod'
            indent = line[:len(line)-len(line.lstrip())]
            if label:
                lines += [indent+'var audit_'+label+':=Metrics.begin()', line.replace(';return', ''), indent+'Metrics.end("'+label+'",audit_'+label+')']
                if ';return' in line:
                    lines.append(indent+'return')
            else:
                lines.append(line)
        source = '\n'.join(lines)+'\n'
        if filename == 'rig':
            source = source.replace('\tif target_xr_pose.is_empty(): xr_pose.clear()', '\tvar tracking_started:=Metrics.begin()\n\tif target_xr_pose.is_empty(): xr_pose.clear()')
            source = source.replace('\t# Rotate only', '\tMetrics.end("tracking",tracking_started)\n\t# Rotate only')
        write(filename+'.gd', source)
    source = read('tools/avatar_lod/benchmark_animation.gd').replace('res://deathmatch/avatars/visual_loader.gd', PREFIX+'visual_loader.gd')
    write('benchmark_animation.gd', source)
    source = read('tools/avatar_lod/frametime_study.gd').replace('res://tools/avatar_lod/benchmark_animation.gd', PREFIX+'benchmark_animation.gd').replace('test-results/frametime-study', 'test-results/remaining-native')
    write('avatars.gd', source)


def server():
    for filename, methods in {
        'fighter': {'simulate':'input,yaw,slow,delta,jump,swim', 'step_up':'travel,height'},
        'bots': {'tick':'delta', 'perceive':'id,brain', 'plan':'id,brain', 'combat':'id,brain,delta', 'steer':'id,brain,delta', 'visible':'id,other'},
        'bot_ai/navigation': {'path':'start,goal,allow_jump', 'cost':'start,goal,route', 'ray':'a,b'},
        'arena': {'_server_tick':'delta', '_collect':'id,used_drop', '_update_projectiles':'delta,movement_start', '_record_history':'', '_update_melee':'id', '_rewound_positions':'rewind', '_rewound_heights':'rewind', '_rewound_yaws':'rewind'},
    }.items():
        source = instrument(read('deathmatch/'+filename+'.gd'), methods)
        for dependency in ['fighter', 'bots', 'bot_ai/navigation']:
            source = source.replace('res://deathmatch/'+dependency+'.gd', PREFIX+dependency.replace('/', '_')+'.gd')
        if filename == 'fighter':
            source = source.replace('move_and_slide()', 'audit_move_and_slide()')
            source += '\nfunc audit_move_and_slide() -> bool:\n\tvar started:=Time.get_ticks_usec()\n\tvar result:=move_and_slide()\n\tif not remaining_audit.has("engine_slide"):remaining_audit.engine_slide=[0,0]\n\tremaining_audit.engine_slide[0]+=Time.get_ticks_usec()-started;remaining_audit.engine_slide[1]+=1\n\treturn result\n'
        write(filename.replace('/', '_')+'.gd', source)


def network():
    write('codec.gd', instrument(read('deathmatch/network/codec.gd'), {'encode':'value', 'decode':'raw'}))
    write('snapshot_codec.gd', read('deathmatch/network/snapshot_codec.gd').replace('res://deathmatch/network/codec.gd', PREFIX+'codec.gd'))
    write('replication.gd', read('deathmatch/network/replication.gd').replace('res://deathmatch/network/snapshot_codec.gd', PREFIX+'snapshot_codec.gd'))
    source = read('tools/native_study/remaining_network.gd').replace('res://deathmatch/network/replication.gd', PREFIX+'replication.gd')
    source = source.replace('\t\tfor tick in 140:', '\t\tvar audit=preload("'+PREFIX+'codec.gd")\n\t\tfor tick in 140:\n\t\t\tif tick==20:audit.remaining_audit.clear()')
    source = source.replace('"encode":stats(send_times)', '"compact_codec_us_and_calls":audit.remaining_audit.duplicate(true),"encode":stats(send_times)')
    write('network.gd', source)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['network', 'avatars', 'server']:
        parser.add_argument('--'+name, action='store_true')
    parser.add_argument('--reference', action='store_true', help='Uninstrumented server control')
    parser.add_argument('--codec-scopes', action='store_true', help='Include nested compact codec scopes in network probe')
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    if args.avatars:
        avatars()
    if args.server:
        server()
    if args.network and args.codec_scopes:
        network()
    reports = {}
    for name in ['network', 'avatars', 'server']:
        if not getattr(args, name):
            continue
        script = PREFIX+'avatars.gd' if name == 'avatars' else 'res://tools/native_study/remaining_'+name+'.gd'
        if name == 'network' and args.codec_scopes:
            script = PREFIX+'network.gd'
        label = name+('-reference' if args.reference else '-scopes' if args.codec_scopes else '')
        command = ['godot', *([] if name == 'avatars' else ['--headless']), '--xr-mode', 'off', '--path', str(ROOT), '--script', script, '--', *(['--reference'] if args.reference else []), '--client-config', '/tmp/fps-remaining.cfg']
        result = subprocess.run(command, cwd=ROOT, env=dict(os.environ, XDG_DATA_HOME='/tmp/fpsloppa-remaining-native'), text=True, capture_output=True, timeout=180)
        output = result.stdout+result.stderr
        write(label+'.log', output)
        if result.returncode or 'SCRIPT ERROR' in output or 'FAIL ' in output:
            raise RuntimeError(label+' failed; see '+str(OUT/(label+'.log')))
        for line in output.splitlines():
            if line.startswith('REMAINING_RESULT '):
                reports[name] = json.loads(line[len('REMAINING_RESULT '):])
                write(label+'.json', json.dumps(reports[name], indent=2)+'\n')
        print(label, 'PASS', flush=True)


if __name__ == '__main__':
    main()
