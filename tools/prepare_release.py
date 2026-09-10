"""Stage an explicit release allowlist, verify archives and write publication checksums."""
from pathlib import Path
import hashlib,json,shutil,subprocess,zipfile
ROOT=Path(__file__).resolve().parents[1]
VERSION=(ROOT/'VERSION').read_text().strip()
OUT=ROOT/'release-assets'/VERSION
BUILDS=ROOT.parent/'Builds'
RETIRED={'optional-arena-pack','optional-threewave-tools','optional-tf-tools','optional-ad-tools'}
files={
    'Linux.zip':ROOT.parent/'FPSloppa-Linux.zip',
    'Windows.zip':ROOT.parent/'FPSloppa-Windows.zip',
    'Dedicated-Server-Linux.zip':ROOT.parent/'FPSloppa-Dedicated-Server-Linux.zip',
    'Source.zip':ROOT.parent/'FPSloppa-Deathmatch.zip',
    'Base-Assets.zip':BUILDS/f'FPSloppa-{VERSION}-Base-Assets.zip',
    'Quest.apk':BUILDS/'Android/FPSloppa-Quest.apk',
    'Pico.apk':BUILDS/'Android/FPSloppa-Pico.apk',
    'LibreQuake-Extra-Maps.zip':BUILDS/f'FPSloppa-{VERSION}-LibreQuake-Extra-Maps.zip',
    'Original-TF-Arenas.zip':BUILDS/f'FPSloppa-{VERSION}-Original-TF-Arenas.zip',
}
expected={f'FPSloppa-{VERSION}-{label}' for label in files}|{'BUILD-MANIFEST.json','SHA256SUMS','RELEASE-NOTES.md'}
OUT.mkdir(parents=True,exist_ok=True)
unexpected={p.name for p in OUT.iterdir()}-expected
if unexpected:raise SystemExit('Unexpected staged release assets: '+str(sorted(unexpected)))
rows=[]
for label,source in files.items():
    assert source.is_file(),source
    with zipfile.ZipFile(source) as archive:
        assert archive.testzip() is None,source
        for name in archive.namelist():
            parts=Path(name).parts
            assert not RETIRED.intersection(parts),('Retired content',source,name)
            assert not any(part in {'.git','.codex','.agents','test-results','__pycache__'} for part in parts),('Private/build payload',name)
    destination=OUT/f'FPSloppa-{VERSION}-{label}'
    shutil.copy2(source,destination)
    with destination.open('rb') as stream:digest=hashlib.file_digest(stream,'sha256').hexdigest()
    rows.append({'file':destination.name,'bytes':destination.stat().st_size,'sha256':digest})
commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
(OUT/'BUILD-MANIFEST.json').write_text(json.dumps({'version':VERSION,'commit':commit,'artifacts':rows,'retired_extras_release':'0.5v','archive_integrity_and_exclusions_verified':True},indent=2)+'\n')
shutil.copy2(ROOT/'docs'/f'RELEASE-{VERSION}.md',OUT/'RELEASE-NOTES.md')
checks=[]
for path in sorted(OUT.iterdir()):
    if path.name=='SHA256SUMS':continue
    with path.open('rb') as stream:digest=hashlib.file_digest(stream,'sha256').hexdigest()
    checks.append(f'{digest}  {path.name}')
(OUT/'SHA256SUMS').write_text('\n'.join(checks)+'\n')
print(json.dumps({'version':VERSION,'commit':commit,'artifacts':rows},indent=2))
