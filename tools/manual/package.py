#!/usr/bin/env python3
"""Bundle the offline HTML, illustrations and linked PDF for sharing."""
from pathlib import Path
import re
import shutil
import zipfile
ROOT=Path(__file__).resolve().parents[2]
manual=ROOT/'docs/manual'
out=ROOT/'output'
(out/'pdf').mkdir(parents=True,exist_ok=True)
shutil.copy2(manual/'FPSloppa-Player-Manual.pdf',out/'pdf/FPSloppa-Player-Manual.pdf')
with zipfile.ZipFile(out/'FPSloppa-Manual.zip','w',zipfile.ZIP_DEFLATED) as z:
 for p in sorted(manual.rglob('*')):
  if not p.is_file() or p.name.endswith('.import'):continue
  rel=p.relative_to(manual)
  if rel.as_posix()=='index.html':
   text=p.read_text()
   text=re.sub(r' · <a class="local-ref"[^>]*>Local file</a>','',text)
   text=text.replace('; the adjacent local links work when this manual is kept inside the source tree','')
   z.writestr('FPSloppa-Manual/index.html',text)
  else:z.write(p,'FPSloppa-Manual/'+str(rel))
 z.writestr('FPSloppa-Manual/START-HERE.txt','Open index.html in a modern browser. All content and images work offline.\nOpen FPSloppa-Player-Manual.pdf for the hyperlinked print edition.\nRepository source references require an internet connection.\n')
print(out/'FPSloppa-Manual.zip')
