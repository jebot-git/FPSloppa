#!/usr/bin/env python3
"""Compare the corrected boarding baseline with coverage/cover playtests."""
import argparse, collections, json, math, os, statistics
from pathlib import Path

os.environ.setdefault('MPLCONFIGDIR', '/tmp/fpsloppa-matplotlib')
parser = argparse.ArgumentParser()
parser.add_argument('files', nargs='+', help='Baseline first, then completed new runs')
parser.add_argument('--output', required=True)
args = parser.parse_args()

def episodes(data):
    rows = []
    changes = data['pilot_changes']
    for i, change in enumerate(changes):
        if not change['to']:
            continue
        end = changes[i+1]['time'] if i+1 < len(changes) else data['seconds']
        start = max(60, change['time'])
        if end <= start:
            continue
        died = any(e['victim'] == change['to'] and abs(e['time']-end) < .02 for e in data['deaths'])
        boarding = next((b for b in data['boardings'] if b['pilot'] == change['to'] and abs(b['time']-change['time']) < .02), {})
        rows.append(dict(start=start, end=end, seconds=end-start, pilot=change['to'],
                         distance=change['distance'], died=died, role=boarding.get('class', 'unknown')))
    return rows

raw = [json.loads(Path(file).read_text()) for file in args.files]
rows = []
all_episodes = []
for file, data in zip(args.files, raw):
    ep = episodes(data)
    all_episodes.append(ep)
    active = data['seconds']-60
    damage = [e for e in data['damage_events'] if e['time'] >= 60]
    cannon = [e for e in damage if e['weapon'] == 'TITAN CANNON' and e['attacker_team'] == 0 and e['victim_team'] == 1]
    crush = [e for e in damage if e['weapon'] == 'TITAN CRUSH' and e['victim_team'] == 1]
    deaths = collections.Counter(e['team'] for e in data['deaths'] if e['time'] >= 60)
    rounds = sum(v['barrels'] for v in data['cannon_volleys'] if v['time'] >= 60)
    kills = sum(e['fatal'] for e in cannon)
    health_damage = sum(e['damage'] for e in cannon)
    pilot_deaths = sum(e['died'] for e in ep)
    cps = {}
    for sample in data['samples']:
        if sample['checkpoint'] and sample['checkpoint'] not in cps:
            cps[sample['checkpoint']] = sample['time']-60
    classes = {}
    for role in sorted({e['role'] for e in ep}):
        subset = [e for e in ep if e['role'] == role]
        classes[role] = dict(episodes=len(subset), mean_seconds=statistics.mean(e['seconds'] for e in subset),
                            median_seconds=statistics.median(e['seconds'] for e in subset), deaths=sum(e['died'] for e in subset))
    rows.append(dict(file=file, seed=int(data['options']['seed']), revision=data['options']['revision'],
        renderer='headless' if not data['options'].get('record') else 'Vulkan Mobile recording',
        winner=['Attackers','Defenders'][data['winner']] if data['winner'] in [0,1] else 'Unfinished',
        active_seconds=active, remaining_seconds=max(0,600+180*data['checkpoints']-active),
        distance_m=data['progress'], checkpoints=cps, boardings=len(data['boardings']),
        pilot_seconds=data['pilot_seconds'], pilot_duty_percent=100*data['pilot_seconds']/active,
        mean_pilot_seconds=statistics.mean(e['seconds'] for e in ep), median_pilot_seconds=statistics.median(e['seconds'] for e in ep),
        under_one_second_percent=100*sum(e['seconds']<1 for e in ep)/len(ep),
        death_ended_episodes=pilot_deaths, censored_episodes=len(ep)-pilot_deaths,
        deaths_during_exit_lock=sum(any(d['victim']==b['pilot'] and b['time']<=d['time']<b['time']+3 for d in data['deaths']) for b in data['boardings']),
        deaths_attack_defend=[deaths[0],deaths[1]], cannon_kills=kills, cannon_logged_health_damage=health_damage,
        cannon_damage_per_piloted_second=health_damage/max(1,data['pilot_seconds']),
        cannon_kills_per_piloted_minute=60*kills/max(1,data['pilot_seconds']),
        cannon_kills_per_pilot_death=kills/max(1,pilot_deaths), cannon_share_of_defender_deaths_percent=100*kills/max(1,deaths[1]),
        fired_rounds=rounds, direct_events_per_round_percent=100*sum(not e['blast'] for e in cannon)/max(1,rounds),
        peak_pair_heat=max((v['heat'] for v in data['cannon_volleys']),default=0),
        overheat_volleys=sum(v['heat']>=100 for v in data['cannon_volleys']),
        crush_kills=len(crush), gibbed_crush_kills=sum(e.get('gibbed',False) for e in crush),
        destroyed_blue_deployables=dict(collections.Counter(e['kind'] for e in data.get('deployable_crushes',[]))),
        pilot_noncontact_hits=sum(e['pilot'] and not e['hull_contact'] for e in damage),
        max_abs_body_yaw_degrees=max(abs(s['body_yaw'])*180/math.pi for s in data['samples']) if 'body_yaw' in data['samples'][0] else None,
        by_class=classes, episodes=ep))

