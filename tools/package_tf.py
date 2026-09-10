"""Package original TF arenas/tools only; never include converted original BSPs."""
from pathlib import Path
import hashlib
import importlib.util
import json
import shutil
import struct
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / 'optional-tf-map-pack'
TOOLS = ROOT / 'optional-tf-tools'
OUT = ROOT.parent / 'Builds'
VERSION = (ROOT / 'VERSION').read_text().strip()
IDS = ('tf_ironspan', 'tf_relayworks')
NOTICES = ('LibreQuake-COPYING.txt', 'LibreQuake-CREDITS.txt',
           'LibreQuake-README-IMPORTANT-LICENCE-INFO.txt', 'texture-sources.json')

spec = importlib.util.spec_from_file_location('texture_replace', TOOLS / 'texture_replace.py')
textures = importlib.util.module_from_spec(spec)
spec.loader.exec_module(textures)
donors = textures.wad_textures(TOOLS / 'librequake.wad')
provenance = []
for name in IDS:
    raw = (PACK / (name + '.bsp')).read_bytes()
    offset, size = struct.unpack_from('<ii', raw, 20)
    count = struct.unpack_from('<i', raw, offset)[0]
    names = []
    for i in range(count):
        rel = struct.unpack_from('<i', raw, offset + 4 + 4*i)[0]
        assert rel >= 0, 'External texture reference'
        at = offset + rel
        texture = raw[at:at+16].split(b'\0')[0].decode()
        source = donors[texture]
        width, height = struct.unpack_from('<II', raw, at + 16)
        assert (width, height) == struct.unpack_from('<II', source, 16)
        for mip in range(4):
            start = struct.unpack_from('<I', raw, at + 24 + mip*4)[0]
            donor_start = struct.unpack_from('<I', source, 24 + mip*4)[0]
            length = max(1, width >> mip) * max(1, height >> mip)
            assert rel + start + length <= size
            assert raw[at+start:at+start+length] == source[donor_start:donor_start+length], texture
        names.append(texture)
    provenance.append({'id': name, 'sha256': hashlib.sha256(raw).hexdigest(),
                       'textures': names, 'all_four_mips_match_librequake': True})
(PACK / 'texture-validation.json').write_text(json.dumps(provenance, indent=2) + '\n')

OUT.mkdir(exist_ok=True)
archives = []
def archive(label, files):
    path = OUT / f'FPSloppa-{VERSION}-{label}.zip'
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as z:
        for source, destination in files:
            z.write(source, destination)
    archives.append({'file': path.name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                     'size': path.stat().st_size})
    print(path)

files = [(PACK / name, 'maps/' + name) for name in (*NOTICES, 'tf_maplist.txt')]
files += [(PACK / name, 'maps/tf-docs/' + name)
          for name in ('README.md', 'manifest.json', 'texture-validation.json')]
for name in IDS:
    files += [(PACK / (name + ext), 'maps/' + name + ext) for ext in ('.bsp', '.lit')]
    files.append((PACK / (name + '-navigation.res'), 'maps/navigation/' + name + '.res'))
    files.append((PACK / 'source' / (name + '.map'), 'maps/tf-docs/source/' + name + '.map'))
archive('Original-TF-Arenas', files)
archive('TF-Conversion-Tools', [(TOOLS / name, 'TF-Conversion-Tools/' + name)
        for name in (*NOTICES, 'RIGHTS.md', 'convert.py', 'texture_replace.py', 'librequake.wad')])
(OUT / f'FPSloppa-{VERSION}-TF-checksums.json').write_text(json.dumps(archives, indent=2) + '\n')

# Install only the two authored arenas in the local source project's external assets.
for name in IDS:
    for ext in ('.bsp', '.lit'):
        shutil.copy2(PACK / (name + ext), ROOT / 'maps' / (name + ext))
    (ROOT / 'maps/navigation').mkdir(exist_ok=True)
    shutil.copy2(PACK / (name + '-navigation.res'), ROOT / 'maps/navigation' / (name + '.res'))
