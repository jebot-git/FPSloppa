"""Build/package the CQ C++ executable and offline-cooked world; no Godot runtime."""
from pathlib import Path
import argparse, hashlib, json, os, shutil, subprocess, tarfile, tempfile, urllib.request
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'native_server'
DEPS=ROOT/'external-tools/cq-standalone'
def digest(path):
    with Path(path).open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def dependencies():
    manifest=json.loads((SOURCE/'dependencies.json').read_text());DEPS.mkdir(parents=True,exist_ok=True)
    for name,row in manifest.items():
        if '.' in name:
            if digest(SOURCE/'vendor'/name)!=row['sha256']:raise RuntimeError('Vendored dependency checksum: '+name)
            continue
        target=DEPS/name;marker=target/'.cq-source-sha256'
        if target.exists():
            # A cache made before receipts is accepted only after comparing its archive.
            archive=DEPS/(name+'.tar.gz')
            if marker.exists() and marker.read_text().strip()==row['sha256']:continue
            if not archive.exists() or digest(archive)!=row['sha256']:raise RuntimeError('Unverified dependency cache: '+str(target))
            with tempfile.TemporaryDirectory(dir=DEPS) as temporary:
                with tarfile.open(archive) as tar:tar.extractall(temporary,filter='data')
                extracted=next(Path(temporary).iterdir())
                for file in extracted.rglob('*'):
                    if file.is_file() and (not (target/file.relative_to(extracted)).is_file() or digest(file)!=digest(target/file.relative_to(extracted))):raise RuntimeError('Modified dependency cache: '+name)
            marker.write_text(row['sha256']+'\n');continue
        with tempfile.TemporaryDirectory(dir=DEPS) as temporary:
            archive=Path(temporary)/'source.tar.gz';urllib.request.urlretrieve(row['url'],archive)
            if digest(archive)!=row['sha256']:raise RuntimeError('Dependency archive checksum: '+name)
            with tarfile.open(archive) as tar:tar.extractall(temporary,filter='data')
            extracted=next(p for p in Path(temporary).iterdir() if p.is_dir());os.replace(extracted,target)
            (target/'.cq-source-sha256').write_text(row['sha256']+'\n')
def source_hashes():
    files=list((SOURCE/'src').glob('*'))+list((SOURCE/'vendor').glob('*'))+list((ROOT/'addons/fps_native/src').glob('authority*'))+[SOURCE/'CMakeLists.txt',SOURCE/'dependencies.json',ROOT/'addons/fps_native/src/cq_wire.h']
    return {p.relative_to(ROOT).as_posix():digest(p) for p in sorted(files) if p.is_file()}
def verify(folder):
    receipt=json.loads((folder/'server-build.json').read_text())
    if receipt['runtime']!='standalone-cpp' or receipt['protocol']!='fpsloppa-cq-native-1':raise RuntimeError('Wrong server package type')
    if source_hashes()!=receipt['source_sha256']:raise RuntimeError('Standalone server package is stale')
    expected=set(receipt['package_files'])|{'server-build.json','release-sha256.json'}
    actual={p.relative_to(folder).as_posix() for p in folder.rglob('*') if p.is_file()}
    if actual!=expected:raise RuntimeError('Unexpected/missing server package files')
    checksums=json.loads((folder/'release-sha256.json').read_text())
    if set(checksums)!=set(receipt['package_files'])|{'server-build.json'}:raise RuntimeError('Invalid release checksums')
    for name,sha in checksums.items():
        if digest(folder/name)!=sha:raise RuntimeError('Server package checksum: '+name)
    for p in folder.rglob('*'):
        if p.suffix in {'.gd','.tscn','.tres','.pck','.gdextension'} or p.name.lower().startswith('godot'):raise RuntimeError('Godot runtime artifact in standalone package: '+str(p))
    if (folder/'cq-server').read_bytes()[:4]!=b'\x7fELF':raise RuntimeError('Server is not a native ELF executable')
    return receipt

def require_build(build):
    receipt=json.loads((build/'build-receipt.json').read_text())
    if receipt['source_sha256']!=source_hashes() or receipt['sha256']!=digest(build/'cq-server'):raise RuntimeError('Standalone executable is stale; rebuild before packaging')

