#!/usr/bin/env python3
"""Repeatable opt-in timing, capture-overhead, and targeted-profile runs."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess
import time

from analyze import write_report
from prepare import ROOT, prepare


def matrix(stage, repeats):
    cases = {'timing':[('buffered','full')],
             'overhead':[('none','full'),('immediate','full'),('buffered','full')],
             'profile':[('none','full'),('none','no-effects'),('none','frozen'),('none','hidden')]}[stage]
    # Reverse each second block to reduce monotonic warmup/thermal bias.
    return [case for block in range(repeats) for case in (cases if block%2==0 else cases[::-1])]


def fingerprint():
    digest = hashlib.sha256()
    paths = subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode().split('\0')
    paths += [str(p.relative_to(ROOT)) for p in (ROOT/'tools/performance_suite').glob('*') if p.is_file()]
    paths += ['addons/bhaptics_native/bin/libfpsloppa_bhaptics_native.so']
    for name in sorted(set(paths)):
        p=ROOT/name
        if p.is_file() and (p.suffix in ('.gd','.py','.json','.tscn','.godot','.gdshader','.so') or name=='project.godot'):
            digest.update(name.encode());digest.update(p.read_bytes())
    return digest.hexdigest()


def clock_anchor():
    before=time.monotonic_ns();wall=time.time_ns();after=time.monotonic_ns()
    return {'unix_ns':wall,'monotonic_ns':(before+after)//2,'sample_uncertainty_ns':after-before}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage',choices=['timing','overhead','profile','analyze','doctor'])
    parser.add_argument('--output',type=Path)
    parser.add_argument('--godot',default='godot')
    parser.add_argument('--seconds',type=float,default=60)
    parser.add_argument('--warmup',type=float,default=10)
    parser.add_argument('--repeats',type=int,default=2)
    parser.add_argument('--refresh-hz',type=float,default=72)
    parser.add_argument('--rules',choices=['cs16','doom','quake','ut99'],default='cs16')
    parser.add_argument('--live',action='store_true',help='Use real OpenXR client and saved settings; no synthetic input')
    parser.add_argument('--connect',help='Optional existing test-server address for live runs')
    parser.add_argument('--port',type=int,default=27777)
    parser.add_argument('--wivrn-capture',type=Path,help='Installed WiVRn tools/perfetto/wivrn_capture.py, runtime already tracing with system backend')
    parser.add_argument('--prepare-only',action='store_true')
    args=parser.parse_args()
    if args.stage=='doctor':
        print(json.dumps({'godot':shutil.which(args.godot),'wivrn':shutil.which('wivrn-server'),
            'capture_script':str(args.wivrn_capture) if args.wivrn_capture and args.wivrn_capture.is_file() else None,
            'runtime_tracing':'Must be explicitly enabled in a tracing-capable WiVRn build; executable presence does not establish support.',
            'instructions':str(ROOT/'tools/performance_suite/README.md')},indent=2));return
    if args.stage=='analyze':
        if not args.output:parser.error('analyze requires --output')
        result=write_report(args.output.resolve());print(json.dumps(result['comparison'],indent=2));return
    if not all(math.isfinite(v) for v in [args.seconds,args.warmup,args.refresh_hz]) or not 1<=args.seconds<=1800 or not 0<=args.warmup<=120 or not 30<=args.refresh_hz<=240 or not 1<=args.repeats<=10:
        parser.error('Use seconds 1–1800, warmup 0–120, refresh 30–240 Hz, repeats 1–10')
    if args.connect and not args.live:parser.error('--connect requires --live')
    if args.live and args.stage=='profile':
        # Live profiling measures current tracking/effects; never disable the wearer's representation.
        cases=[('none','full')]*args.repeats
    else:cases=matrix(args.stage,args.repeats)
    folder=(args.output or ROOT/'test-results/performance-suite'/datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')).resolve()
    if folder.exists():parser.error('Output must be a new directory; existing captures are never overwritten')
    folder.mkdir(parents=True)
    # Resource paths must live in the Godot project, even if results go elsewhere.
    generated=ROOT/'test-results/performance-suite/generated'/folder.name
    if generated.exists():parser.error('Generated resource directory already exists; choose a unique output name')
    scene=prepare(generated)
    source_hash=fingerprint()
    plan=[]
    for index,(capture,variant) in enumerate(cases):
        output=folder/f'{index:02d}-{capture}-{variant}';output.mkdir()
        config={'stage':args.stage,'capture':capture,'variant':variant,'live':args.live,
            'seconds':args.seconds,'warmup':args.warmup,'refresh_hz':args.refresh_hz,
            'rules':args.rules,'scene':scene,'output':str(output),'source_hash':source_hash}
        config_path=output/'config.json';config_path.write_text(json.dumps(config,indent=2)+'\n')
        command=[args.godot,'--path',str(ROOT),'--xr-mode','on' if args.live else 'off',
            '--log-file',str(output/'engine.log'),'--script','res://tools/performance_suite/client.gd','--','--suite-config',str(config_path)]
        if args.connect:command+=['--connect',args.connect,'--port',str(args.port)]
        plan.append({'config':str(config_path),'command':command})
    (folder/'plan.json').write_text(json.dumps(plan,indent=2)+'\n')
    print(f'Prepared {len(plan)} captures in {folder}',flush=True)
    if args.prepare_only:return
    if not shutil.which(args.godot):parser.error('Godot executable unavailable')
    if args.wivrn_capture and (not args.live or not args.wivrn_capture.is_file()):parser.error('WiVRn capture requires --live and an existing wrapper script')
    for item in plan:
        output=Path(item['config']).parent
        anchors={'before':clock_anchor()};trace=None
        with (output/'console.log').open('w') as log:
            process=subprocess.Popen(item['command'],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
            deadline=time.monotonic()+args.seconds+args.warmup+180
            try:
                while process.poll() is None:
                    if time.monotonic()>deadline:raise TimeoutError('Game capture exceeded bounded runtime')
                    if args.wivrn_capture and trace is None and 'PERFORMANCE_SUITE_READY' in (output/'console.log').read_text():
                        with (output/'compositor.log').open('w') as trace_log:
                            trace=subprocess.Popen(['python3',str(args.wivrn_capture),'--duration-ms',str(math.ceil((args.seconds+args.warmup)*1000)),'-o',str(output/'compositor.pftrace')],stdout=trace_log,stderr=subprocess.STDOUT)
                    time.sleep(.25)
                if process.returncode:raise RuntimeError(f'Godot failed ({process.returncode}); inspect {output}/console.log')
                if trace is not None:
                    code=trace.wait(timeout=45)
                    trace_path=output/'compositor.pftrace'
                    if code or not trace_path.exists() or not trace_path.stat().st_size:raise RuntimeError('Compositor capture failed; inspect compositor.log')
            finally:
                for child in (process,trace):
                    if child is not None and child.poll() is None:
                        child.terminate()
                        try:child.wait(timeout=5)
                        except subprocess.TimeoutExpired:child.kill();child.wait()
                anchors['after']=clock_anchor();(output/'clock.json').write_text(json.dumps(anchors,indent=2)+'\n')
        if not (output/'metadata.json').exists():raise RuntimeError(f'Capture did not finish: {output}')
        if fingerprint()!=source_hash:raise RuntimeError('Source changed during capture; rerun with a stable checkout')
        if 'SCRIPT ERROR:' in (output/'console.log').read_text() or '\nERROR:' in (output/'console.log').read_text():
            raise RuntimeError(f'Engine errors invalidate capture: {output}/console.log')
        print(f'Captured {output.name}',flush=True)
    result=write_report(folder)
    print(json.dumps(result['comparison'],indent=2))

if __name__=='__main__':main()
