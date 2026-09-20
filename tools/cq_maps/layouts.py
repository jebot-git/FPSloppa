"""Review all urban district plans and reject mirrored/rotated street-plan clones."""
import collections, hashlib, json
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, Circle
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'maps/CQDistricts';OUT=ROOT/'test-results/cq-maps';OUT.mkdir(exist_ok=True)
def identity(streets):
 variants=[]
 for mirror in [-1,1]:
  for rotation in range(4):
   roads=[]
   for road in streets:
    points=[]
    for x,z in road:
     x*=mirror
     for _ in range(rotation):x,z=-z,x
     points.append((x,z))
    roads.append(min(tuple(points),tuple(reversed(points))))
   variants.append(tuple(sorted(roads)))
 return hashlib.sha256(repr(min(variants)).encode()).hexdigest()
fig,axes=plt.subplots(4,4,figsize=(16,17),facecolor='#101522')
seen=set();rows=[]
for zone,ax in enumerate(axes.flat):
 layout=json.loads((BASE/f'district_{zone:02d}/layout.json').read_text());signature=identity(layout['streets'])
 assert signature not in seen,'Rotated or mirrored street-plan duplicate';seen.add(signature)
 props=collections.Counter(p['kind'] for p in layout['props'])
 assert props['streetlamp']>=8 and props['parked_vehicle']+props['freight_vehicle']>=4 and props['market_stall']>=3
 assert len(layout['spawns'])==4 and len(layout['pickup_positions'])==8
 assert len(layout['lots'])>=16 and len(layout['rooms'])>=3
 ax.set_facecolor('#182231');ax.set_aspect('equal');ax.set_xlim(-128,128);ax.set_ylim(128,-128);ax.set_xticks([]);ax.set_yticks([])
 for road in layout['streets']:
  xs,zs=zip(*road);ax.plot(xs,zs,color='#7d8994',linewidth=5,solid_capstyle='round');ax.plot(xs,zs,color='#36404c',linewidth=3)
 for x,z,w,d,interior in layout['lots']:
  assert ((max(0,abs(x)-w))**2+(max(0,abs(z)-d))**2)**.5>=33
  ax.add_patch(Rectangle((x-w,z-d),w*2,d*2,facecolor='#3b9cba' if interior else '#827971',edgecolor='#bec1bd',linewidth=.35))
 for p in layout['props']:
  if p['kind']=='skyway':
   xs,zs=zip(*p['points']);ax.plot(xs,zs,color='#ffc56c',linewidth=1.5)
 for gate in layout['gates']:
  x,_,z=gate['position'];ax.scatter(x,z,s=28,color='#74ebcc',marker='s',zorder=5)
 ax.add_patch(Circle((0,0),9,facecolor='#e9d68b',edgecolor='white',linewidth=.5))
 ax.set_title(f'{zone+1:02} {layout["name"]}\n{layout["street_plan"]}',color='#edf3f7',fontsize=9)
 rows.append(dict(zone=zone,name=layout['name'],street_plan=layout['street_plan'],street_signature=signature,buildings=len(layout['lots']),interiors=len(layout['rooms']),props=dict(props)))
fig.suptitle('VESPER / DISTINCT DISTRICT STREET PLANS\nCyan: accessible interiors · Grey: other buildings · Gold: capture / skyways · Green: gates',color='white',fontsize=15)
fig.tight_layout(rect=(0,0,1,.96));fig.savefig(OUT/'urban-plans.png',dpi=130,facecolor=fig.get_facecolor());plt.close(fig)
report=dict(districts=16,distinct_up_to_rotation_and_reflection=len(seen),rows=rows)
(OUT/'urban-layouts.json').write_text(json.dumps(report,indent=2)+'\n');print('CQ_URBAN_LAYOUTS',len(seen))
