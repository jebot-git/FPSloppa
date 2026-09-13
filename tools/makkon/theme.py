"""Apply original WAD miptextures without modifying their pixels or BSP geometry.

Texture coordinates stay in Quake world units. Changing texture dimensions must
NOT rescale texinfo: doing so would invalidate the existing lightmap extents.
"""
from pathlib import Path
import hashlib
import json
import struct
import zipfile

ROOT = Path(__file__).resolve().parents[2]
SOURCE = 'https://www.slipseer.com/resources/makkon-textures.28/'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def name(raw):
    return raw[:16].split(b'\0')[0].decode('ascii')


def wad_textures(data):
    assert data[:4] == b'WAD2', 'Only original Quake WAD2 textures are accepted'
    count, offset = struct.unpack_from('<ii', data, 4)
    result = {}
    for i in range(count):
        at, size, _, kind, compressed, _, _ = struct.unpack_from('<iiiBBH16s', data, offset+32*i)
        if kind not in [67, 68]:
            continue
        assert not compressed and at >= 12 and at+size <= len(data)
        raw = data[at:at+size]
        w, h = struct.unpack_from('<II', raw, 16)
        assert len(raw) == 40+w*h*85//64
        result[name(raw)] = raw
    return result


def makkon():
    textures, sources = {}, {}
    inventory = json.loads((ROOT/'tools/makkon/inventory.json').read_text())
    for pack in inventory['packs']:
        path = ROOT/'tools/makkon/local'/pack['archive']
        data = path.read_bytes()
        assert sha(data) == pack['sha256'], 'Makkon archive hash mismatch'
        with zipfile.ZipFile(path) as z:
            for entry in z.namelist():
                if not entry.lower().endswith('.wad'):
                    continue
                wad = z.read(entry)
                wad_hash = sha(wad)
                for key, raw in wad_textures(wad).items():
                    textures[key] = raw
                    sources[key] = dict(author='Ben "Makkon" Hale', source=SOURCE,
                        archive=pack['archive'], archive_sha256=pack['sha256'],
                        wad=entry, wad_sha256=wad_hash, sha256=sha(raw),
                        format='original WAD2 miptex; all four mip levels unchanged',
                        license='Makkon_License.txt; project-specific permission confirmed by project owner')
    return textures, sources


def lumps(data):
    assert struct.unpack_from('<i', data)[0] == 29
    ranges = [struct.unpack_from('<ii', data, 4+8*i) for i in range(15)]
    assert all(o >= 0 and n >= 0 and o+n <= len(data) for o, n in ranges)
    result = [data[o:o+n] for o, n in ranges]
    end = (max(o+n for o, n in ranges)+3)&~3
    extra = []
    if data[end:end+4] == b'BSPX':
        count = struct.unpack_from('<i', data, end+4)[0]
        for i in range(count):
            key, at, size = struct.unpack_from('<24sii', data, end+8+32*i)
            assert 0 <= at <= at+size <= len(data)
            extra.append((key, data[at:at+size]))
    return result, extra


def bsp_textures(data):
    lump = lumps(data)[0][2]
    result = []
    for i in range(struct.unpack_from('<i', lump)[0]):
        at = struct.unpack_from('<i', lump, 4+4*i)[0]
        if at < 0:
            result.append(None)
            continue
        w, h = struct.unpack_from('<II', lump, at+16)
        raw = lump[at:at+40+w*h*85//64]
        assert len(raw) == 40+w*h*85//64
        result.append(raw)
    return result


def repack(parts, extra):
    result = bytearray(struct.pack('<i', 29)+bytes(120))
    for i, part in enumerate(parts):
        result.extend(bytes((-len(result)) % 4))
        struct.pack_into('<ii', result, 4+8*i, len(result), len(part))
        result.extend(part)
    if extra:
        result.extend(bytes((-len(result)) % 4))
        offset = len(result)
        result.extend(b'BSPX'+struct.pack('<i', len(extra))+bytes(32*len(extra)))
        for i, (key, payload) in enumerate(extra):
            result.extend(bytes((-len(result)) % 4))
            struct.pack_into('<24sii', result, offset+8+32*i, key, len(result), len(payload))
            result.extend(payload)
    return bytes(result)


def replace(data, replacements):
    """replacements maps old texture name to a complete original donor miptex."""
    parts, extra = lumps(data)
    old = bsp_textures(data)
    lump = bytearray(struct.pack('<i', len(old))+bytes(4*len(old)))
    for i, raw in enumerate(old):
        if raw is None:
            struct.pack_into('<i', lump, 4+4*i, -1)
            continue
        raw = replacements.get(name(raw), raw)
        struct.pack_into('<i', lump, 4+4*i, len(lump))
        lump.extend(raw)
    parts[2] = bytes(lump)
    result = repack(parts, extra)
    before, bx = lumps(data)
    after, ax = lumps(result)
    assert all(before[i] == after[i] for i in range(15) if i != 2)
    assert bx == ax, 'BSPX lighting/collision changed'
    assert len(result) < 25_000_000, 'Map exceeds client download limit'
    return result


ASSAULT = {
    'as_hislop': {
        'hs_wall': 'ind_w02_blu1',
        'met_blu_tile': 'ind_w02_blk1',
        'aqpanl10': 'ind_w04_grey1',
        'met_grn_panel1': 'ind_w08_grn1',
    },
    'as_frigate': {
        'met_brn_block': 'ind_w06_rst2',
        'met_brn_tile2': 'ind_w02_blk1',
        'aqpanl10': 'ind_w04_grey1',
        'met_grn_panel1': 'ind_w08_grn1',
    },
}


def apply_assault(out):
    manifest_path = out/'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    if manifest['id'] not in ASSAULT:
        return
    textures, sources = makkon()
    selection = ASSAULT[manifest['id']]
    path = out/'maps'/(manifest['id']+'.bsp')
    data = path.read_bytes()
    assert sha(data) == manifest['sha256']
    previous = manifest.get('texture_replacements',{})
    data = replace(data, {previous.get(old,old): textures[new] for old, new in selection.items()})
    path.write_bytes(data)
    provenance_path = out/'texture-sources.json'
    provenance = json.loads(provenance_path.read_text())
    for old, new in selection.items():
        provenance.pop(previous.get(old,old), None)
        provenance[new] = sources[new]
    provenance_path.write_text(json.dumps(provenance, indent=2)+'\n')
    manifest.update(sha256=sha(data), bytes=len(data), texture_theme='Makkon industrial (original miptextures)', texture_replacements=selection)
    manifest_path.write_text(json.dumps(manifest, indent=2)+'\n')
    (out/'licenses/Makkon_License.txt').write_bytes((ROOT/'tools/makkon/Makkon_License.txt').read_bytes())


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path, help='Compiled Assault generator output folder')
    apply_assault(parser.parse_args().output)
