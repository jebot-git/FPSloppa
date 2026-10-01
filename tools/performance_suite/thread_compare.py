#!/usr/bin/env python3
"""Compare engine threading in disposable projects using the same release runtime."""
import argparse
from collections import defaultdict
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import statistics
import subprocess
import sys
import time

from analyze import distribution
from prepare import ROOT, prepare
from run import fingerprint

sys.path.insert(0, str(ROOT / 'tools'))
from renderer_policy import require_client_template

VARIANTS = {'baseline': (1, False), 'render': (2, False),
            'physics': (1, True), 'both': (2, True)}


def project_settings(source, scene, variant):
    render, physics = VARIANTS[variant]
    source = re.sub(r'^run/main_scene=.*$', f'run/main_scene="{scene}"', source, flags=re.M)
    for section, key, value in [('rendering', 'driver/threads/thread_model', str(render)),
                                ('physics', '3d/run_on_separate_thread', str(physics).lower())]:
        source = re.sub(r'^' + re.escape(key) + r'=.*\n', '', source, flags=re.M)
        source = source.replace(f'[{section}]', f'[{section}]\n\n{key}={value}', 1)
    return source


def driver_source():
    # Share the existing deterministic avatar/effects fixture. Release templates
    # require a main-scene Node instead of the editor's --script SceneTree entry.
    source = (ROOT / 'tools/performance_suite/client.gd').read_text()
    replacements = {
        'extends SceneTree': 'extends Node\nvar root: Window',
        'func _initialize() -> void:run.call_deferred()':
            'func _ready() -> void:\n\troot=get_tree().root\n\trun.call_deferred()',
        'current_scene=game': 'get_tree().current_scene=game',
        'quit(2)': 'get_tree().quit(2)',
        'func _process(delta: float) -> bool:': 'func _process(delta: float) -> void:',
        'return false': 'return',
        '\tif not config.live:\n': '''
	var vest: Dictionary=game.haptics.values.duplicate();vest.enabled=false;game.haptics.configure(vest)
	var observed:={"main_thread_id":OS.get_thread_caller_id(),"render_model":ProjectSettings.get_setting("rendering/driver/threads/thread_model",1),"physics_thread":ProjectSettings.get_setting("physics/3d/run_on_separate_thread",false),"physics_engine":ProjectSettings.get_setting("physics/3d/physics_engine","DEFAULT")}
	var settings_file:=FileAccess.open(config.output.path_join("thread-settings.json"),FileAccess.WRITE)
	settings_file.store_string(JSON.stringify(observed));settings_file.close()
	print("THREADING_SETTINGS ",JSON.stringify(observed))
	if config.live:
		game.xr_rig.tracking.enabled=true
		var deadline:=Time.get_ticks_msec()+90000
		while (not game.active or game.map_loading) and Time.get_ticks_msec()<deadline:await get_tree().create_timer(.25).timeout
		if not game.active or game.map_loading:push_error("Private lab did not become ready");game.request_quit();return
		game.chat_send("/lab cs16")
		await get_tree().create_timer(3).timeout
		game.chat_send("/lab target 5")
		game._announcement("THREADING TEST: "+str(config.thread_variant).to_upper()+" · Repeat the same weapon sequence")
	if not config.live:
''',
    }
    for old, new in replacements.items():
        if old not in source:
            raise ValueError(f'Threading fixture entry point changed: {old}')
        source = source.replace(old, new)
    return source


def sample_threads(pid):
    threads = []
    for folder in (Path('/proc') / str(pid) / 'task').glob('*'):
        try:
            stat = (folder / 'stat').read_text().rsplit(')', 1)[1].split()
            sched = (folder / 'schedstat').read_text().split()
            threads.append(dict(tid=int(folder.name), name=(folder / 'comm').read_text().strip(),
                cpu_ns=int(sched[0]), runqueue_ns=int(sched[1]), core=int(stat[36])))
        except (OSError, ValueError, IndexError):
            pass
    return dict(monotonic_ns=time.monotonic_ns(), unix_ns=time.time_ns(), threads=threads)


