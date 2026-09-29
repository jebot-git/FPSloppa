"""Package the stdlib-only CS map converter, without game or third-party assets."""
import argparse
import hashlib
import json
import zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'tools/cs16_map_converter'


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=ROOT/'Builds/Converters/FPSloppa-CS16-Map-Converter-1.0.zip')
    args=parser.parse_args();args.output.parent.mkdir(parents=True,exist_ok=True)
    names=['convert.py','bsp.py','textures.py','entities.py','replacements.py','README.md']
    manifest={'tool':'FPSloppa CS16 Map Converter','version':'1.0','python':'3.10+','files':{name:hashlib.sha256((SOURCE/name).read_bytes()).hexdigest() for name in names}}
    temporary=args.output.with_suffix('.zip.tmp')
    with zipfile.ZipFile(temporary,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as archive:
        for name in names:archive.write(SOURCE/name,'CS16-Map-Converter/'+name)
        archive.writestr('CS16-Map-Converter/MANIFEST.json',json.dumps(manifest,indent=2)+'\n')
        archive.writestr('CS16-Map-Converter/convert.cmd','@echo off\r\npy -3 "%~dp0convert.py" %*\r\n')
        launcher=zipfile.ZipInfo('CS16-Map-Converter/convert.sh');launcher.external_attr=0o100755<<16
        archive.writestr(launcher,'#!/usr/bin/env sh\nexec python3 "$(dirname "$0")/convert.py" "$@"\n')
    with zipfile.ZipFile(temporary) as archive:
        assert archive.testzip() is None
        assert len(archive.namelist())==9
    temporary.replace(args.output)
    print(json.dumps({'path':str(args.output),'bytes':args.output.stat().st_size,'sha256':hashlib.sha256(args.output.read_bytes()).hexdigest()}))


if __name__=='__main__':main()
