"""Build the direct-BLE GDExtension for desktop x86_64 or Android ARM64.

Install the Rust standard library for cross targets using the same Rust toolchain
as RUSTC. Linux requires libdbus development headers. Android also packages a
Godot v2 AAR; use ANDROID_SDK_ROOT, JAVA_HOME and --ndk for your installed SDK.
"""
from pathlib import Path
import argparse
import json
import os
import platform
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / 'addons/bhaptics_native'
TARGETS = ('x86_64-unknown-linux-gnu', 'x86_64-pc-windows-msvc',
           'x86_64-pc-windows-gnullvm', 'aarch64-linux-android')

def install_library(source, destination, strip=None):
    # Replacing the inode preserves libraries mapped by a running Godot process.
    with tempfile.TemporaryDirectory(prefix='.install-', dir=destination.parent) as temp:
        staged = Path(temp)/destination.name
        shutil.copy2(source, staged)
        if strip: subprocess.run([strip, '--strip-debug', str(staged)], check=True)
        os.replace(staged, destination)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--release', action='store_true')
    parser.add_argument('--offline', action='store_true')
    parser.add_argument('--target', choices=TARGETS, help='Omit to build for the host desktop')
    parser.add_argument('--llvm-mingw', type=Path, help='LLVM-MinGW root for Windows cross builds')
    parser.add_argument('--ndk', type=Path, help='Android NDK root (otherwise ANDROID_NDK_HOME)')
    parser.add_argument('--godot-aar', type=Path, default=ROOT/'android/build/libs/release/godot-lib.template_release.aar')
    args = parser.parse_args()
    target = args.target
    if target is None:
        if platform.machine().lower() not in ('x86_64', 'amd64') or platform.system() not in ('Linux', 'Windows'):
            parser.error('Select an explicit supported --target on this host.')
        target = 'x86_64-pc-windows-msvc' if platform.system() == 'Windows' else 'x86_64-unknown-linux-gnu'
    android = target == 'aarch64-linux-android'
    windows = 'windows' in target
    env = dict(os.environ)
    flags = []
    strip = None
    if target.endswith('gnullvm'):
        if not args.llvm_mingw:
            parser.error('--llvm-mingw is required for the gnullvm target and its runtime packaging.')
        toolchain = args.llvm_mingw.resolve()
        env['PATH'] = str(toolchain/'bin') + os.pathsep + env['PATH']
        env['CARGO_TARGET_X86_64_PC_WINDOWS_GNULLVM_LINKER'] = 'x86_64-w64-mingw32-clang'
        strip = str(toolchain/'bin/llvm-strip')
    elif android:
        ndk = args.ndk or (Path(env['ANDROID_NDK_HOME']) if env.get('ANDROID_NDK_HOME') else None)
        if ndk is None: parser.error('Set --ndk or ANDROID_NDK_HOME.')
        host = {'Linux': 'linux-x86_64', 'Windows': 'windows-x86_64', 'Darwin': 'darwin-x86_64'}[platform.system()]
        toolchain = ndk.resolve()/'toolchains/llvm/prebuilt'/host/'bin'
        suffix = '.cmd' if platform.system() == 'Windows' else ''
        env['CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER'] = str(toolchain/('aarch64-linux-android26-clang'+suffix))
        flags = ['-C', 'link-arg=-Wl,-z,max-page-size=16384']
        strip = str(toolchain/('llvm-strip.exe' if platform.system() == 'Windows' else 'llvm-strip'))
    elif not windows:
        strip = 'strip'
    manifest = str(ADDON/'native/Cargo.toml')
    metadata = json.loads(subprocess.check_output(['cargo', 'metadata', '--no-deps', '--format-version', '1', '--manifest-path', manifest], env=env, text=True))
    command = ['cargo', 'rustc', '--locked', '--manifest-path', manifest, '-j', '2']
    if args.target: command += ['--target', target]
    if args.release: command.append('--release')
    if args.offline: command.append('--offline')
    if flags: command += ['--', *flags]
    subprocess.run(command, cwd=ROOT, env=env, check=True)
    source_dir = Path(metadata['target_directory'])
    if args.target: source_dir /= target
    source_dir /= 'release' if args.release else 'debug'
    library = 'fpsloppa_bhaptics_native.dll' if windows else 'libfpsloppa_bhaptics_native.so'
    (ADDON/'bin').mkdir(exist_ok=True)
    destination = ADDON/'bin'/('libfpsloppa_bhaptics_native.android.so' if android else library)
    install_library(source_dir/library, destination, strip)
    if target.endswith('gnullvm'):
        install_library(args.llvm_mingw/'x86_64-w64-mingw32/bin/libunwind.dll', ADDON/'bin/libunwind.dll')
        shutil.copy2(args.llvm_mingw/'LICENSE.TXT', ADDON/'bin/LLVM-MinGW-LICENSE.txt')
    if android:
        subprocess.run([sys.executable, str(ROOT/'tools/build_bhaptics_android.py'), '--godot-aar', str(args.godot_aar)], env=env, check=True)
    descriptor = (ADDON/'bhaptics.gdextension.in').read_text()
    if (ADDON/'bin/libunwind.dll').exists():
        descriptor += '\n[dependencies]\nwindows.x86_64 = { "res://addons/bhaptics_native/bin/libunwind.dll": "" }\n'
    (ADDON/'bhaptics.gdextension').write_text(descriptor)
    print(f'Built {destination} ({destination.stat().st_size} bytes)')

if __name__ == '__main__':
    main()