def analyze_run(folder, pid):
    metadata = json.loads((folder / 'metadata.json').read_text())
    frames = [json.loads(line) for line in (folder / 'frames.jsonl').read_text().splitlines()]
    if not metadata['complete'] or not frames or len(frames) != metadata['frames']:
        raise ValueError('Incomplete capture')
    if any(b['ticks_us']<=a['ticks_us'] for a,b in zip(frames,frames[1:])):
        raise ValueError('Nonmonotonic frame timestamps')
    if metadata.get('xr') and abs(metadata.get('refresh_hz',0)-metadata['budget_hz'])>.5:
        raise ValueError('Headset refresh rate differs from configured budget')
    eligible = [f for f in frames if f['active'] and not f['menu'] and f.get('focused', True)]
    samples = [json.loads(line) for line in (folder / 'threads.jsonl').read_text().splitlines()]
    offset = statistics.median(s['unix_ns'] - s['monotonic_ns'] for s in samples)
    origin = metadata['utc_start'] * 1e9 - offset - metadata['ticks_start_us'] * 1000
    lo = origin + metadata['measurement_start_us'] * 1000
    hi = origin + metadata['measurement_end_us'] * 1000
    usage = defaultdict(lambda: dict(cpu_ns=0, queue_ns=0, name='', cores=set()))
    duration = 0
    # CPU covers the full measurement window; focus-filtered frame stats are separate.
    for first, second in zip(samples, samples[1:]):
        if not lo <= first['monotonic_ns'] < second['monotonic_ns'] <= hi:
            continue
        duration += second['monotonic_ns'] - first['monotonic_ns']
        before = {t['tid']: t for t in first['threads']}
        for t in second['threads']:
            if t['tid'] not in before:
                continue
            u = usage[t['tid']]; old = before[t['tid']]
            u['cpu_ns'] += max(0, t['cpu_ns'] - old['cpu_ns'])
            u['queue_ns'] += max(0, t['runqueue_ns'] - old['runqueue_ns'])
            u['name'] = t['name']; u['cores'].add(t['core'])
    threads = sorted([dict(tid=tid, name=u['name'], core_equivalents=u['cpu_ns']/duration,
        runqueue_ms=u['queue_ns']/1e6, sampled_cores=sorted(u['cores'])) for tid,u in usage.items()],
        key=lambda t:-t['core_equivalents']) if duration else []
    result = dict(metadata=metadata, frames=len(frames), eligible_frames=len(eligible),
        all_frame_ms=distribution([f['frame_ms'] for f in frames]),
        focused_frame_ms=distribution([f['frame_ms'] for f in eligible]),
        over_20ms_pct=100*sum(f['frame_ms']>20 for f in eligible)/len(eligible) if eligible else None,
        threads=threads, cpu_window_seconds=duration/1e9,
        total_core_equivalents=sum(t['core_equivalents'] for t in threads),
        main_core_equivalents=sum(t['core_equivalents'] for t in threads if t['tid']==pid),
        monitors={k:distribution([f[k] for f in eligible if f[k]>0]) for k in
            ['process_ms','physics_ms','render_cpu_ms','render_gpu_ms','draw_calls']})
    (folder / 'thread-report.json').write_text(json.dumps(result, indent=2)+'\n')
    return result


