"""Add deduplicated, unmodified Makkon records to the shared texture dictionary."""
from pathlib import Path
import json
import shutil
import struct
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'tools'))
from makkon.theme import makkon, sha, name, bsp_textures

PACK = ROOT/'deathmatch/maps/texture_replacements'


def build():
    textures, sources = makkon()
    crosswalk = json.loads(Path(__file__).with_name('shared.json').read_text())['librequake']
    manifest = json.loads((PACK/'manifest.json').read_text())
    # Re-running against an augmented dictionary must not retain obsolete aliases.
    base = {key: row.get('base_entry', row) for key, row in manifest['textures'].items()
            if row.get('pack') != 'makkon-used.wad' or 'base_entry' in row}
    aliases = dict(crosswalk)
    for key, row in base.items():
        if row.get('librequake') in crosswalk:
            aliases[key] = crosswalk[row['librequake']]
    assert all(not key.startswith(('*','sky','+','{')) for key in aliases)
    selected = set(aliases.values())
    # Include only Makkon records actually embedded in maintained maps, never an
    # entire texture family/CTF pack "just in case". Local imports are excluded.
    paths = [ROOT/row['path'].removeprefix('res://') for row in json.loads((ROOT/'deathmatch/maps/manifest.json').read_text())]
    paths += list((ROOT/'optional-map-pack').glob('*.bsp')) + list((ROOT/'optional-tf-map-pack').glob('*.bsp'))
    for path in paths:
        for raw in bsp_textures(path.read_bytes()):
            if raw and name(raw) in textures and raw == textures[name(raw)]:
                selected.add(name(raw))
    assert selected <= textures.keys(), 'Unknown Makkon donor'
    wad = bytearray(b'WAD2'+bytes(8)); directory = []; records = {}
    for key in sorted(selected):
        raw = textures[key]; offset = len(wad); wad.extend(raw)
        directory.append(struct.pack('<iiiBBH16s', offset, len(raw), len(raw), 68, 0, 0, key.encode()))
        width, height = struct.unpack_from('<II', raw, 16)
        records[key] = dict(sources[key], source_sha256=sha(raw), makkon=key,
            width=width, height=height, offset=offset, size=len(raw), pack='makkon-used.wad')
    offset = len(wad); wad.extend(b''.join(directory)); struct.pack_into('<ii', wad, 4, len(directory), offset)
    (PACK/'makkon-used.wad').write_bytes(wad)
    entries = dict(base)
    for key, donor in sorted(aliases.items()):
        entries[key] = dict(records[donor], match='reviewed material/team-colour counterpart; original donor record')
        if key in base: entries[key]['base_entry'] = base[key]
    # Exact names allow a second conversion pass without changing the result.
    for key, row in records.items(): entries[key] = dict(row)
    manifest['textures'] = entries
    manifest['makkon_pack_sha256'] = sha(wad)
    manifest['version'] = sha((PACK/'replacement-miptex.lmp').read_bytes()+wad+json.dumps(entries,sort_keys=True).encode())[:16]
    (PACK/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    shutil.copy2(Path(__file__).with_name('Makkon_License.txt'), PACK/'Makkon_License.txt')
    proof = dict(format='WAD2', sha256=sha(wad), bytes=len(wad), textures={key:sources[key] for key in sorted(selected)},
        aliases=aliases, note='Only records referenced by the shared crosswalk or maintained BSPs. All four original mip levels, names and dimensions unchanged. No unused CTF banners.')
    Path(__file__).with_name('selection.json').write_text(json.dumps(proof, indent=2)+'\n')
    print('MAKKON_SHARED', len(records), 'unique original textures;', len(aliases), 'aliases;', len(wad), 'bytes')
    return proof


if __name__ == '__main__': build()
