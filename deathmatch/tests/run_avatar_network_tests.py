"""Server + uploader + receiver, isolated caches, actual 14 MB VRM transfer."""
from pathlib import Path
import shutil, subprocess, time, json, os, tempfile, struct, hashlib

def main():
    root = Path(__file__).resolve().parents[2]
    godot = '/home/blux/.local/bin/Godot_v4.7.2-stable_linux.x86_64'
    logs = root / 'test-results'
    processes, handles = [], []
    with tempfile.TemporaryDirectory(prefix='entryway-avatar-test-') as temp:
        data = (root/'vrm/sample_f.vrm').read_bytes()
        length = struct.unpack_from('<I',data,12)[0]
        doc = json.loads(data[20:20+length])
        doc['extensions']['VRM']['meta']['title'] = 'Custom network test '+Path(temp).name
        chunk = json.dumps(doc,separators=(',',':'),ensure_ascii=False).encode()
        chunk += b' ' * (-len(chunk)%4)
        binary = data[20+length:]
        data = struct.pack('<IIIII',0x46546c67,2,20+len(chunk)+len(binary),len(chunk),0x4e4f534a)+chunk+binary
        model = Path(temp)/'custom.vrm'
        model.write_bytes(data)
        sha = hashlib.sha256(data).hexdigest()
        try:
            for role in ['server','uploader','receiver']:
                handle = (logs/('avatar_'+role+'.log')).open('w'); handles.append(handle)
                env = os.environ.copy(); env['XDG_DATA_HOME'] = str(Path(temp)/role)
                asset_root=Path(temp)/('assets-'+role);shutil.copytree(root/'maps',asset_root/'maps');shutil.copytree(root/'vrm',asset_root/'vrm')
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
