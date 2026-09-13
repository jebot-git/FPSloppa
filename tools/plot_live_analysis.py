from pathlib import Path
import json,csv,collections,numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
root=Path(__file__).resolve().parents[1];report=json.loads((root/'test-results/live-session-analysis.json').read_text());out=root/'docs/validation/live-0.10v';out.mkdir(exist_ok=True)
plt.rcParams.update({'font.size':10,'axes.spines.top':False,'axes.spines.right':False})
fig,ax=plt.subplots(2,2,figsize=(13,9),layout='constrained')
modes=['dm','koth','tf','cc','ft','as','ig'];x=np.arange(len(modes));d=report['per_mode']
ax[0,0].bar(x-.16,[d[m]['physics_ms']['median'] for m in modes],.32,label='Median',color='#385e87');ax[0,0].bar(x+.16,[d[m]['physics_ms']['p95'] for m in modes],.32,label='95th percentile',color='#d89b42');ax[0,0].axhline(16.667,color='#ae343b',ls='--',label='60 Hz tick budget');ax[0,0].set(xticks=x,xticklabels=[m.upper() for m in modes],ylabel='Physics sample (ms)',title='Server samples: 0–5 players (mixed occupancy)');ax[0,0].legend(fontsize=8)
labels=['HiSlop\nEnvironment','HiSlop\nWeapons + sentries','Frigate\nEnvironment','Frigate\nWeapons + sentries'];values=[]
for m in ['as_hislop','as_frigate']:
 w=report['per_map'][m]['weapons'];values += [w.get('environment',{}).get('fatal_events',0),sum(v['fatal_events'] for k,v in w.items() if k not in ['environment','SUICIDE'])]
ax[0,1].bar(labels,values,color=['#ae343b','#385e87','#ae343b','#385e87']);ax[0,1].set(title='Assault: recorded fatal damage events',ylabel='Events (one paired match per map)');ax[0,1].bar_label(ax[0,1].containers[0]);ax[0,1].set_ylim(0,18);ax[0,1].text(.02,.96,'All sampled teams were 3v2; excludes explicit suicides.',transform=ax[0,1].transAxes,va='top',fontsize=8)
rows=list(csv.DictReader((root/'test-results/assault-movement.csv').open()));alive=[r for r in rows if r['dead']=='false'];xx=np.array([-float(r['z']) for r in alive]);yy=np.array([-float(r['x']) for r in alive]);h=ax[1,0].hist2d(xx,yy,bins=[75,18],range=[[-88,74],[-12,12]],cmap='YlOrRd',norm=matplotlib.colors.LogNorm());fig.colorbar(h[3],ax=ax[1,0],label='Alive player-samples (~20 Hz)');ax[1,0].scatter([1856/32,2016/32],[112/32,-112/32],marker='*',s=100,c='#256fa4');ax[1,0].set(title='HiSlop: time spent along the train',xlabel='Along train (map metres)',ylabel='Across train (map metres)');ax[1,0].text(.02,.02,'Overhead projection merges decks; stars mark objectives.\nStanding time is not evidence of being stuck.',transform=ax[1,0].transAxes,fontsize=8)
labels=['HiSlop leg 1','HiSlop leg 2','Frigate leg 1'];v=[5.220,8.966,52.983];ax[1,1].barh(labels,v,color=['#d89b42','#d89b42','#385e87']);ax[1,1].set(title='Time from objective 1 to objective 2',xlabel='Seconds');ax[1,1].bar_label(ax[1,1].containers[0],fmt='%.1f s',padding=3);ax[1,1].set_xlim(0,65);ax[1,1].text(.02,.06,'Frigate leg 2 ran out of time after objective 1.',transform=ax[1,1].transAxes,fontsize=8)
fig.suptitle('FPSloppa 0.10v · Live-session findings',fontsize=17)
fig.savefig(out/'analysis.png',dpi=170);plt.close(fig)