def package(build,cooked,output):
    require_build(build)
    if output.exists() and any(output.iterdir()):raise RuntimeError('Output must be new or empty')
    output.mkdir(parents=True,exist_ok=True);shutil.copy2(build/'cq-server',output/'cq-server');(output/'cq-server').chmod(0o755)
    metadata=json.loads((cooked/'world.json').read_text())
    for name,sha in metadata['sources'].items():
        if not name.startswith('res://') or digest(ROOT/name[6:])!=sha:raise RuntimeError('Cooked world is stale: '+name)
    world=output/'world';world.mkdir()
    for name in ['world.json','geometry.bin','navigation.bin','receipt.json']:shutil.copy2(cooked/name,world/name)
    shutil.copytree(cooked/'avatars',world/'avatars')
    licenses=output/'licenses';licenses.mkdir()
    for name,path in [('Jolt','jolt/LICENSE'),('ENet','enet/LICENSE'),('nlohmann-json','json/LICENSE.MIT')]:shutil.copy2(DEPS/path,licenses/(name+'.txt'))
    for name in ['picosha2.h','fastlz.c','fastlz.h']:shutil.copy2(SOURCE/'vendor'/name,licenses/(name+'.txt'))
    for name in ['ASSET_CREDITS.md','LICENSE']:
        if (ROOT/name).is_file():shutil.copy2(ROOT/name,licenses/name)
    (output/'server.cfg').write_text('sets sv_hostname "FPSloppa CQ"\nset net_port 7777\nset sv_cq_maxclients 64\nset sv_cq_adaptive_tick 1\nset sv_cq_tick_rate 60\nset sv_cq_destruction 1\nset sv_cq_bot_fill 0\nset sv_log_file "server.log"\nset rcon_bind "127.0.0.1"\nset rcon_port 7778\nset rcon_password ""\n')
    launcher=output/'start-server.sh';launcher.write_text('#!/bin/sh\nset -eu\ncd -- "$(dirname -- "$0")"\nexec ./cq-server --world ./world --config ./server.cfg --state ./state "$@"\n');launcher.chmod(0o755)
    (output/'README.txt').write_text('FPSloppa CQ standalone C++ server\nRun ./start-server.sh. No Godot executable, PCK, renderer or GDScript runtime is used.\nUDP 7777; 64 players; adaptive 60/30 Hz; destruction enabled.\nRCON is disabled until a password is set. Keep its bind on loopback and use an SSH tunnel.\nProfiles and custom avatars are stored in ./state. Back up state between releases.\nRequires a matching fpsloppa-cq-native-1 client. Older Godot-RPC clients are incompatible.\nWorld data is cooked offline; never run a Godot map cooker on the live service.\n')
    files={p.relative_to(output).as_posix():digest(p) for p in sorted(output.rglob('*')) if p.is_file()}
    receipt={'runtime':'standalone-cpp','protocol':'fpsloppa-cq-native-1','source_sha256':source_hashes(),'sha256':files,'package_files':sorted(files),'world_receipt':json.loads((cooked/'receipt.json').read_text())}
    (output/'server-build.json').write_text(json.dumps(receipt,indent=2)+'\n')
    (output/'release-sha256.json').write_text(json.dumps({**files,'server-build.json':digest(output/'server-build.json')},indent=2)+'\n');verify(output);return receipt

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--build-dir',type=Path,default=SOURCE/'build');p.add_argument('--cooked',type=Path,default=SOURCE/'cooked');p.add_argument('--output',type=Path);p.add_argument('--cook',action='store_true');p.add_argument('--godot',default=os.environ.get('GODOT_BIN','godot'));p.add_argument('--skip-build',action='store_true');p.add_argument('--verify-only',action='store_true');p.add_argument('--cxx');p.add_argument('--cc');p.add_argument('-j',type=int,default=3);a=p.parse_args()
    if a.verify_only:
        if not a.output:p.error('--verify-only requires --output')
        verify(a.output);print('CQ_STANDALONE_PACKAGE_VERIFIED',a.output);return
    dependencies()
    if not a.skip_build:
        command=['cmake','-S',str(SOURCE),'-B',str(a.build_dir),'-G','Ninja','-DCMAKE_BUILD_TYPE=Release']
        if a.cxx:command+=['-DCMAKE_CXX_COMPILER='+a.cxx]
        if a.cc:command+=['-DCMAKE_C_COMPILER='+a.cc]
        subprocess.run(command,check=True);subprocess.run(['cmake','--build',str(a.build_dir),'--target','cq-server','cq-server-tests','cq-load-client','-j',str(a.j)],check=True)
        subprocess.run([str(a.build_dir/'cq-server-tests')],check=True)
        (a.build_dir/'build-receipt.json').write_text(json.dumps({'sha256':digest(a.build_dir/'cq-server'),'source_sha256':source_hashes()},indent=2)+'\n')
    if a.skip_build:require_build(a.build_dir)
    if a.cook:subprocess.run([a.godot,'--headless','--xr-mode','off','--path',str(ROOT),'--script','res://tools/standalone_server/cook_world.gd','--','--output',str(a.cooked),'--cq-destruction'],check=True)
    if a.output:package(a.build_dir,a.cooked,a.output);print('CQ_STANDALONE_PACKAGE',a.output)
if __name__=='__main__':main()