pooled = [e for group in all_episodes[1:] for e in group]
result = dict(runs=rows, new_runs_pooled=dict(rounds=len(rows)-1,
    attacker_wins=sum(r['winner']=='Attackers' for r in rows[1:]),
    pilot_episodes=len(pooled), mean_pilot_seconds=statistics.mean(e['seconds'] for e in pooled),
    median_pilot_seconds=statistics.median(e['seconds'] for e in pooled)),
    notes=['Cannon damage is logged post-armour health damage and can include overkill; crush damage is excluded from efficiency totals.',
           'Active combat excludes preparation. A final surviving tenure is censored at round end.',
           'The baseline and new native run share seed 7129; other seeds are headless robustness checks, not paired before/after trials.',
           'Combined changes and a small fixed-roster bot sample cannot identify individual effects or establish human-team win rates.'])
out = Path(args.output)
out.write_text(json.dumps(result,indent=2)+'\n')

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
fig, axes = plt.subplots(2,2,figsize=(12,8.5))
colors = ['#888888','#087da5','#ae5c1d','#467845']
for i, (data,row,ep) in enumerate(zip(raw,rows,all_episodes)):
    color=colors[i%len(colors)];label=f"{row['revision']} / {row['seed']}"
    axes[0,0].plot([(s['time']-60)/60 for s in data['samples']],[s['distance'] for s in data['samples']],label=label,color=color)
    values=sorted(e['seconds'] for e in ep)
    axes[0,1].step(values,[100*(j+1)/len(values) for j in range(len(values))],where='post',color=color,label=label)
    axes[1,0].bar(i,row['cannon_damage_per_piloted_second'],color=color)
    axes[1,0].text(i,row['cannon_damage_per_piloted_second']+.12,f"{row['cannon_damage_per_piloted_second']:.1f}",ha='center')
    axes[1,1].bar(i,row['cannon_share_of_defender_deaths_percent'],color=color)
    axes[1,1].text(i,row['cannon_share_of_defender_deaths_percent']+.3,f"{row['cannon_kills']} kills",ha='center',fontsize=9)
for y in [90,190]:axes[0,0].axhline(y,color='#aaaaaa',linestyle=':',linewidth=1)
axes[0,0].set(xlabel='Active minutes',ylabel='Route distance (m)',ylim=(0,305),title='Payload progress');axes[0,0].legend(fontsize=8)
axes[0,1].set(xlabel='Active cockpit tenure (seconds)',ylabel='Cumulative episodes (%)',xlim=(0,15),ylim=(0,101),title='Pilot survival (view limited to 15 seconds)')
labels=[('R5' if i==0 else 'R6')+'\n'+str(r['seed']) for i,r in enumerate(rows)]
axes[1,0].set(xticks=range(len(rows)),xticklabels=labels,ylabel='Logged health damage / occupied second',title='Cannon support while piloted')
axes[1,1].set(xticks=range(len(rows)),xticklabels=labels,ylabel='Share of defender deaths (%)',title='Cannon combat contribution')
for ax in axes.flat:ax.grid(axis='y',alpha=.2);ax.set_axisbelow(True)
fig.suptitle('TITANBALL / Ashfall / TF 6v6 / coverage and street-cover study',fontsize=14)
fig.text(.5,.015,'Baseline and primary rerun: native Vulkan. Additional seeds: headless. Exploratory bot sample; combined changes.',ha='center',fontsize=9)
fig.tight_layout(rect=(0,.03,1,.96));fig.savefig(out.with_suffix('.png'),dpi=150)
for row in rows:print(row['revision'],row['seed'],row['winner'],round(row['distance_m'],2),'pilot',round(row['mean_pilot_seconds'],2),round(row['median_pilot_seconds'],2),'cannon',row['cannon_kills'])
