"""Build optional gameplay acceleration; portable desktop builds use existing containers."""
from pathlib import Path
import argparse, hashlib, json, os, platform, shutil, subprocess, tarfile, tempfile, urllib.request
ROOT=Path(__file__).resolve().parents[1]
ADDON=ROOT/'addons/fps_native'
REVISION='507ed9d840c01a3c5b2a39af8bb4000bfac30bf5'
ARCHIVE_SHA='30da4ac295997061a6af81ae531510efd4e6a86e506eb4466edc0898ef3fe048'

def source():
    dest=ROOT/'external-tools/godot-cpp-native'
    if dest.exists():
        if not (dest/'.fps_revision').exists() or (dest/'.fps_revision').read_text().strip()!=REVISION:
            raise RuntimeError('Bindings directory is not the pinned revision; supply --bindings for a deliberate override')
        return dest
    dest.parent.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(dir=dest.parent) as tmp:
        archive=Path(tmp)/'source.tar.gz'
        urllib.request.urlretrieve('https://github.com/godotengine/godot-cpp/archive/'+REVISION+'.tar.gz',archive)
        if hashlib.sha256(archive.read_bytes()).hexdigest()!=ARCHIVE_SHA:raise RuntimeError('Bindings archive checksum mismatch')
        with tarfile.open(archive) as tar:tar.extractall(tmp,filter='data')
        extracted=Path(tmp)/('godot-cpp-'+REVISION)
        (extracted/'.fps_revision').write_text(REVISION+'\n');os.replace(extracted,dest)
    return dest

def require_build(target, server=False):
    label=target+('-server' if server else '')
    name='libfpsloppa_native'+('.dll' if target=='windows' else '.android.so' if target=='android' else '.server.so' if server else '.so')
    library=ADDON/'bin'/name
    receipt=ADDON/'bin'/(label+'.json')
    if not library.is_file() or not receipt.is_file():
        raise RuntimeError('Build gameplay acceleration first: tools/build_gameplay_native.py --target '+target+(' --server' if server else ''))
    data=json.loads(receipt.read_text())
    if hashlib.sha256(library.read_bytes()).hexdigest()!=data['sha256']:
        raise RuntimeError('Native library differs from build receipt: '+str(library))
    current={p.relative_to(ADDON).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((ADDON/'src').glob('*')) if p.suffix in ('.cpp','.h')}
    if data['source_sha256']!=current:raise RuntimeError('Rebuild stale native library: '+label)
    return library

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--target',choices=['linux','windows','android'],default='windows' if platform.system()=='Windows' else 'linux')
    parser.add_argument('--server',action='store_true')
    parser.add_argument('--container',action='store_true',help='Use existing portable Ubuntu desktop build images')
    parser.add_argument('--bindings',type=Path)
    parser.add_argument('--ndk',type=Path,default=Path(os.environ.get('ANDROID_NDK_HOME',str(Path.home()/'Android/Sdk/ndk/29.0.14206865'))))
    parser.add_argument('--api',type=Path,help='Custom Godot extension_api.json, when required by the engine build')
    parser.add_argument('-j',type=int,default=6)
    args=parser.parse_args()
    if args.server and args.target!='linux':parser.error('Dedicated server target is Linux')
    bindings=(args.bindings or source()).resolve()
    profile='profile-server.json' if args.server else 'profile.json'
    label=args.target+('-server' if args.server else '')
    name='libfpsloppa_native'+('.dll' if args.target=='windows' else '.android.so' if args.target=='android' else '.server.so' if args.server else '.so')
    if args.container:
        (ADDON/'build-scons').mkdir(exist_ok=True)
        (ADDON/'build-scons/.gdignore').touch()
        if args.target=='android':parser.error('Use the NDK for Android')
        image='localhost/fpsloppa-windows-toolchain:godot-4.7.2-noble' if args.target=='windows' else 'localhost/fpsloppa-server-toolchain:godot-4.7.2-jammy'
        relative=bindings.relative_to(ROOT).as_posix()
        command=['podman','run','--rm','--network=none','-v',str(ROOT)+':/src:Z','-w','/src/addons/fps_native','--entrypoint',('/opt/scons/bin/scons' if args.target=='windows' else '/usr/local/bin/scons'),image,
                 'bindings=/src/'+relative,'platform='+args.target,'target=template_release','arch=x86_64','build_profile='+profile,'server='+('yes' if args.server else 'no'),'-j',str(args.j)]
        if args.api:command.append('custom_api_file=/src/'+args.api.resolve().relative_to(ROOT).as_posix())
        subprocess.run(command,check=True)
        matches=list((ADDON/'build-scons').glob('*.dll' if args.target=='windows' else '*.so'))
        built=max(matches,key=lambda p:p.stat().st_mtime)
    else:
        build=ADDON/('build-'+label)
        build.mkdir(exist_ok=True); (build/'.gdignore').touch()
        command=['cmake','-S',str(ADDON),'-B',str(build),'-G','Ninja','-DCMAKE_BUILD_TYPE=Release','-DGODOT_CPP_PATH='+str(bindings),'-DFPS_SERVER='+('ON' if args.server else 'OFF')]
        if args.target=='linux':command.append('-DGODOTCPP_USE_STATIC_CPP=OFF')
        if args.target=='windows' and platform.system()!='Windows':
            command+=['-DCMAKE_SYSTEM_NAME=Windows','-DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++']
        if args.target=='android':
            command+=['-DCMAKE_TOOLCHAIN_FILE='+str(args.ndk/'build/cmake/android.toolchain.cmake'),'-DANDROID_ABI=arm64-v8a','-DANDROID_PLATFORM=android-26','-DANDROID_STL=c++_static','-DCMAKE_SHARED_LINKER_FLAGS=-Wl,-z,max-page-size=16384']
        if args.api:command.append('-DGODOTCPP_CUSTOM_API_FILE='+str(args.api.resolve()))
        subprocess.run(command,check=True);subprocess.run(['cmake','--build',str(build),'-j',str(args.j)],check=True)
        built=build/('libfpsloppa_native.dll' if args.target=='windows' else 'libfpsloppa_native.so')
    dest=ADDON/'bin';dest.mkdir(exist_ok=True)
    # Never truncate a shared library mapped by a running game.
    with tempfile.TemporaryDirectory(dir=dest) as tmp:
        staged=Path(tmp)/name;shutil.copy2(built,staged);os.replace(staged,dest/name)
    shutil.copy2(ADDON/'fps_native.gdextension.in',ADDON/'fps_native.gdextension')
    shutil.copy2(bindings/'LICENSE.md',ADDON/'GODOT-CPP-LICENSE.md')
    receipt={'target':label,'bindings_revision':REVISION if not args.bindings else str(bindings),'portable_container':args.container,'sha256':hashlib.sha256((dest/name).read_bytes()).hexdigest(),'source_sha256':{p.relative_to(ADDON).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((ADDON/'src').glob('*')) if p.suffix in ('.cpp','.h')}}
    (dest/(label+'.json')).write_text(json.dumps(receipt,indent=2)+'\n')
    print('NATIVE_BUILD',dest/name)
if __name__=='__main__':main()
