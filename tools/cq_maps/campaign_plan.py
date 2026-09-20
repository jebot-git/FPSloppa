"""Export the authored 9×9 campaign plan for review."""
import json
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle,Circle
ROOT=Path(__file__).resolve().parents[2]
fig,axes=plt.subplots(9,9,figsize=(22,24),facecolor='#101724')
for i,ax in enumerate(axes.flat):
    layout=json.loads((ROOT/f'maps/CampaignDistricts/district_{i:02}/layout.json').read_text());row=layout['campaign'];role=row['campaign_role']
    color=('#f86980' if row['initial_owner']==0 else '#58b9fa') if role in ('homebase','perimeter') else '#d19a63' if role=='relay' else '#e9eef5' if role=='hub' else '#52ae88'
    ax.set_facecolor('#1c2938');ax.set_aspect('equal');ax.set_xlim(-128,128);ax.set_ylim(128,-128);ax.set_xticks([]);ax.set_yticks([])
    for spine in ax.spines.values():spine.set_color(color);spine.set_linewidth(2)
    for x,z,w,d,inside in layout['lots']:ax.add_patch(Rectangle((x-w,z-d),w*2,d*2,facecolor='#4b6672' if inside else '#344451',edgecolor='#758590',linewidth=.3))
    for road in layout['streets']:
        xs,zs=zip(*road);ax.plot(xs,zs,color='#a1a9ad',linewidth=1.6)
    for road in layout.get('enclosure',{}).get('bridges',[]):
        xs,zs=zip(*road);ax.plot(xs,zs,color='#ba985f',linewidth=.5,alpha=.75)
    for gate in layout['gates']:ax.scatter(gate['position'][0],gate['position'][2],s=14,c='#97f4dd',marker='s',zorder=4)
    if role in ('homebase','relay','hub'):
        ax.add_patch(Circle((0,0),19,color='#101724',zorder=5));ax.text(0,0,{'homebase':'B','relay':'R','hub':'H'}[role],ha='center',va='center',color=color,fontsize=11,weight='bold',zorder=6)
    elif role=='perimeter':ax.add_patch(Circle((0,0),8,color=color,zorder=5))
    ax.set_title(f'd{i:02} · {row["name"]}\n{role.upper()} · {row["profile"]}',color=color,fontsize=7.3,pad=4)
fig.suptitle('VESPER CAMPAIGN / 81 INDEPENDENT DISTRICTS\nB · 30-point homebase with eight 10-point perimeter districts    R · 30-point relay    H · no-fire inner city\nGreen · neutral outskirts without capture points    Gold lines · upper galleries    Mint squares · district gateways',color='#ecf4fa',fontsize=16,y=.995)
fig.tight_layout(rect=(0,0,1,.955),h_pad=1,w_pad=.6)
out=ROOT/'docs/validation';fig.savefig(out/'campaign-81-plan.png',dpi=130,facecolor=fig.get_facecolor());fig.savefig(out/'campaign-81-plan.svg',facecolor=fig.get_facecolor());plt.close(fig)
svg=out/'campaign-81-plan.svg';svg.write_text('\n'.join(line.rstrip() for line in svg.read_text().splitlines())+'\n')
