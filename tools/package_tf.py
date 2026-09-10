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
OUT = ROOT.parent / 'Builds'
VERSION = (ROOT / 'VERSION').read_text().strip()
IDS = ('tf_ironspan', 'tf_relayworks')
NOTICES = ('LibreQuake-COPYING.txt', 'LibreQuake-CREDITS.txt',
           'LibreQuake-README-IMPORTANT-LICENCE-INFO.txt', 'texture-sources.json')

# Preserve the published provenance check; reject changed BSPs until revalidated.
provenance = json.loads((PACK / 'texture-validation.json').read_text())
for row in provenance:
    assert row['all_four_mips_match_librequake']
    assert hashlib.sha256((PACK / (row['id'] + '.bsp')).read_bytes()).hexdigest() == row['sha256']

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
(OUT / f'FPSloppa-{VERSION}-TF-checksums.json').write_text(json.dumps(archives, indent=2) + '\n')

# Install only the two authored arenas in the local source project's external assets.
for name in IDS:
    for ext in ('.bsp', '.lit'):
        shutil.copy2(PACK / (name + ext), ROOT / 'maps' / (name + ext))
    (ROOT / 'maps/navigation').mkdir(exist_ok=True)
    shutil.copy2(PACK / (name + '-navigation.res'), ROOT / 'maps/navigation' / (name + '.res'))
