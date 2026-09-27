"""Export a plan showing the buried connections hidden by the BSP's roof."""
from pathlib import Path
import json,math
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.collections import LineCollection
ROOT=Path(__file__).resolve().parents[3]
out=ROOT/'test-results/cindercoil'
r=json.loads((ROOT/'maps/Cindercoil/route.json').read_text())
p=json.loads((ROOT/'maps/Cindercoil/probes.json').read_text())
s=np.array([row['position'] for row in r['samples']]);right=np.array([row['right'] for row in r['samples']])
fig,ax=plt.subplots(figsize=(11,10),facecolor='#111a24');ax.set_facecolor('#111a24')
edge=np.concatenate([(s+right*24)[:,[0,2]],(s-right*24)[::-1,[0,2]]])
ax.fill(edge[:,0],edge[:,1],color='#344453',zorder=1)
# The hidden central hall and its four connected radial passages.
ax.add_patch(plt.Circle((r['radius'],0),12.5,color='#c18b43',alpha=.35,zorder=2))
for tunnel in p['tunnels']:
 a=np.array(tunnel['entry']);b=np.array(tunnel['hub'])
 ax.plot([a[0],b[0]],[a[2],b[2]],color='#efb765',lw=16,solid_capstyle='round',alpha=.75,zorder=2)
 ax.scatter(a[0],a[2],s=38,color='#fff1ce',zorder=5)
 ax.annotate(f"{int(tunnel['distance'])} m",(a[0],a[2]),xytext=(6,5),textcoords='offset points',color='#fff1ce',fontsize=10,zorder=6)
pts=s[:,[0,2]].reshape(-1,1,2);segments=np.concatenate([pts[:-1],pts[1:]],axis=1)
lc=LineCollection(segments,cmap='Blues',norm=plt.Normalize(0,14),linewidth=5,zorder=3);lc.set_array(s[:-1,1]+2);ax.add_collection(lc)
for distance in [35,115,200,285]:
 row=r['samples'][distance*4];a=np.array(row['position']);f=np.array(row['forward'])
 ax.annotate('',xy=(a[0]+f[0]*6,a[2]+f[2]*6),xytext=(a[0],a[2]),arrowprops=dict(arrowstyle='->',color='#dfefff',lw=2),zorder=4)
for d in [92,179,248]:
 row=r['samples'][d*4];a=np.array(row['position']);x=np.array(row['right']);ends=[a-x*20,a+x*20]
 ax.plot([v[0] for v in ends],[v[2] for v in ends],color='#a8cacf',lw=4,zorder=4)
 for v in ends:ax.scatter(v[0],v[2],s=80,marker='s',color='#a8cacf',edgecolor='#111a24',zorder=5)
for d in [80,230]:
 a=s[d*4];ax.scatter(a[0],a[2],s=125,marker='D',color='#f6d36d',edgecolor='#111a24',zorder=6)
 ax.annotate(f'CHECKPOINT\n{d} m',(a[0],a[2]),xytext=(-65,-35) if d==80 else (-65,24),textcoords='offset points',fontsize=10,color='#ffe298',weight='bold',zorder=7)
for station in p['stations']:
 a=station['position'];ax.scatter(a[0],a[2],s=68,marker='+',linewidths=2.4,color='#9fedb4',zorder=6)
for d,color,label,offset in [(0,'#ff7b73','ATTACKER HANGAR\n0 m · level base',(-92,-42)),(350,'#91ceff','DEFENDER BASE\n350 m · +14 m',(-48,-32))]:
 a=s[d*4];ax.scatter(a[0],a[2],s=115,color=color,edgecolor='#111a24',zorder=6)
 ax.annotate(label,(a[0],a[2]),xytext=offset,textcoords='offset points',color=color,fontsize=11,weight='bold',zorder=7)
ax.text(r['radius'],0,'CENTRAL\nHALL',ha='center',va='center',color='#fff1ce',weight='bold',fontsize=11,zorder=6)
ax.text(.04,.98,'CINDERCOIL',transform=ax.transAxes,color='white',weight='bold',fontsize=24,va='top')
ax.text(.04,.925,'TITANBALL  /  350 m route  /  14 m climb',transform=ax.transAxes,color='#b3c5d8',fontsize=12)
ax.text(.04,.065,'GOLD: internal tunnels    SQUARES: overpass towers    + resupply',transform=ax.transAxes,color='#d2dbe4',fontsize=10)
ax.text(.04,.025,'56 m → 315 m entrance: 88 m walking path, versus 259 m along the Titan route.',transform=ax.transAxes,color='#efb765',fontsize=10)
ax.set_xlim(-46,177);ax.set_ylim(-110,115);ax.set_aspect('equal');ax.axis('off')
fig.savefig(out/'layout.png',dpi=150,bbox_inches='tight',facecolor=fig.get_facecolor())
fig.savefig(ROOT/'maps/Cindercoil/layout.svg',bbox_inches='tight',facecolor=fig.get_facecolor())
