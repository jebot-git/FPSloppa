"""Server + uploader + receiver, isolated caches, actual UT99 vertex avatar transfer."""
from pathlib import Path
import shutil, subprocess, time, json, os, tempfile, struct, hashlib, argparse

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--avatar-file',type=Path);args=parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    godot = shutil.which('godot') or 'godot'
    logs = root / 'test-results'
    processes, handles = [], []
    with tempfile.TemporaryDirectory(prefix='entryway-avatar-test-') as temp:
        source = args.avatar_file or root/'deathmatch/avatars/models/world_leaders/jong-un.utavatar'
        original = source.read_bytes()
        length = struct.unpack_from('<I',original,12)[0]
        doc = json.loads(original[16:16+length])
        doc['title'] = 'Custom UT99 network '+Path(temp).name
        chunk = json.dumps(doc,separators=(',',':'),ensure_ascii=False).encode()
        binary = original[16+length:]
        data = struct.pack('<4sIII',b'UTAV',1,16+len(chunk)+len(binary),len(chunk))+chunk+binary
        model = Path(temp)/'custom.utavatar'
        model.write_bytes(data)
        sha = hashlib.sha256(data).hexdigest()
        try:
            for role in ['server','uploader','receiver']:
                handle = (logs/('avatar_'+role+'.log')).open('w'); handles.append(handle)
                env = os.environ.copy(); env['XDG_DATA_HOME'] = str(Path(temp)/role)
                asset_root=Path(temp)/('assets-'+role);shutil.copytree(root/'maps',asset_root/'maps',ignore=lambda folder,names:[name for name in names if (Path(folder)/name).is_dir() or Path(name).suffix not in {'.bsp','.txt','.json'}])
                cmd = [godot,'--headless','--xr-mode','off','--path',str(root),'--script','res://deathmatch/tests/avatar_network_runner.gd','--',role,str(model),sha,"--asset-root",str(asset_root)]
                processes.append((role,subprocess.Popen(cmd,env=env,stdout=handle,stderr=subprocess.STDOUT)))
                if role=='server':
                    until=time.monotonic()+10
                    while time.monotonic()<until:
                        if 'DM_HOST_READY' in (logs/'avatar_server.log').read_text(): break
                        time.sleep(.05)
            deadline=time.monotonic()+100
            for role, process in processes: process.wait(timeout=max(1,deadline-time.monotonic()))
            success=True
            for role, process in processes:
                contents=(logs/('avatar_'+role+'.log')).read_text()
                print(role,process.returncode,contents)
                success &= process.returncode==0 and 'AVATAR_NETWORK_RESULT' in contents and 'ERROR:' not in contents
            (logs/'avatar_summary.json').write_text(json.dumps({'passed':success,'sha256':sha,'bytes':len(data)},indent=2))
            return 0 if success else 1
        finally:
            for _,process in processes:
                if process.poll() is None: process.terminate(); process.wait(timeout=3)
            for handle in handles: handle.close()
if __name__=='__main__': raise SystemExit(main())
