"""Compare the standalone matrix to archived same-VPS Godot-hosted authority runs."""
import argparse,csv,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
ARCHIVE=ROOT/'docs/validation/voxel-battle'
def load(p):return json.loads(p.read_text())
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('results',type=Path);a=p.parse_args();out=a.results.resolve();rows=[];details=[]
 historical={
  (64,30):ARCHIVE/'resident-cq-complete-20261014/vps/64-normal/server.json',
  (64,60):ARCHIVE/'capacity-128-60hz-20261015/load-20261015-64-60-final/server.json',
  (128,30):ARCHIVE/'capacity-128-60hz-20261015/load-20261015-128-reload/server.json'}
 old_resource=load(ARCHIVE/'resident-cq-complete-20261014/vps/resource-summary.json')['64-normal']
 for result in load(out/'matrix.json'):
  players,hz=result['players'],result['configured_hz'];case=out/f'{players}-{hz}';server=load(case/'server.json');b=server['benchmark'];clients=load(case/'clients.json');old_path=historical.get((players,hz));old=load(old_path) if old_path else None
  r={'players':players,'configured_hz':hz,'achieved_hz':b['hz'],'passed':result['passed'],'mean_tick_ms':b['callback_us']['mean']/1000,'p95_tick_ms':b['callback_us']['p95']/1000,'p99_tick_ms':b['callback_us']['p99']/1000,'max_tick_ms':b['callback_us']['max']/1000,'p95_interval_ms':b['physics_interval_us']['p95']/1000,'max_interval_ms':b['physics_interval_us']['max']/1000,'cpu_one_core_percent':result['resource']['mean_cpu_one_core_percent'],'peak_rss_mib':result['resource']['peak_rss_mib'],'minimum_snapshot_hz':clients['minimum_steady_snapshot_hz'],'max_snapshot_gap_ms':clients['maximum_steady_snapshot_gap']*1000,'accepted_inputs':result['accepted_inputs'],'shots':sum(b['shots_by_class']),'payload_mbit_s':(server['bytes_sent']-b['baseline']['bytes_sent'])*8/b['seconds']/1e6,'old_mean_tick_ms':old['callback_us']['mean']/1000 if old else None,'old_p95_tick_ms':old['callback_us']['p95']/1000 if old else None}
  if old:
   if players==64 and hz==30:old_cpu=old_resource['mean_process_cpu_percent_one_core_100'];old_rss=old_resource['max_rss_mib']
   else:
    samples=load(old_path.with_name('resources.json'));old_cpu=(samples[-1]['cpu_seconds']-samples[0]['cpu_seconds'])/(samples[-1]['epoch']-samples[0]['epoch'])*100;old_rss=max(s['rss_mib'] for s in samples)
   r.update(old_cpu_one_core_percent=old_cpu,old_peak_rss_mib=old_rss,mean_tick_reduction_percent=100*(1-r['mean_tick_ms']/r['old_mean_tick_ms']))
  rows.append(r);details.append({'case':f'{players}/{hz}','historical_source':str(old_path.relative_to(ROOT)) if old else None,'shots_by_class':b['shots_by_class'],'phase_mean_ms':{k:b[k]['mean']/1000 for k in ['movement_us','combat_us','mode_us','encoding_us','jolt_update_us','publication_us']}})
 (out/'comparison.json').write_text(json.dumps({'cases':rows,'details':details},indent=2)+'\n')
 with (out/'comparison.csv').open('w',newline='') as f:
  w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
 print(json.dumps(rows,indent=2))
if __name__=='__main__':main()
