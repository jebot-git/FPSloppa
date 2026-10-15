"""Summarize sampled CQ/WiVRn pacing without treating window p95 as global p95."""
import argparse,collections,datetime,json,statistics
from pathlib import Path

def describe(values):
    values=sorted(float(v) for v in values if isinstance(v,(int,float)))
    if not values:return {}
    def quantile(q):
        at=(len(values)-1)*q;low=int(at)
        return values[low]+(values[min(low+1,len(values)-1)]-values[low])*(at-low)
    return {'samples':len(values),'mean':statistics.mean(values),'min':values[0],'p05':quantile(.05),'median':quantile(.5),'p95':quantile(.95),'max':values[-1]}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--session',type=Path,required=True);parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--app-id',type=int,required=True,help='WiVRn application entry to examine; verify its identity separately.')
    args=parser.parse_args();src=args.session;out=args.output;out.mkdir(parents=True,exist_ok=True)
    game=[json.loads(l) for l in (src/'client-gameplay.jsonl').read_text().splitlines()]
    process=[json.loads(l) for l in (src/'client-process-wivrn.jsonl').read_text().splitlines()]
    frames=[json.loads(l.split('FRAME_STATS ',1)[1]) for l in (src/'client-console.log').read_text().splitlines() if l.startswith('FRAME_STATS ')]
    active=[r for r in game if r['active'] and not r['menu'] and not r['dead'] and not r['map_loading']]
    result={'session':str(src),'target_hz':90,'budget_ms':1000/90,'gameplay_fps':describe([r['fps'] for r in active]),'by_class':{},'slow_intervals':[]}
    for role in ['shocktroop','medic','scout','technician']:
        samples=[r for r in active if r['class']==role]
        result['by_class'][role]={'fps':describe([r['fps'] for r in samples]),'seconds_sampled_below_75_fps':sum(r['fps']<75 for r in samples)}
    run=[]
    def finish():
        if len(run)>=5:result['slow_intervals'].append({'first_utc':run[0]['utc'],'last_utc':run[-1]['utc'],'samples':len(run),'classes':dict(collections.Counter(r['class'] for r in run))})
        run.clear()
    for row in game:
        if row in active and row['fps']<75:
            if run and row['ms']-run[-1]['ms']>2500:finish()
            run.append(row)
        else:finish()
    finish()
    result['frame_windows']={'count':len(frames),'window_p95_ms':describe([r['frame_ms_p95'] for r in frames]),'over_90hz_budget':sum(r['frame_ms_p95']>1000/90 for r in frames),'over_2budgets':sum(r['frame_ms_p95']>2000/90 for r in frames)}
    apps=[]
    for row in process:
        w=row.get('wivrn',{})
        for app in w.get('apps',[]):
            if app['id']==args.app_id and app['completed']>0 and 0<=(w['updated_ns']-app['updated_ns'])/1e6<1000:
                apps.append((row,app))
    result['wivrn_app']={k:describe([a[k] for _,a in apps]) for k in ['cpu_ms','gpu_ms','interval_ms']}
    result['interpretation']=[
        'One player. These observations do not validate 64-player performance.',
        'Class timings are correlations with what the player did/visited; class code is not established as the cause.',
        'The old logger had no scope/vehicle/NVG tags or per-spike timestamps, and used a hard-coded 72 Hz budget despite the runtime reporting 90 Hz.',
        'Each FRAME_STATS p95 belongs to its own window. A global frame p95 cannot be recovered from these summaries.',
        'CPU app p95 near the 11.11 ms budget and GPU p95 below it suggest CPU-side/compositor scheduling pressure; neither proves a unique bottleneck.',
        'Fresh state-tagged wall-time/CPU/GPU reports and a matched rendered headset run are needed to validate improvements.'
    ]
    (out/'pacing.json').write_text(json.dumps(result,indent=2)+'\n')
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    import matplotlib.dates as mdates
    from zoneinfo import ZoneInfo
    local=ZoneInfo('Europe/Prague')
    dates=[datetime.datetime.fromisoformat(r['utc']).replace(tzinfo=datetime.timezone.utc) for r in game]
    fig,axes=plt.subplots(3,1,figsize=(12,8),sharex=True,layout='constrained')
    colors={'shocktroop':'#d68b31','medic':'#43a271','scout':'#5387c4','technician':'#9871b5'}
    axes[0].plot(dates,[r['fps'] for r in game],color='#66757a',linewidth=.7,alpha=.6)
    for role,color in colors.items():
        selected=[i for i,r in enumerate(game) if r['class']==role and not r['menu'] and not r['dead']]
        axes[0].scatter([dates[i] for i in selected],[game[i]['fps'] for i in selected],s=5,c=color,label=role)
    axes[0].axhline(90,color='#bf4141',linestyle='--',linewidth=1);axes[0].set_ylabel('Sampled FPS');axes[0].set_ylim(0,102);axes[0].legend(ncol=4,loc='lower right',fontsize=8)
    app_dates=[datetime.datetime.fromtimestamp(r['time'],datetime.timezone.utc) for r,_ in apps]
    axes[1].plot(app_dates,[a['cpu_ms'] for _,a in apps],label='WiVRn app CPU',linewidth=.9)
    axes[1].plot(app_dates,[a['gpu_ms'] for _,a in apps],label='WiVRn app GPU',linewidth=.9)
    axes[1].axhline(1000/90,color='#bf4141',linestyle='--',label='90 Hz budget');axes[1].set_ylabel('App timing (ms)');axes[1].legend(loc='upper right',fontsize=8)
    axes[2].plot(dates,[r['physics_ms'] for r in game],linewidth=.8,label='Client physics callback')
    axes[2].plot(dates,[min(r['process_ms'],50) for r in game],linewidth=.7,alpha=.7,label='Client process callback (clipped at 50 ms)')
    axes[2].axhline(1000/90,color='#bf4141',linestyle='--');axes[2].set_ylabel('Client callback (ms)');axes[2].legend(loc='upper right',fontsize=8)
    axes[2].xaxis.set_major_formatter(mdates.DateFormatter('%H:%M',tz=local));axes[2].set_xlabel('15 October 2026 · Europe/Prague')
    for axis in axes:axis.grid(alpha=.2);axis.set_xlim(dates[0],dates[-1])
    fig.suptitle('CQ live VR test · one player · 90 Hz target\nPer-second samples; WiVRn app identity inferred from newly active entry '+str(args.app_id),fontsize=12)
    fig.savefig(out/'pacing.png',dpi=160);plt.close(fig)
    print(json.dumps({'gameplay_fps':result['gameplay_fps'],'frame_windows':result['frame_windows'],'by_class':result['by_class']}))
if __name__=='__main__':main()