def stop(process):
    if process.poll() is None:
        process.terminate()
        try: process.wait(timeout=5)
        except subprocess.TimeoutExpired: process.kill(); process.wait()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--seconds', type=float, default=30)
    parser.add_argument('--warmup', type=float, default=10)
    parser.add_argument('--repeats', type=int, default=2)
    parser.add_argument('--variants', nargs='+', choices=VARIANTS, default=list(VARIANTS))
    parser.add_argument('--live', action='store_true')
    parser.add_argument('--connect', default='127.0.0.1')
    parser.add_argument('--port', type=int, default=27777)
    parser.add_argument('--prepare-only', action='store_true')
    args=parser.parse_args()
    if not 1<=args.seconds<=300 or not 0<=args.warmup<=60 or not 1<=args.repeats<=8:
        parser.error('Use seconds 1–300, warmup 0–60, repeats 1–8')
    out=(args.output or ROOT/'test-results/threading'/datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')).resolve()
    if out.exists(): parser.error('Output must be a new directory')
    out.relative_to(ROOT)
    out.mkdir(parents=True)
    generated=out/'generated'; generated.mkdir()
    scene=prepare(generated/'instrumented')
    (generated/'driver.gd').write_text(driver_source())
    prefix='res://'+generated.relative_to(ROOT).as_posix()+'/'
    (generated/'driver.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="'+prefix+'driver.gd" id="1"]\n[node name="ThreadingTest" type="Node"]\nscript=ExtResource("1")\n')
    runtime=out/'runtime'; runtime.mkdir(); (runtime/'.gdignore').touch()
    for path in ROOT.iterdir():
        if path.name=='Builds' or (path.name.startswith('.') and path.name!='.godot'):
            continue
        if path.name!='project.godot': (runtime/path.name).symlink_to(path, target_is_directory=path.is_dir())
    template=require_client_template('linuxbsd')
    shutil.copy2(template, runtime/'FPSloppa')
    source_hash=fingerprint()
    order=[v for n in range(args.repeats) for v in (args.variants if n%2==0 else args.variants[::-1])]
    plan=[]
    for index,variant in enumerate(order):
        folder=out/f'{index:02d}-{variant}';folder.mkdir()
        config=dict(stage='profile',capture='none',variant='full',live=args.live,seconds=args.seconds,
            warmup=args.warmup,refresh_hz=72,rules='cs16',scene=scene,output=str(folder),
            source_hash=source_hash,thread_variant=variant,runtime_sha256=hashlib.sha256(template.read_bytes()).hexdigest())
        (folder/'config.json').write_text(json.dumps(config,indent=2)+'\n')
        plan.append(dict(folder=str(folder),variant=variant))
    (out/'plan.json').write_text(json.dumps(plan,indent=2)+'\n')
    print('Prepared',out,flush=True)
    if args.prepare_only:return
    results=[];invalid=set()
    for item in plan:
        folder=Path(item['folder']);variant=item['variant']
        if variant in invalid:
            results.append(dict(variant=variant,folder=str(folder),status='skipped_after_failure'));continue
        (runtime/'project.godot').write_text(project_settings((ROOT/'project.godot').read_text(),prefix+'driver.tscn',variant))
        command=[str(runtime/'FPSloppa'),'--xr-mode','on' if args.live else 'off','--log-file',str(folder/'engine.log'),
                 '--','--suite-config',str(folder/'config.json')]
        if args.live:command+=['--connect',args.connect,'--port',str(args.port)]
        print('START',folder.name,flush=True)
        code=None;failure=None
        with (folder/'console.log').open('w') as log, (folder/'threads.jsonl').open('w') as monitor:
            process=subprocess.Popen(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
            (folder/'process.json').write_text(json.dumps(dict(pid=process.pid,command=command)))
            deadline=time.monotonic()+args.seconds+args.warmup+120
            try:
                while process.poll() is None:
                    monitor.write(json.dumps(sample_threads(process.pid))+'\n');monitor.flush()
                    if time.monotonic()>deadline:raise TimeoutError('Client exceeded bounded runtime')
                    time.sleep(.1)
                code=process.returncode
                log_text=(folder/'console.log').read_text()
                if code:raise RuntimeError(f'Client exit {code}')
                rejected = 'ERROR:' in log_text or 'ObjectDB instances were leaked' in log_text
                if fingerprint()!=source_hash:raise RuntimeError('Source changed during capture')
                report=analyze_run(folder,process.pid)
                expected=VARIANTS[variant]
                observed=json.loads((folder/'thread-settings.json').read_text())
                if (observed['render_model'],observed['physics_thread'])!=expected:
                    raise RuntimeError('Effective thread settings differ from requested settings')
                summary={k:report[k] for k in ['frames','eligible_frames','all_frame_ms','focused_frame_ms',
                    'over_20ms_pct','total_core_equivalents','main_core_equivalents','monitors']}
                status='rejected_engine_errors' if rejected else 'ok'
                results.append(dict(variant=variant,folder=str(folder),status=status,**summary))
                print('DONE',folder.name,status,json.dumps(summary),flush=True)
            except (OSError,ValueError,RuntimeError,TimeoutError) as error:
                failure=str(error);invalid.add(variant)
                results.append(dict(variant=variant,folder=str(folder),status='failed',error=failure))
                print('FAILED',folder.name,failure,flush=True)
            finally:stop(process)
        (out/'comparison.json').write_text(json.dumps(results,indent=2)+'\n')
    print('Finished',out,flush=True)


if __name__=='__main__':main()
