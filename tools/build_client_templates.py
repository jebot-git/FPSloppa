#!/usr/bin/env python3
"""Build pinned Godot release templates with the OpenGL backend excluded."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
VERSION = '4.7.2-stable'
SOURCE_SHA256 = 'e954996374cbd1cb5d72e0e3781cc537408e6ce73b010b12c6c2f308a820690a'
NAMES = {'linuxbsd': 'linux.x86_64', 'windows': 'windows.x86_64.exe', 'android': 'godot-lib.template_release.aar'}
PATCHES = ['openxr-shutdown.patch']


def patch_hashes():
    return {name: hashlib.sha256((ROOT / 'tools/patches' / name).read_bytes()).hexdigest() for name in PATCHES}


def patch_source(source):
    for name in PATCHES:
        patch = ROOT / 'tools/patches' / name
        command = ['patch', '--batch', '-p1', '-i', str(patch)]
        forward = subprocess.run([*command, '--forward', '--dry-run'], cwd=source, capture_output=True)
        if forward.returncode == 0:
            subprocess.run([*command, '--forward'], cwd=source, check=True)
        elif subprocess.run([*command, '--reverse', '--dry-run'], cwd=source, capture_output=True).returncode:
            raise RuntimeError(f'Engine patch does not match source: {name}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('platform', choices=NAMES)
    parser.add_argument('--scons', default=shutil.which('scons'), help='Path to SCons (install in your build environment)')
    parser.add_argument('--container', action='store_true', help='Build with the pinned Ubuntu 22.04 client toolchain')
    parser.add_argument('--jobs', type=int, default=min(8, os.cpu_count() or 2))
    args = parser.parse_args()
    if not args.scons and not args.container: parser.error('SCons is required; provide --scons or --container')
    work = ROOT / 'Builds/ClientRuntime'; work.mkdir(parents=True, exist_ok=True)
    (work.parent / '.gdignore').touch()
    (work / '.gdignore').touch()
    archive = work / ('godot-' + VERSION + '.tar.gz')
    if not archive.exists():
        cached = ROOT / 'Builds/ServerRuntime' / archive.name
        if cached.exists(): shutil.copy2(cached, archive)
        else: urllib.request.urlretrieve('https://github.com/godotengine/godot/archive/refs/tags/' + VERSION + '.tar.gz', archive)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != SOURCE_SHA256:
        raise SystemExit('Pinned Godot source digest mismatch')
    platform_work = work / args.platform
    platform_work.mkdir(parents=True, exist_ok=True)
    source = platform_work / ('godot-' + VERSION)
    if not source.exists():
        with tarfile.open(archive) as bundle: bundle.extractall(platform_work, filter='data')
    patch_source(source)
    flags = dict(platform=args.platform, target='template_release', arch='arm64' if args.platform == 'android' else 'x86_64',
                 opengl3='no', vulkan='yes', openxr='yes', production='yes', lto='none')
    if args.platform == 'windows': flags['d3d12'] = 'no'
    command = [args.scons] if not args.container else [
        'podman', 'run', '--rm', '--network=none', '--security-opt', 'label=disable',
        '-v', str(source) + ':/src']
    if args.container:
        if args.platform == 'android':
            sdk = Path(os.environ.get('ANDROID_HOME', str(Path.home() / 'Android/Sdk')))
            command += ['-v', str(sdk) + ':/sdk:ro', '-e', 'ANDROID_HOME=/sdk']
        command += ['localhost/fpsloppa-windows-toolchain:godot-4.7.2-noble' if args.platform == 'windows'
                    else 'localhost/fpsloppa-client-toolchain:godot-4.7.2-jammy']
    subprocess.run([*command, *[f'{k}={v}' for k, v in flags.items()], f'-j{args.jobs}'], cwd=source, check=True)
    if args.platform == 'android':
        # Editor scans from older checkouts can leave Godot import sidecars in
        # Android resources; AAPT must never receive these generated files.
        for sidecar in (source / 'platform/android/java').rglob('*.import'):
            sidecar.unlink()
        env = os.environ.copy()
        env.setdefault('ANDROID_HOME', str(Path.home() / 'Android/Sdk'))
        env.setdefault('JAVA_HOME', str(Path.home() / '.local/share/entryway-toolchains/jdk-17.0.20.1+1'))
        # Gradle resolves SCons while configuring its (excluded) native tasks.
        local_scons = work / 'python/bin'
        if local_scons.is_dir():env['PATH'] = str(local_scons) + os.pathsep + env['PATH']
        subprocess.run(['./gradlew', '--no-daemon', 'generateGodotTemplates'], cwd=source / 'platform/android/java', env=env, check=True)
        output = source / 'bin' / NAMES['android']
    else:
        output = source / 'bin' / ('godot.' + args.platform + '.template_release.x86_64' + ('.exe' if args.platform == 'windows' else ''))
    dest = ROOT / 'Builds/ClientTemplates' / NAMES[args.platform]; dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(output, dest)
    receipt = dict(engine=VERSION, source_sha256=SOURCE_SHA256, patches=patch_hashes(), flags=flags, sha256=hashlib.sha256(dest.read_bytes()).hexdigest())
    dest.with_suffix(dest.suffix + '.json').write_text(json.dumps(receipt, indent=2) + '\n')
    from renderer_policy import require_client_template
    require_client_template(args.platform)
    print('OPENGL_FREE_TEMPLATE', dest)


if __name__ == '__main__': main()
