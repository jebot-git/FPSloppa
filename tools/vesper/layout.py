"""Export an annotated plan of the compiled Vesper Abbey BSP."""
from pathlib import Path
import struct,os
os.environ.setdefault('MPLCONFIGDIR','/tmp/vesper-mpl')
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.collections import LineCollection
from matplotlib.patches import Rectangle
ROOT=Path(__file__).resolve().parents[2]
b=(ROOT/'maps/tf_vesper.bsp').read_bytes()
def lump(n):
 p,l=struct.unpack_from('<ii',b,4+n*8);return b[p:p+l]
verts=list(struct.iter_unpack('<fff',lump(3)));lines=[[],[]]
for i,j in struct.iter_unpack('<HH',lump(12)):
 a,c=verts[i],verts[j]
 if abs(a[2]-c[2])>.1 or a[2]<-.1 or a[2]>768:continue
 lines[int(a[2]>260)].append([(a[0]/32,a[1]/32),(c[0]/32,c[1]/32)])
fig,ax=plt.subplots(figsize=(14,10),facecolor='#111922');ax.set_facecolor('#111922')
for layer,color,width in [(1,'#53636b',.4),(0,'#a7b6bf',.6)]:ax.add_collection(LineCollection(lines[layer],colors=color,linewidths=width,alpha=.65))
for side,color,team in [(-1,'#ff8780','RED'),(1,'#87c4ff','BLUE')]:
 for x,y,label,marker in [(58.5,-9.5,'UPPER FLAG','P'),(35.5,11.5,'CAPTURE','o'),(57,27,'SPAWNS','s')]:
  x*=side;y*=side;ax.scatter(x,y,c=color,s=80,marker=marker,zorder=5);ax.annotate(team+' '+label,(x,y),xytext=(0,13),textcoords='offset points',ha='center',color=color,fontsize=9)
 for x,y in [(40,-17),(56,8)]:
  x,y=(x,y) if side>0 else (-x-6,-y-6)
  ax.add_patch(Rectangle((x,y),6,6,facecolor='#deba57',alpha=.8,zorder=4));ax.text(x+3,y+3,'LIFT',ha='center',va='center',color='#151923',fontsize=8,zorder=5)
 x,y=(32,-31) if side>0 else (-56,23)
 ax.add_patch(Rectangle((x,y),24,8,facecolor=color,alpha=.12));ax.text(x+12,y+4,'RAMP →' if side>0 else '← RAMP',color=color,ha='center',va='center',fontsize=9)
ax.text(0,0,'BROKEN\nNAVE',ha='center',va='center',color='#f4ddaa',fontsize=10)
ax.text(0,34,'LOWER CLOISTER',ha='center',color='#becbd0',fontsize=9)
ax.text(0,-35,'LOWER CLOISTER',ha='center',color='#becbd0',fontsize=9)
ax.set(xlim=(-68,68),ylim=(-43,43),aspect='equal',xlabel='Quake X / metres',ylabel='Quake Y / metres')
ax.set_title('VESPER ABBEY  ·  TF 6v6  ·  4v4–8v8\nFour 8 m lifts; permanent walking ramps; faint lines show upper architecture',color='#e8eef0',pad=18)
ax.tick_params(colors='#b7c5cc')
for label in [ax.xaxis.label,ax.yaxis.label]:label.set_color('#b7c5cc')
for spine in ax.spines.values():spine.set_color('#445661')
fig.tight_layout();fig.savefig(ROOT/'maps/VesperAbbey/layout.png',dpi=140,facecolor=fig.get_facecolor());plt.close(fig)
