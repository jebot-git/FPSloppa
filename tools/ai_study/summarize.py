#!/usr/bin/env python3
"""Condensed receipts; raw demos, logs and intermediate trials stay in test-results."""
import collections,hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'test-results/ai-study'
rows=[json.loads(line) for line in (ROOT/'test-results/remote-all-modes/server.jsonl').read_text().splitlines()]
rows=[r for r in rows if r['epoch']>=3]
log_modes={}
for mode in ['dm','tdm','ctf','koth','ig','if','ft','cc','tf','as']:
 rr=[r for r in rows if r['mode']==mode];damage=collections.Counter()
 for r in rr:
  if r['event']=='damage':damage[r['data'].get('weapon','?')]+=r['data'].get('damage',0)
 log_modes[mode]=dict(events=dict(collections.Counter(r['event'] for r in rr)),damage_by_source=dict(damage),objective_messages=[r['data']['message'] for r in rr if r['event']=='match_event' and any(w in r['data']['message'].lower() for w in ['flag','captur','frozen','thaw','checkpoint'])])
def condensed(path):
 data=json.loads(path.read_text());out=[]
 for row in data:
  row=dict(row);b=dict(row.get('behaviour',{}));b.pop('idle_examples',None);row['behaviour']=b;out.append(row)
 return out
receipt=dict(recording='video-output/remote-all-modes-2026-09-12.mp4',recorded_log_analysis=log_modes,practice={},network={},regressions={})
for label in ['baseline','baseline-other','candidate','recovery','final','final-confirm','second-seed']:
 p=OUT/label/'summary.json'
 if p.exists():receipt['practice'][label]=condensed(p)
for label in ['network-before','network-after','network-final']:
 p=OUT/label/'audit.json'
 if not p.exists():continue
 d=json.loads(p.read_text());rounds=[]
 for s in d['segments']:
  rounds.append(dict(mode=s['mode'],seconds=s['end']-s['start'],shots=s['shots'],yaw_degrees_per_active_second=s['yaw_degrees']/max(1,s['active_seconds']),stationary_fraction=s['stationary_seconds']/max(1,s['active_seconds']),close_pair_fraction=s['close_pair_seconds']/max(1,s['team_pair_seconds'])))
 receipt['network'][label]=dict(rounds=rounds,processes=json.loads((p.parent/'results.json').read_text()))
for label in ['regressions','regressions-final']:
 p=OUT/(label+'.json')
 if p.exists():receipt['regressions'][label]=json.loads(p.read_text())
role_log=(OUT/'roles-final.log').read_text()
receipt['regressions']['roles-current']={'passed':'BOT_ROLE_RESULT []' in role_log and 'FAIL ' not in role_log and 'SCRIPT ERROR:' not in role_log,'checks':sum(line.startswith('PASS ') for line in role_log.splitlines())}
receipt['source_sha256']={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [ROOT/'deathmatch/bots.gd',*sorted((ROOT/'deathmatch/bot_ai').glob('*.gd')),ROOT/'tools/remote_match/client_ai.gd',ROOT/'tools/remote_match/client_arena.gd']}
p=ROOT/'docs/validation/ai-competitive-study.json';p.write_text(json.dumps(receipt,indent=2)+'\n');print(p)

base={r['mode']:r for label in ['baseline','baseline-other'] for r in receipt['practice'].get(label,[])}
latest={r['mode']:r for label in ['final','final-confirm'] for r in receipt['practice'].get(label,[])}
lines=['\n## Measured practice comparison\n','Eight bots, seed 7129, 180 simulated seconds per mode. A different random seed is retained separately in the receipt. These are AI behavior checks, not human balance estimates. DM/IG/CC use personal frags, so their team-score columns are inapplicable.\n','| Mode | Active idle, before → after | Close teammate pairs, before → after | Pickups, before → after | Team score, before → after |','|---|---:|---:|---:|---|']
for mode,b in base.items():
 if mode not in latest:continue
 a=latest[mode]
 def idle(r):
  q=r['behaviour'];return 100*q['idle_samples']/max(1,q['active_samples'])
 def close(r):
  q=r['behaviour'];return 100*q['close_pair_samples']/max(1,q['team_pair_samples'])
 score='—' if mode in ['dm','ig','cc'] else str(b['score'])+' → '+str(a['score'])
 lines.append(f"| {mode.upper()} | {idle(b):.1f}% → {idle(a):.1f}% | {close(b):.1f}% → {close(a):.1f}% | {b['counts'].get('pickup',0)} → {a['counts'].get('pickup',0)} | {score} |")
lines.append('\nIdle here means the planner selected no strategic route; it excludes intentional holding and is different from snapshot stationarity. Low idle alone does not prove successful traversal. The qsrc_dm3 spawn/island issue persists, and three-minute CTF rounds still ended without a capture.\n')
report=ROOT/'docs/AI-COMPETITIVE-BEHAVIOUR-STUDY.md'
s=report.read_text().split('\n## Measured practice comparison')[0];report.write_text(s+'\n'.join(lines))
