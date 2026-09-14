#!/usr/bin/env python3
"""Render matched robot progress curves from the healing comparison report."""
import argparse,json,os
from pathlib import Path
config=Path(__file__).resolve().parents[3]/"test-results/matplotlib";config.mkdir(parents=True,exist_ok=True)
os.environ.setdefault("MPLCONFIGDIR",str(config))
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
p=argparse.ArgumentParser();p.add_argument('report');p.add_argument('--output',required=True);a=p.parse_args()
d=json.loads(Path(a.report).read_text());seeds=sorted({r['seed'] for r in d['matches']})
colors={'class_hp_healing':'#864ab0','previous':'#7a8797','200_hp':'#cb871d','200_hp_healing':'#187d82'}
labels={'class_hp_healing':'Class HP + 10 HP/s','previous':'Previous class HP','200_hp':'200 HP','200_hp_healing':'200 HP + 10 HP/s'}
fig,axes=plt.subplots(1,len(seeds),figsize=(13,4.4),sharex=True,sharey=True,squeeze=False)
for ax,seed in zip(axes[0],seeds):
 for row in d['matches']:
  if row['seed']!=seed:continue
  run=json.loads(Path(row['file']).read_text());samples=[s for s in run['samples'] if s['time']>=60]
  ax.plot([(s['time']-60)/60 for s in samples],[s['distance'] for s in samples],color=colors[row['treatment']],label=labels[row['treatment']],linewidth=1.8)
  ax.scatter([row['active_seconds']/60],[row['distance_m']],color=colors[row['treatment']],s=27,marker='o' if row['attacker_win'] else 'x',zorder=5)
 ax.set_title(f'Seed {int(seed)}');ax.set_xlabel('Active minutes');ax.set_xlim(0,16.2);ax.set_ylim(0,310);ax.grid(alpha=.18)
 for y in [100,200,290]:ax.axhline(y,color='#999999',linestyle=':',linewidth=.6)
axes[0][0].set_ylabel('Robot progress (m)')
policy='heavy-ordnance hull filter' if d.get('pilot_damage','heavy')=='heavy' else 'heavy-ordnance restriction OFF'
fig.suptitle('TITANBALL · 6v6 TF/Quake · '+policy+' in every trial',fontsize=12)
handles,legend=axes[0][0].get_legend_handles_labels();fig.legend(handles,legend,loc='lower center',ncol=len(handles),frameon=False)
fig.tight_layout(rect=(0,.09,1,.96));fig.savefig(a.output,dpi=160);plt.close(fig)
