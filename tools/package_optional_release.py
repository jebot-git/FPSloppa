"""Package the maintained optional LibreQuake maps; legacy tools stay with 0.5v."""
from pathlib import Path
import zipfile
root=Path(__file__).resolve().parents[1]
version=(root/'VERSION').read_text().strip()
out=root.parent/'Builds'
for source,suffix,prefix in [('optional-map-pack','LibreQuake-Extra-Maps','maps')]:
 path=out/f'FPSloppa-{version}-{suffix}.zip'
 with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
  for file in sorted((root/source).rglob('*')):
   if not file.is_file() or file.name.startswith('.') or '__pycache__' in file.parts:continue
   archive.write(file,Path(prefix)/file.relative_to(root/source))
 print(path)
