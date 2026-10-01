"""Compare fixed-camera native renders; report surface and silhouette differences."""
from pathlib import Path
import json,numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[3];OUT=ROOT/'test-results/weapon-optimization';rows=[]
for entry in json.loads((OUT/'candidate-counts.json').read_text()):
 views=[]
 for i in range(3):
  a=np.asarray(Image.open(OUT/'renders/before'/f'{entry["key"]}_{i}.png').convert('RGB')).astype(float)
  b=np.asarray(Image.open(OUT/'renders/after'/f'{entry["key"]}_{i}.png').convert('RGB')).astype(float)
  bg=a[0,0];ma=np.max(abs(a-bg),axis=2)>4;mb=np.max(abs(b-bg),axis=2)>4;mask=ma|mb
  delta=np.max(abs(a-b),axis=2);views.append({'view':i,'mean_channel_difference':float(np.mean(abs(a-b)[mask])),'changed_over_16_fraction':float(np.mean(delta[mask]>16)),'silhouette_difference_fraction':float(np.sum(ma!=mb)/np.sum(mask))})
 # Changes confined to subpixel edge antialiasing are expected; stronger or
 # widespread differences require retaining the original geometry.
 cylindrical=any(p.get('cylindrical_allowance',False) and p['after']<p['before'] for p in entry['parts'])
 accepted=all(v['mean_channel_difference']<.75 and v['changed_over_16_fraction']<(.015 if cylindrical else .006) and v['silhouette_difference_fraction']<.003 for v in views)
 rows.append({'key':entry['key'],'before':entry['before'],'after':entry['after'],'accepted':accepted,'moderate_cylinder_faceting_allowed':cylindrical,'views':views})
(OUT/'visual-comparison.json').write_text(json.dumps(rows,indent=2)+'\n')
print('Rejected',[(r['key'],r['views']) for r in rows if not r['accepted']]);print('Accepted reduction',sum(r['before']-r['after'] for r in rows if r['accepted']))
