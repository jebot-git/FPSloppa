#!/usr/bin/env python3
"""Fresh version comparison using prepared projects; preserves previous captures."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import statistics
import subprocess
import time

from run import ROOT, PROJECTS, digest, distribution

MAPS = [('qsrc_dm6', 'tdm', 'quake'), ('ctf_katabatic', 'st', 'tribes'),
        ('de_dust2_rebuilt', 'de', 'cs16')]
ORDER = ['0.20', 'current', 'current', '0.20']

def write_json(path, data):
    path.write_text(json.dumps(data, indent=2) + '\n')

def settings(project, scene):
    source = ((ROOT / 'project.godot').read_text() if project == PROJECTS['current']
              else subprocess.check_output(['git', 'show', '0.20v:project.godot'], cwd=ROOT, text=True))
    source = re.sub(r'run/main_scene=.*', f'run/main_scene="res://{scene}.tscn"', source)
    source = re.sub(r'\[autoload\].*?(?=\[)', '', source, flags=re.S)
    (project / 'project.godot').write_text(source)

def prepare():
    baseline = PROJECTS['0.20']
    manifest = json.loads((baseline / 'deathmatch/maps/manifest.json').read_text())
    for name, _, _ in MAPS:
        row = next(row for row in manifest if row['id'] == name)
        original = ROOT / 'Builds/ConsoleServer/maps' / (name + '.bsp')
        assert digest(original) == row['sha256'], f'Wrong baseline BSP: {name}'
        shutil.copy2(original, baseline / 'maps' / original.name)
    shutil.copytree(ROOT / 'Builds/ConsoleServer/maps/navigation', baseline / 'maps/navigation', dirs_exist_ok=True)
    # One common test driver, calling each version's unchanged gameplay implementation.
    driver = (ROOT / 'deathmatch/tests/bot_soak.gd').read_text()
    driver = driver.replace('extends SceneTree\n', 'extends Node\nvar root: Window\n', 1)
    driver = driver.replace('func _initialize():run.call_deferred()',
                            'func _ready():\n root=get_tree().root\n run.call_deferred()')
    driver = driver.replace('await physics_frame', 'await get_tree().physics_frame')
    driver = driver.replace('await process_frame', 'await get_tree().process_frame')
    driver = re.sub(r'(?<![\w.])quit\(', 'get_tree().quit(', driver)
    driver = driver.replace(' result.physics_backend=',
        ' result.tick_samples_ms=ticks\n result.engine=Engine.get_version_info()\n result.physics_backend=')
    for project in PROJECTS.values():
        (project / '.godot/extension_list.cfg').write_text(
            'res://addons/fps_native/fps_native.gdextension\nres://addons/twovoip/twovoip.gdextension\n')
        for scene, script in [('version_fixture', (ROOT / 'tools/version_compare/fixture.gd').read_text()),
                              ('version_gameplay', driver)]:
            (project / (scene + '.gd')).write_text(script)
            (project / (scene + '.tscn')).write_text(
                '[gd_scene load_steps=2 format=3]\n'
                f'[ext_resource type="Script" path="res://{scene}.gd" id="1"]\n'
                f'[node name="Benchmark" type="Node"]\nscript=ExtResource("1")\n')
        settings(project, 'version_fixture')
    return driver

def execute(project, command, dest, timeout):
    start = time.monotonic()
    with Path(str(dest) + '.log').open('w') as log:
        completed = subprocess.run(command, cwd=project, stdout=log, stderr=subprocess.STDOUT,
            env=dict(os.environ, XDG_DATA_HOME='/tmp/fps-version-comparison-user-' + project.name), timeout=timeout)
    log = Path(str(dest) + '.log').read_text()
    errors = [line for line in log.splitlines() if 'ERROR:' in line or 'WARNING:' in line or 'leaked' in line]
    if completed.returncode or errors:
        raise RuntimeError(f'{dest.name}: exit={completed.returncode}, errors={errors}')
    data = json.loads(Path(str(dest) + '.json').read_text())
    data['wall_seconds'] = time.monotonic() - start
    return data

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--smoke', action='store_true')
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    driver = prepare()
    (out / 'gameplay_driver.gd').write_text(driver)
    shutil.copy2(ROOT / 'tools/version_compare/fixture.gd', out / 'render_driver.gd')
    sources = {p.relative_to(ROOT).as_posix(): digest(p)
        for folder in ['deathmatch', 'addons/vrm', 'addons/Godot-MToon-Shader', 'addons/fps_native/src']
        for p in (ROOT / folder).rglob('*')
        if p.is_file() and p.suffix in ['.gd', '.gdshader', '.scn', '.glb', '.png', '.cpp', '.h']}
    sources['project.godot'] = digest(ROOT / 'project.godot')
    write_json(out / 'current-sources.json', sources)
    manifest = dict(baseline_commit=subprocess.check_output(['git','rev-parse','0.20v^{}'], cwd=ROOT,text=True).strip(),
        current_head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        current_includes_working_tree=True, started_utc=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),
        source_manifest_sha256=digest(out / 'current-sources.json'),
        cpu=subprocess.check_output(['lscpu'], text=True), order=ORDER,
        scope='Same release runtime for both. Render: 8 animated avatars, 1440x900 Mobile, uncapped, 6s warmup + 20s capture. Gameplay: headless 16 bots, fixed 60Hz, 30 simulated seconds warmup + 60 measured, inclusive game._physics_process CPU only; excludes engine physics step outside callback. Own version maps/native/gameplay; AI trajectories diverge. Not VR/compositor or load-time measurements.',
        versions={})
    for version, project in PROJECTS.items():
        receipt=json.loads((project / 'addons/fps_native/bin/linux.json').read_text())
        assert digest(project / 'addons/fps_native/bin/libfpsloppa_native.so') == receipt['sha256']
        for name, sha in receipt['source_sha256'].items():
            assert digest(project / 'addons/fps_native' / name) == sha, f'Stale native: {version}/{name}'
        manifest['versions'][version] = dict(runtime_sha256=digest(project / 'FPSloppa'),
            native_receipt=receipt, settings=(project/'project.godot').read_text(),
            voice_library_sha256=digest(project/'addons/twovoip/libs/libtwovoip.linux.template_release.x86_64.so'),
            navigation={name:digest(project/'maps/navigation'/(name+'.res')) for name,_,_ in MAPS},
            maps={name:digest(project / 'maps' / (name+'.bsp')) for name,_,_ in MAPS})
    assert len({v['runtime_sha256'] for v in manifest['versions'].values()}) == 1
    write_json(out / 'manifest.json', manifest)
    render_rows=[]; game_rows=[]
    if not args.smoke:
        for variant in ['unarmed','armed']:
            for index, version in enumerate(ORDER):
                project=PROJECTS[version]; dest=out/f'render-{variant}-{index}-{version}'
                print('START',dest.name,flush=True)
                data=execute(project,[str(project/'FPSloppa'),'--xr-mode','off','--audio-driver','Dummy','--',str(dest),variant,'20','--no-avatar-disk-cache'], dest,90)
                meta=data['metadata']; frames=data['frames']
                assert meta['native_pose'] and meta['sleeping']==0 and meta['measured_seconds']>=20
                assert meta['main_cpu_ms_per_frame']>0 and all(f[2]>0 for f in frames)
                assert meta['physics_backend']==('JoltPhysicsDirectSpaceState3D' if version=='current' else 'GodotPhysicsDirectSpaceState3D')
                row=dict(version=version,variant=variant,run=index,frames=len(frames),metadata=meta,
                    **{key:distribution([f[i] for f in frames]) for i,key in enumerate(data['columns'])})
                render_rows.append(row);write_json(out/'render-runs.json',render_rows)
                print('DONE',dest.name,'mainCPU',round(meta['main_cpu_ms_per_frame'],3),'GPU',round(row['gpu_ms']['median'],3),flush=True)
    for project in PROJECTS.values():settings(project,'version_gameplay')
    for map_name,mode,rules in (MAPS[:1] if args.smoke else MAPS):
        for index,version in enumerate(['0.20','current'] if args.smoke else ORDER):
            project=PROJECTS[version];dest=out/f'gameplay-{map_name}-{index}-{version}'
            seconds=35 if args.smoke else 90
            options=dict(map=map_name,mode=mode,rules=rules,bots=16,seconds=seconds,
                         profile_tick=True,seed=20261001,output=str(dest)+'.json')
            print('START',dest.name,flush=True)
            data=execute(project,[str(project/'FPSloppa'),'--headless','--xr-mode','off','--fixed-fps','60',
                '--',json.dumps(options),'--asset-root',str(project),'--client-config','/tmp/fps-version-benchmark.cfg',
                '--no-avatar-disk-cache'],dest,240)
            assert len(data['bots'])==16 and data['simulated_seconds']>=seconds and data['actual_map']==map_name
            assert data['physics_backend']==('JoltPhysicsDirectSpaceState3D' if version=='current' else 'GodotPhysicsDirectSpaceState3D')
            row=dict(version=version,map=map_name,run=index,backend=data['physics_backend'],
                tick_ms=distribution(data['tick_samples_ms']),samples=len(data['tick_samples_ms']),
                distance=sum(b['distance'] for b in data['bots'].values()),shots=sum(b['shots'] for b in data['bots'].values()),
                damage=data['damage'],wall_seconds=data['wall_seconds'])
            assert row['distance']>100 and row['shots']>0
            game_rows.append(row);write_json(out/'gameplay-runs.json',game_rows)
            print('DONE',json.dumps(row),flush=True)
    for name,sha in sources.items():assert digest(ROOT/name)==sha,'Source changed: '+name
    for version,project in PROJECTS.items():
        assert digest(project/'addons/fps_native/bin/libfpsloppa_native.so')==manifest['versions'][version]['native_receipt']['sha256']
        for name,sha in manifest['versions'][version]['maps'].items():assert digest(project/'maps'/(name+'.bsp'))==sha
        settings(project,'version_fixture')
    summary=dict(manifest=manifest,render={},gameplay={})
    for variant in ['unarmed','armed'] if render_rows else []:
        values={}
        for version in PROJECTS:
            group=[r for r in render_rows if r['version']==version and r['variant']==variant]
            values[version]=dict(main_cpu_ms_per_frame=statistics.mean(r['metadata']['main_cpu_ms_per_frame'] for r in group),
                **{k:statistics.mean(r[k]['median'] for r in group) for k in ['frame_ms','render_cpu_ms','gpu_ms','draw_calls','primitives']},
                frame_p95_ms=statistics.mean(r['frame_ms']['p95'] for r in group))
        summary['render'][variant]=dict(versions=values,change_percent={k:100*(values['current'][k]/values['0.20'][k]-1) for k in values['0.20']})
    for name in sorted({r['map'] for r in game_rows}):
        values={version:{key:statistics.mean(r['tick_ms'][key] for r in game_rows if r['version']==version and r['map']==name)
            for key in ['median','mean','p95','p99']} for version in PROJECTS}
        summary['gameplay'][name]=dict(versions=values,change_percent={k:100*(values['current'][k]/values['0.20'][k]-1) for k in values['0.20']})
    write_json(out/'summary.json',summary)
    print('COMPLETE',out,flush=True)

if __name__=='__main__':main()
