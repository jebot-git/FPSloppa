"""Archive the CQ-only builds and versioned sources; verify CRCs and publication hashes."""
import concurrent.futures,hashlib,json,shutil,subprocess,zipfile
from pathlib import Path
from map_distribution import distributable
ROOT=Path(__file__).resolve().parents[1]
def digest(path):
    with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def main():
    version=(ROOT/'VERSION').read_text().strip();commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    assert not subprocess.check_output(['git','status','--porcelain'],cwd=ROOT),'Commit validated sources first'
    out=ROOT/'release-assets'/version;out.mkdir(parents=True,exist_ok=True)
    retired={'optional-map-pack','optional-tf-map-pack','optional-arena-pack','optional-threewave-tools','optional-tf-tools','optional-ad-tools','android','materials','textures'}
    files=subprocess.check_output(['git','ls-files','-z'],cwd=ROOT,text=True).split('\0')
    source=[]
    for name in files:
        if not name:continue
        p=Path(name)
        if not distributable(p) or p.parts[0] in retired:continue
        if set(p.parts)&{'.git','.godot','.agents','.codex','Builds','release-assets','test-results','__pycache__'}:continue
        if p.suffix in {'.pyc','.log','.mp4','.tmp','.bak','.keystore','.jks','.p12'} or p.name.startswith('.env'):continue
        source.append((ROOT/p,p.as_posix()))
    def archive(label,rows):
        path=out/f'FPSloppa-{version}-{label}.zip'
        with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
            for original,name in sorted(rows):
                assert original.is_file(),original
                assert original.suffix not in {'.log','.pyc','.sqlite','.tmp','.conf'},original
                assert not set(Path(name).parts)&{'__pycache__','state','test-results','config'},name
                z.write(original,Path('FPSloppa-CQ-'+label)/name)
        with zipfile.ZipFile(path) as z:assert z.testzip() is None
        assert path.stat().st_size<2_000_000_000,'GitHub asset exceeds 2 GB'
        print('ARCHIVE_VERIFIED',path.name,path.stat().st_size,flush=True)
        return dict(file=path.name,bytes=path.stat().st_size,sha256=digest(path))
    jobs=[]
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        for label,folder in [('Linux','Linux'),('Windows','Windows'),('Server-Linux','Server')]:
            base=ROOT/'Builds/CQRelease'/folder
            rows=[(p,p.relative_to(base).as_posix()) for p in base.rglob('*') if p.is_file() and '__pycache__' not in p.parts]
            jobs.append(pool.submit(archive,label,rows))
        jobs.append(pool.submit(archive,'Source',source))
        rows=[job.result() for job in jobs]
    receipt=json.loads((ROOT/'Builds/CQRelease/client-build.json').read_text())
    manifest=dict(version=version,commit=commit,artifacts=rows,client_pack_sha256=receipt['pack_sha256'],campaign_maps=receipt['maps'],unit_tests=43,
        validations=['docs/validation/cq-moderation-release.json','docs/validation/cq-release-package.json'],windows_execution='not tested on native Windows',desktop_renderer='Vulkan',mode='CQ',loadout='UT99',player_limit=128,district_capacity=16)
    (out/'BUILD-MANIFEST.json').write_text(json.dumps(manifest,indent=2)+'\n');shutil.copy2(ROOT/'docs'/f'RELEASE-{version}.md',out/'RELEASE-NOTES.md')
    expected={r['file'] for r in rows}|{'BUILD-MANIFEST.json','SHA256SUMS','RELEASE-NOTES.md'}
    assert not {p.name for p in out.iterdir()}-expected
    (out/'SHA256SUMS').write_text(''.join(f'{digest(p)}  {p.name}\n' for p in sorted(out.iterdir()) if p.name!='SHA256SUMS'))
    print('CQ_RELEASE_STAGED',version,commit,flush=True)
if __name__=='__main__':main()
