"""Atomic, self-contained static campaign page. No identities or secrets exported."""
from datetime import datetime, timezone
from html import escape
from pathlib import Path
import os


def utc(value):
    return datetime.fromtimestamp(value,timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')


def render(state, now):
    campaign=state.get('campaign') or {}
    names={-1:'Neutral',0:'Red',1:'Blue'}
    tiles=[]
    for district,row in sorted(state['districts'].items()):
        owner=campaign.get('owners',{}).get(district,-1)
        points=campaign.get('points',{}).get(district,[0,0])
        lock=campaign.get('locks',{}).get(row.get('homebase'),{})
        lines=[escape(row.get('name',district)), escape(row.get('campaign_role','district')),
               f'{names[owner]} · {row["reservations"]}/16', 'Online' if row['online'] else 'Offline']
        if row.get('threshold'):lines.append(f'Capture R {points[0]:.0f} / B {points[1]:.0f} → {row["threshold"]}')
        if lock:lines.append('Lockdown until '+utc(lock['until']))
        hold=campaign.get('holds',{}).get(district)
        if hold:lines.append('Holding since '+utc(hold['since']))
        tiles.append(f'<article class="team{owner}" title="{escape(district)}"><b>{escape(district)}</b><br>'+ '<br>'.join(lines)+'</article>')
    history=''.join('<tr><td>'+str(h['epoch'])+'</td><td>'+utc(h['ended'])+'</td><td>'+str(h['scores'][0])+' – '+str(h['scores'][1])+'</td><td>'+('Draw' if h['winner']==-1 else names[h['winner']])+'</td></tr>' for h in reversed(campaign.get('history',[])))
    scores=campaign.get('scores',[0,0])
    return f'''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta http-equiv="refresh" content="30"><title>CQ campaign</title>
<style>body{{font:15px system-ui;background:#111724;color:#e7eef8;margin:2rem}}h1{{margin-bottom:.3rem}}.grid{{display:grid;grid-template-columns:repeat(9,minmax(140px,1fr));gap:5px;overflow:auto}}article{{padding:9px;background:#28313d;border-top:4px solid #9099a5;font-size:12px;min-height:120px}}.team0{{border-color:#f26778}}.team1{{border-color:#68b2f8}}table{{border-collapse:collapse}}td,th{{padding:8px 18px;text-align:left;border-bottom:1px solid #384459}}p{{line-height:1.6}}a{{color:#b9d5fa}}</style>
<h1>CQ · Campaign {campaign.get('epoch',1)}</h1><p><strong>Red {scores[0]} / 20 · Blue {scores[1]} / 20</strong><br>
Players {state.get('player_count',0)} / 128 · {sum(a['phase']=='waiting' for a in state.get('actors',{}).values())} waiting · {sum(r['online'] for r in state['districts'].values())} / 81 districts online<br>
Updated {utc(now)} · Next daily award {utc(campaign.get('next_award',now))}<br>One victory point per controlled homebase at UTC midnight. First to 20 wins; the campaign then resets.</p>
<section class="grid" aria-label="81 district campaign map">{''.join(tiles)}</section>
<h2>Campaign results</h2><table><thead><tr><th>Campaign</th><th>Finished</th><th>Red – Blue</th><th>Winner</th></tr></thead><tbody>{history or '<tr><td colspan="4">No completed campaigns yet.</td></tr>'}</tbody></table>
<p>Refreshes every 30 seconds. Check the update timestamp if the master is unavailable.</p></html>'''


def write(path, state, now):
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
    temporary=path.with_name(path.name+'.tmp')
    temporary.write_text(render(state,now),encoding='utf-8')
    os.replace(temporary,path)
