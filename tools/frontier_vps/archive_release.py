"""Archive validated game-only CQ builds for tools/publish_release.py."""
import argparse, hashlib, json, shutil, subprocess, zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
def digest(path):
    with path.open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build',type=Path,required=True)
    args=parser.parse_args()
    version=(ROOT/'VERSION').read_text().strip()
    commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    assert not subprocess.check_output(['git','status','--porcelain'],cwd=ROOT),'Commit release sources first'
    build=args.build.resolve();receipt=json.loads((build/'build.json').read_text())
    assert receipt['version']==version and receipt['launcher'] is False
    out=ROOT/'release-assets'/version;out.mkdir(parents=True,exist_ok=False)
    artifacts=[]
    for platform,label in [('Linux','Linux-x86_64'),('Windows','Windows-x86_64'),('Server','Server-Linux-x86_64')]:
        folder=build/platform;hashes=json.loads((folder/'release-sha256.json').read_text())
        files=sorted(p for p in folder.rglob('*') if p.is_file())
        assert {p.relative_to(folder).as_posix() for p in files}==set(hashes)|{'release-sha256.json'}
        for name,expected in hashes.items():assert digest(folder/name)==expected,name
        target=out/f'FPSloppa-CQ-{version}-{label}.zip'
        with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
            for path in files:archive.write(path,Path('FPSloppaCQ-'+label)/path.relative_to(folder))
        with zipfile.ZipFile(target) as archive:assert archive.testzip() is None
        artifacts.append({'file':target.name,'bytes':target.stat().st_size,'sha256':digest(target),'platform':platform})
        print('ARCHIVED',target.name,flush=True)
    manifest={**receipt,'commit':commit,'branch':subprocess.check_output(['git','branch','--show-current'],cwd=ROOT,text=True).strip(),'server':{'max_clients':64,'adaptive_tick':True,'tick_hz':[60,30],'destruction':True},'artifacts':artifacts,'validation':'docs/validation/voxel-battle/release-20261015'}
    (out/'BUILD-MANIFEST.json').write_text(json.dumps(manifest,indent=2)+'\n')
    shutil.copy2(ROOT/'docs'/f'RELEASE-{version}.md',out/'RELEASE-NOTES.md')
    (out/'SHA256SUMS').write_text(''.join(digest(p)+'  '+p.name+'\n' for p in sorted(out.iterdir()) if p.is_file()))
if __name__=='__main__':main()
