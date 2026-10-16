"""Compare snapshot optimisation to the preceding same-VPS standalone matrix."""
import argparse,csv,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def read(p):return json.loads(p.read_text())
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('results',type=Path);p.add_argument('--baseline',type=Path,default=ROOT/'docs/validation/voxel-battle/standalone-capacity-20261016');a=p.parse_args();rows=[]
 for case in read(a.results/'matrix.json'):
  name=f"{case['players']}-{case['configured_hz']}";s=read(a.results/name/'server.json');b=s['benchmark'];previous=read(a.baseline/name/'server.json');old=previous['benchmark'];base=read(a.baseline/name/'summary.json');c=read(a.results/name/'clients.json')
  mbps=(s['bytes_sent']-b['baseline']['bytes_sent'])*8/b['seconds']/1e6;old_mbps=(previous['bytes_sent']-old['baseline']['bytes_sent'])*8/old['seconds']/1e6
  d={'players':case['players'],'configured_hz':case['configured_hz'],'passed':case['passed'],'actual_hz':b['hz'],'before_payload_mbit_s':old_mbps,'after_payload_mbit_s':mbps,'payload_reduction_percent':100*(1-mbps/old_mbps),'before_mean_tick_ms':old['callback_us']['mean']/1000,'after_mean_tick_ms':b['callback_us']['mean']/1000,'before_p95_tick_ms':old['callback_us']['p95']/1000,'after_p95_tick_ms':b['callback_us']['p95']/1000,'after_max_tick_ms':b['callback_us']['max']/1000,'before_cpu_one_core_percent':base['resource']['mean_cpu_one_core_percent'],'after_cpu_one_core_percent':case['resource']['mean_cpu_one_core_percent'],'before_peak_rss_mib':base['resource']['peak_rss_mib'],'after_peak_rss_mib':case['resource']['peak_rss_mib'],'minimum_snapshot_hz':c['minimum_steady_snapshot_hz'],'max_snapshot_gap_ms':c['maximum_steady_snapshot_gap']*1000,'shots_by_class':b['shots_by_class']}
  for metric in ['snapshot_source_bytes','snapshot_relevant_bytes','snapshot_packed_bytes','snapshot_deltas','snapshot_keyframes','snapshot_budget_fallbacks','snapshot_shared_population_frames']:d[metric]=s[metric]-b['baseline'][metric]
  rows.append(d)
 (a.results/'comparison.json').write_text(json.dumps(rows,indent=2)+'\n')
 with (a.results/'comparison.csv').open('w',newline='') as f:
  w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
 print(json.dumps(rows,indent=2))
if __name__=='__main__':main()
