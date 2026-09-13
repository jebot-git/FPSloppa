#!/usr/bin/env python3
"""Run renderer tests serially so GPU timings do not compete with each other."""
import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('suite', choices=['coverage', 'mtoon', 'shimmer', 'emission', 'ao', 'distribution-ao', 'material-audit', 'static', 'presentation', 'vesper-hole', 'surfaces', 'presentation-ui', 'candidates789', 'static-assets'])
    parser.add_argument('--renderer', choices=['mobile', 'gl_compatibility', 'both'], default='mobile', help='OpenGL options are historical diagnostics, not supported game configurations')
    parser.add_argument('--only-map', help='Coverage only: comma-separated maps to repeat, preserving other existing results')
    parser.add_argument('--depth-prepass', choices=['on', 'off'], help='Diagnostic isolated project override (shimmer/coverage)')
    parser.add_argument('--contrast', action='store_true', help='Static-assets suite: repeat with Contrast lighting')
    args = parser.parse_args()
    if args.contrast and args.suite != 'static-assets':parser.error('--contrast requires static-assets')
    folder = ROOT/('test-results/lighting-ao' if args.suite == 'ao' else 'test-results/lighting-coverage')
    if args.suite == 'distribution-ao':
        folder = ROOT/'test-results/lighting-ao-distribution'
    if args.suite == 'material-audit':
        folder = ROOT/'test-results/material-audit'
    if args.suite == 'static':
        folder = ROOT/'test-results/static-rendering'
    if args.suite in ('presentation', 'vesper-hole', 'surfaces', 'presentation-ui'):
        folder = ROOT/'test-results/map-presentation'
    if args.suite == 'candidates789':
        folder = ROOT/'test-results/candidates789'
    if args.suite == 'static-assets':
        folder = ROOT/'test-results/static-assets'
    folder.mkdir(parents=True, exist_ok=True)
    script = 'coverage_render' if args.suite == 'coverage' else args.suite
    if args.suite == 'distribution-ao':
        script = 'distribution_render'
    if args.suite == 'material-audit':
        script = 'material_audit'
    if args.suite == 'static':
        script = 'static_render'
    if args.suite == 'presentation':
        script = 'presentation_render'
    if args.suite == 'vesper-hole':
        script = 'vesper_hole'
    if args.suite == 'surfaces':
        script = 'surface_render'
    if args.suite == 'presentation-ui':
        script = 'presentation_ui'
    if args.suite == 'static-assets':
        script = 'static_assets_render'
    script_path = f'res://tools/lighting_experiment/{script}.gd'
    if args.suite == 'candidates789':
        script_path = 'res://tools/lighting_experiment/candidates789/render.gd'
    if args.suite == 'emission':
        script_path = 'res://deathmatch/tests/avatar_surface_probe.gd'
    if args.depth_prepass and args.suite not in ('shimmer', 'coverage'):
        parser.error('--depth-prepass is only supported by shimmer/coverage')
    temporary = tempfile.TemporaryDirectory(prefix='fpsloppa-lighting-') if args.depth_prepass else None
    project = ROOT
    if temporary:
        project = Path(temporary.name)
        for entry in ROOT.iterdir():
            if entry.name not in ('project.godot', 'override.cfg', '.git'):
                (project/entry.name).symlink_to(entry, target_is_directory=entry.is_dir())
        (project/'project.godot').write_text((ROOT/'project.godot').read_text())
        enabled = 'true' if args.depth_prepass == 'on' else 'false'
        (project/'override.cfg').write_text(f'[rendering]\ndriver/depth_prepass/enable={enabled}\n')
    for renderer in ['mobile', 'gl_compatibility'] if args.renderer == 'both' else [args.renderer]:
        label = f'{args.suite}-{renderer}' + ('-contrast' if args.contrast else '') + (f'-prepass-{args.depth_prepass}' if args.depth_prepass else '')
        output = folder/f'{label}.log'
        with output.open('w') as log:
            command = ['godot', '--xr-mode', 'off', '--path', str(project),
                '--rendering-method', renderer, '--log-file', str(folder/f'engine-{label}.log'),
                '--script', script_path]
            user_args = ['--contrast'] if args.contrast else []
            if args.only_map:
                assert args.suite == 'coverage'
                user_args += ['--only-map', args.only_map]
            if args.depth_prepass:
                user_args += ['--depth-prepass', args.depth_prepass]
            if user_args:
                command += ['--'] + user_args
            completed = subprocess.run(command, cwd=ROOT,
                stdout=log, stderr=subprocess.STDOUT, timeout=900 if args.suite in ('distribution-ao', 'candidates789', 'static-assets') else 300)
        print(renderer, 'exit', completed.returncode, 'log', output, flush=True)
        if completed.returncode:
            raise SystemExit(completed.returncode)
    if temporary:
        temporary.cleanup()


if __name__ == '__main__':
    main()
