"""Fetch only approved community source archives, verifying their pinned hashes."""
from pathlib import Path
import hashlib
import json
import subprocess

folder=Path(__file__).with_name('local');folder.mkdir(exist_ok=True)
for row in json.loads(Path(__file__).with_name('approved.json').read_text()):
    if 'slipseer.com' in row['source']:assert row['rating']>=3
    path=folder/row['archive']
    if not path.exists():
        part=path.with_suffix('.zip.part')
        subprocess.run(['curl','-fL','--retry','2',row['download'],'-o',str(part)],check=True)
        assert hashlib.sha256(part.read_bytes()).hexdigest()==row['sha256']
        part.replace(path)
    assert hashlib.sha256(path.read_bytes()).hexdigest()==row['sha256']
    print('VERIFIED',path.name)
