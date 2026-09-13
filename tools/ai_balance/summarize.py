"""Summarize measured priority trials without treating harness success as balance."""
from pathlib import Path
import argparse,hashlib,json,statistics
from findings import paragraphs
from run import cases
ROOT=Path(__file__).resolve().parents[2]
def quantile(values,q):
 values=sorted(values)
 return values[min(len(values)-1,int((len(values)-1)*q))] if values else 0
def main():
 p=argparse.ArgumentParser();p.add_argument('--label',default='priority-20260912');a=p.parse_args()
 folder=ROOT/'test-results/ai-balance'/a.label
 records=[]
 for status_path in sorted(folder.glob('*-status.json')):
  status=json.loads(status_path.read_text());source=folder/(status['case']+'.json')
  if not status['passed']:continue
  data=json.loads(source.read_text());assert hashlib.sha256(source.read_bytes()).hexdigest()==status['result_sha256']
  if 'balance' not in data:continue
  b=data['balance'];deaths=b['death_equipment'];allowed={0,2,11} if data['effective_rules']=='ut99' else {0,1,2};owned=[x['seconds'] for x in b['hill_runs'] if x['owner']>=0]
  row={**status,'map':data['actual_map'],'mode':data['case']['mode'],'rules':data['effective_rules'],'seed':data['case']['seed'],'mirror':data['case']['mirror'],'class_mix':data['case'].get('class_mix',[]),'deaths':len(deaths),'basic_loadout_deaths':sum(set(d['owned'])<=allowed for d in deaths),'pickups':len(b['pickups']),'weapon_pickups':sum(x['kind']=='weapon' for x in b['pickups']),'shots':sum(x['shots'] for x in data['bots'].values()),'weapon_shots':data['weapons'],'damage_categories':b['damage_categories'],'weapons_damage':data['damage'],'active_bot_seconds':b['active_bot_seconds'],'raw_id_0_to_2_seconds':b['spawn_only_seconds'],'max_stall':max(x['max_stall'] for x in data['bots'].values()),'physics_p50_ms':data['physics_p50_ms'],'physics_p95_ms':data['physics_p95_ms']}
  if row['mode']=='koth':row.update(hill_seconds=b['hill_seconds'],uncontested_mean=statistics.mean(owned) if owned else 0,uncontested_p50=quantile(owned,.5),uncontested_p95=quantile(owned,.95),uncontested_max=max(owned,default=0),approach_deaths=sum(d.get('hill_distance',999)<12 for d in deaths))
  row['death_categories']={key:sum(d['category']==key for d in deaths) for key in sorted({d['category'] for d in deaths})}
  if row['mode'] in ['ctf','tf']:row.update(flag_approach_lives=len(b['flag_approaches']),flag_takes=len(b['flag_carriers']),carrier_progress=b['flag_carriers'],closest_flag_distance=min(b['nearest_flag_by_life'].values(),default=None))
  if row['mode']=='as':row.update(assault_progress=b['assault_progress'],attacker_water_seconds=b['attacker_water_seconds'],wet_attacker_lives=len(b['wet_attacker_lives']))
  if row['mode']=='tf':row.update(class_combat_damage=b['class_combat_damage'],active_class_seconds=b['active_class_seconds'],class_damage_per_active_minute={k:v*60/max(.25,b['active_class_seconds'].get(k,.25)) for k,v in b['class_combat_damage'].items()},teamplay=data['teamplay'])
  if row['mode']=='if':
   freeze_events=[e for e in data['events'] if any(marker in e['text'] for marker in [' is frozen',' thawed','wins the freeze round'])]
   row.update(freezes=b['freezes'],thaws=b['thaws'],freeze_rounds=b['freeze_rounds'],last_freeze_mode_event=freeze_events[-1] if freeze_events else None,teamplay=data['teamplay'])
  records.append(row)
 nav_path=folder/'01-navigation-frozen.json';nav=json.loads(nav_path.read_text()) if nav_path.exists() else {}
 supply={p.stem:json.loads(p.read_text()) for p in folder.glob('*-supplies.json')}
 order=[key for phase in ['koth','ctf','as','tf','cc_if'] for key,_ in cases(phase)]
 expected=set(order)
 records.sort(key=lambda row:order.index(row['case']) if row['case'] in expected else len(order))
 complete={r['case'] for r in records}==expected and all(json.loads(p.read_text())['passed'] for p in folder.glob('*-status.json')) and nav_path.exists() and len(supply)==2
 report={'label':a.label,'complete':complete,'match_count':len(records),'simulated_match_minutes':sum(r['simulated_seconds'] for r in records)/60,'input_hashes':json.loads((folder/'inputs.json').read_text()),'navigation':nav,'supplies':supply,'matches':records,'limits':['Exploratory AI trials, not human win-rate or competitive balance estimates.','Same bot roster swapped between teams; level geometry is unchanged.','Two seeds for most modes; one seed per TF mix. Threaded physics is not perfectly deterministic.','Weapon damage excludes voluntary, environment and hunger categories; class exposure is not a shot-accuracy or causal class-strength estimate.','No network latency, WAN or headset performance claims.','No balance values changed.']}
 finding=folder/'equipment-finding.json'
 if finding.exists():report['equipment_finding']=json.loads(finding.read_text())
 report['raw_json_sha256']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(folder.glob('*.json'))}
 (ROOT/'docs/validation/ai-priority-balance.json').write_text(json.dumps(report,indent=2)+'\n')
 lines=['# Priority-ordered AI balance tests','',f"Status: {'complete' if complete else 'in progress'} — {len(records)} / 24 mirrored/seeded match trials, {report['simulated_match_minutes']:.1f} simulated match minutes.",'','The requested order is qsrc_dm3 navigation → KOTH Alichar → CTF Crownreach → Assault Frigate → TF Vesper → CC/IF. Tests use eight production bots, 60 Hz fixed simulation, and an isolated copy of runtime code/assets. No balance values were changed. The [machine-readable receipt](validation/ai-priority-balance.json) preserves exact inputs, full navigation diagnostics, summaries and limitations. Raw logs and equipment-at-death records are in `test-results/ai-balance/'+a.label+'`.','','## 1. qsrc_dm3 navigation','']
 for probe in nav.get('probes',[]):lines.append(f"- {probe['name']}: {len(probe['reachable_destinations'])} navigation routes to {probe['destinations_tested']} candidate spawn/pickup destinations (those within 3 m are excluded); projection {probe['nav_projection']}.")
 lines += ['', 'Guided trials retain normal movement/physics and force only the chosen goal. Free trials use the production planner. Initial placement is a diagnostic fixture. Inspect the per-seed endpoints and clearance probes in the receipt; a valid navigation route alone is not proof of a usable swim-to-shore route.']
 lines += ['', 'The raised spawn has no complete strategic navigation route. Free exploration escaped in one of three seeds, while two remained on the platform. All three guided trials were explicitly skipped because no route exists. At the water exit, all three guided trials remained approximately 5 m below the chosen shore goal despite a complete navigation path; free exploration escaped in one seed. Repair the local bake/connectivity and validate the vertical shore transition before changing global movement. Nearby capsule probes do not establish a usable doorway aperture or complete swim route.']
 for mode,title in [('koth','2. KOTH Alichar'),('ctf','3. CTF Crownreach'),('as','4. Assault Frigate'),('tf','5. TF Vesper'),('cc','6a. Chainsaw Carnage'),('if','6b. Instagib Freeze Tag')]:
  rows=[r for r in records if r['mode']==mode];lines += ['', '## '+title,'']
  if not rows:lines+=['Pending.'];continue
  lines+=['| Trial | Score red–blue | Basic-loadout deaths / all deaths | Weapon pickups | Max observed stall (s) |','| --- | --- | --- | --- | --- |']
  for r in rows:
   equipment=f"{r['basic_loadout_deaths']}/{r['deaths']}" if mode in ['koth','ctf','as'] else 'N/A'
   lines.append(f"| {r['case']} | {'—' if mode=='cc' else str(r['score'][0])+'–'+str(r['score'][1])} | {equipment} | {r['weapon_pickups']} | {r['max_stall']:.1f} |")
  if mode=='koth':
   total=sum(sum(r['hill_seconds'].values()) for r in rows);seconds={key:sum(r['hill_seconds'][key] for r in rows) for key in ['empty','contested','red','blue']}
   lines+=['', 'Hill occupancy: '+', '.join(f'{k} {v/total:.1%}' for k,v in seconds.items())+'.',f"Deaths within 12 m of the hill: {sum(r['approach_deaths'] for r in rows)}. Mean uncontested streaks per round: "+', '.join(f"{r['uncontested_mean']:.2f}s" for r in rows)+'.']
  if mode in ['ctf','tf']:lines+=['',f"Flag approaches (unique lives within 12 m): {sum(r['flag_approach_lives'] for r in rows)}; takes: {sum(r['flag_takes'] for r in rows)}; captures: {sum(sum(r['score']) for r in rows)}. Carrier closest-to-home measurements are retained per run."]
  if mode=='as':
   for r in rows:lines+=['',r['case']+': '+ '; '.join(f"{x['time']:.1f}s leg {x['leg']+1}, stage {x['stage']}, checkpoint {x['checkpoint']}" for x in r['assault_progress'])+f". Attacker water time {r['attacker_water_seconds']:.1f}s across {r['wet_attacker_lives']} lives."]
  if mode=='cc':
   damage={}
   for r in rows:
    for k,v in r['damage_categories'].items():damage[k]=damage.get(k,0)+v
   lines+=['','Damage categories: '+str(damage)+'. Hunger and environment are excluded from opponent-combat efficiency.']
  if mode=='if':lines+=['',f"Freezes: {sum(r['freezes'] for r in rows)}; successful thaws: {sum(r['thaws'] for r in rows)}; scored freeze rounds: {sum(r['freeze_rounds'] for r in rows)}. These are authoritative events, not inferred from damage."]
  for paragraph in paragraphs(mode,rows,supply):lines+=['',paragraph]
 lines+=['','## Reproduction and integrity','','See [the harness instructions](../tools/ai_balance/README.md) and [supplementary runtime inventory](validation/ai-priority-runtime-inputs.json). Trials ran serially in the requested phase order against a private project copy; fixed inputs were checked after every trial. Successful harness status establishes execution and input integrity, not healthy balance. The [final verification receipt](validation/ai-priority-verification.json) checks coverage, durations, event/score consistency and unchanged runtime inputs. Calibration runs are excluded. Raw result hashes are included in the receipt.']
 lines+=['','## Interpretation limits','','Basic ranged loadout is recomputed from recorded inventories by profile: Doom/Quake allow IDs 0–2 (including melee); UT99 allows 0, 2 and the starting translocator 11, but excludes the acquired Bio Rifle 1. It is not a TF or fixed-loadout strength metric. Raw active-time ID≤2 counters are retained only as diagnostics and are not used for UT99 equipment conclusions. A 12 m approach/death threshold is proximity, not line of sight. Class damage per active minute depends on encounters, roles and survival; it is not a weapon-accuracy estimate. Navigation/capsule supply audits are not live tactical-safety certification. Longer round scores should not be compared directly with the study’s three-minute totals. No movement, objective-health, capture-radius or class nerfs were applied.','']
 (ROOT/'docs/AI-PRIORITY-BALANCE-TESTS.md').write_text('\n'.join(lines))
 print(json.dumps({'complete':complete,'matches':len(records),'minutes':report['simulated_match_minutes']}))
if __name__=='__main__':main()
