#!/usr/bin/env python3
"""Prepare pinned Raindance height data and unchanged project WAD miptextures."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import struct
import sys
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from makkon.theme import wad_textures

NAMES = {'grass', 'med_rock4', 'sky_star', 'metal_iron1_01',
         'ind_dp01_red1', 'ind_dp01_blu1', 'ind_dp01_grey1', 'ind_w02_grey1'}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--assets-root', type=Path, default=ROOT,
                        help='Checkout containing Stonehenge WAD and original Makkon archives')
    args = parser.parse_args()
    out = ROOT / 'maps/Raindance'
    out.mkdir(parents=True, exist_ok=True)
    reference = json.loads((ROOT / 'tools/raindance/references.json').read_text())['heightmap']
    height = out / 'reference-heightmap.png'
    data = height.read_bytes() if height.exists() else urllib.request.urlopen(reference['url'], timeout=30).read()
    if sha(data) != reference['sha256']:
        raise SystemExit('Raindance heightmap hash mismatch')
    height.write_bytes(data)

    base = args.assets_root / 'maps/Stonehenge'
    records = wad_textures((base / 'stonehenge.wad').read_bytes())
    credits = json.loads((base / 'texture-sources.json').read_text())
    inventory = json.loads((ROOT / 'tools/makkon/inventory.json').read_text())
    pack = next(p for p in inventory['packs'] if p['archive'] == 'makkon_industrial.zip')
    archive = args.assets_root / 'tools/makkon/local' / pack['archive']
    if sha(archive.read_bytes()) != pack['sha256']:
        raise SystemExit('Original Makkon archive hash mismatch')
    with zipfile.ZipFile(archive) as z:
        for entry in z.namelist():
            if not entry.lower().endswith('.wad'):
                continue
            wad = z.read(entry)
            for name, raw in wad_textures(wad).items():
                if name not in NAMES:
                    continue
                records[name] = raw
                credits[name] = dict(author='Ben "Makkon" Hale',
                    source='https://www.slipseer.com/resources/makkon-textures.28/',
                    archive=pack['archive'], archive_sha256=pack['sha256'],
                    wad=entry, wad_sha256=sha(wad), sha256=sha(raw),
                    format='original WAD2 miptex; all four mip levels unchanged',
                    license='Makkon_License.txt; project-specific permission confirmed by project owner')
    if not NAMES <= records.keys():
        raise SystemExit('Missing original texture records: ' + str(NAMES - records.keys()))
    wad = bytearray(b'WAD2' + bytes(8))
    directory = []
    for name in sorted(NAMES):
        raw = records[name]
        if sha(raw) != credits[name]['sha256']:
            raise SystemExit('Original texture hash mismatch: ' + name)
        directory.append(struct.pack('<iiiBBH16s', len(wad), len(raw), len(raw), 68, 0, 0, name.encode()))
        wad.extend(raw)
    at = len(wad)
    wad.extend(b''.join(directory))
    struct.pack_into('<ii', wad, 4, len(directory), at)
    (out / 'raindance.wad').write_bytes(wad)
    (out / 'texture-sources.json').write_text(json.dumps({n: credits[n] for n in sorted(NAMES)}, indent=2) + '\n')
    for name in ['Makkon_License.txt', 'LibreQuake-COPYING.txt', 'LibreQuake-CREDITS.txt']:
        shutil.copyfile(base / name, out / name)
    print(json.dumps(dict(textures=len(NAMES), wad_sha256=sha(wad), heightmap_sha256=sha(data))))


if __name__ == '__main__':
    main()
