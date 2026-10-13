"""Fetch hash-pinned authoring sources; no source archives are shipped in the game."""
import hashlib,json,subprocess,sys,urllib.request,zipfile
from pathlib import Path
root=Path(sys.argv[1] if len(sys.argv)>1 else 'test-results/weapon-sources');root.mkdir(parents=True,exist_ok=True)
for source in json.loads(Path(__file__).with_name('sources.json').read_text()):
 target=root/source['file']
 if not target.exists():urllib.request.urlretrieve(source['url'],target)
 if hashlib.sha256(target.read_bytes()).hexdigest()!=source['sha256']:raise RuntimeError('Source hash changed: '+source['file'])
 if source['archive']=='zip':
  with zipfile.ZipFile(target) as archive:archive.extractall(root/source['directory'])
 elif source['archive']=='7z':subprocess.run(['7z','x','-y','-o'+str(root/source['directory']),str(target)],check=True)
 print(source['file'],source['author'])
