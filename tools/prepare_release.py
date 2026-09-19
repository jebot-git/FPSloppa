"""Stage an explicit release allowlist, verify archives and write publication checksums."""
from pathlib import Path
import hashlib,json,shutil,subprocess,zipfile,sys,argparse
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--desktop-only', action='store_true', help='Stage PC/server/source assets without the Quest APK')
args=parser.parse_args()
VERSION=(ROOT/'VERSION').read_text().strip()
subprocess.run([sys.executable,str(ROOT/'tools/validate_release_bundle.py')],check=True)
OUT=ROOT/'release-assets'/VERSION
BUILDS=ROOT.parent/'Builds'
RETIRED={'optional-map-pack','optional-tf-map-pack','optional-arena-pack','optional-threewave-tools','optional-tf-tools','optional-ad-tools'}
files={
    'Linux.zip':ROOT.parent/'FPSloppa-Linux.zip',
    'Windows.zip':ROOT.parent/'FPSloppa-Windows.zip',
    'Dedicated-Server-Linux.zip':ROOT.parent/'FPSloppa-Dedicated-Server-Linux.zip',
    'Source.zip':ROOT.parent/'FPSloppa-Deathmatch.zip',
}
if not args.desktop_only:files['Quest.apk']=BUILDS/'Android/FPSloppa-Quest.apk'
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
            assert Path(name).suffix.lower() not in {'.log','.mp4','.bak','.tmp','.keystore','.jks','.p12'},('Unwanted payload',name)
            assert not RETIRED.intersection(parts),('Retired content',source,name)
            assert not any(part in {'.git','.codex','.agents','test-results','__pycache__'} for part in parts),('Private/build payload',name)
    destination=OUT/f'FPSloppa-{VERSION}-{label}'
    shutil.copy2(source,destination)
    with destination.open('rb') as stream:digest=hashlib.file_digest(stream,'sha256').hexdigest()
    rows.append({'file':destination.name,'bytes':destination.stat().st_size,'sha256':digest})
commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
(OUT/'BUILD-MANIFEST.json').write_text(json.dumps({'version':VERSION,'commit':commit,'artifacts':rows,'retired_downloads':['Base-Assets','Optional-Community-Maps','Original-TF-Arenas'],'map_pack_retirement_version':'0.12v','archive_integrity_and_exclusions_verified':True},indent=2)+'\n')
shutil.copy2(ROOT/'docs'/f'RELEASE-{VERSION}.md',OUT/'RELEASE-NOTES.md')
checks=[]
for path in sorted(OUT.iterdir()):
    if path.name=='SHA256SUMS':continue
    with path.open('rb') as stream:digest=hashlib.file_digest(stream,'sha256').hexdigest()
    checks.append(f'{digest}  {path.name}')
(OUT/'SHA256SUMS').write_text('\n'.join(checks)+'\n')
print(json.dumps({'version':VERSION,'commit':commit,'artifacts':rows},indent=2))
