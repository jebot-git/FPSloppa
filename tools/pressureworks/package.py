"""Package only the tested Pressureworks map, editable source and licences."""
from pathlib import Path
import hashlib,json,zipfile
from validate import fingerprint

ROOT=Path(__file__).resolve().parents[2]


def main():
    bsp=ROOT/'maps/tf_pressureworks.bsp';folder=ROOT/'maps/Pressureworks';nav=ROOT/'maps/navigation/tf_pressureworks.res'
    report=json.loads((folder/'validation.json').read_text());manifest=json.loads((folder/'manifest.json').read_text())
    sha=hashlib.sha256(bsp.read_bytes()).hexdigest()
    assert report['sha256']==manifest['sha256']==sha and not report['failures'],'Stale/failed map acceptance'
    assert manifest['source_sha256']==hashlib.sha256((folder/'tf_pressureworks.map').read_bytes()).hexdigest(),'Editable source changed after compilation'
    audit=json.loads((folder/'texture-audit.json').read_text())
    assert audit['bsp_sha256']==sha and all(row['unchanged'] for row in audit['textures']),'Textures need a fresh audit'
    assert report['code_fingerprint']==fingerprint(),'Tested code changed; validate again'
    assert report['navigation_sha256']==hashlib.sha256(nav.read_bytes()).hexdigest(),'Navigation changed'
    files=[bsp,nav,ROOT/'tools/generate_tf_maps.py']
    files += [p for p in folder.iterdir() if p.suffix in {'.md','.txt','.json','.map','.wad','.png'}]
    files += [p for p in (ROOT/'tools/pressureworks').iterdir() if p.suffix in {'.py','.gd'}]
    dest=ROOT/'dist/Pressureworks-TF-playtest.zip';dest.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(dest,'w',zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(files):archive.write(path,path.relative_to(ROOT))
    checksum=hashlib.sha256(dest.read_bytes()).hexdigest()
    dest.with_suffix('.zip.sha256').write_text(checksum+'  '+dest.name+'\n')
    print(dest);print(checksum)


if __name__=='__main__':main()
