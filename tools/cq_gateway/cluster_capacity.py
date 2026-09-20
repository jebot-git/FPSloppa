"""Planning arithmetic for a proposed sharded CQ service, NOT a cluster benchmark.

The command budget is an assumption to replace with measured quorum throughput.
No game configuration is changed and no servers are launched.
"""
import argparse
import json
import math
from pathlib import Path


def model(districts, gateway_size=4, free_slots=2, command_budget=5000,
          utilization=.5, crossing_seconds=60, burst_crossing_seconds=5,
          progress_hz=1, lease_hz=1, records_per_transfer=4,
          ingress_mbps=12, egress_mbps=4.57):
    def commands(d, seconds):
        return d * progress_hz + math.ceil(d / gateway_size) * lease_hz + 16 * d / seconds * records_per_transfer
    usable = command_budget * utilization
    def maximum(seconds):
        per_district = progress_hz + lease_hz / gateway_size + 16 / seconds * records_per_transfer
        candidate = math.floor(usable / per_district)
        while candidate > 0 and commands(candidate, seconds) > usable:
            candidate -= 1
        return candidate
    return dict(
        scope='Conditional planning model; no consensus, network, or game cluster execution.',
        assumptions=dict(gateway_size=gateway_size, free_slots=free_slots,
                         command_budget_per_second=command_budget, budget_utilization=utilization,
                         crossing_seconds=crossing_seconds, burst_crossing_seconds=burst_crossing_seconds,
                         progress_checkpoint_hz=progress_hz, regional_lease_hz=lease_hz,
                         committed_records_per_transfer=records_per_transfer,
                         private_mbps_per_full_district=ingress_mbps,
                         public_mbps_per_full_district=egress_mbps),
        rows=[dict(districts=d, full_active_slots=16*d,
                   deployment_target=(16-free_slots)*d,
                   gateway_shards=math.ceil(d/gateway_size),
                   private_aggregate_mbps=round(d*ingress_mbps, 2),
                   public_aggregate_mbps=round(d*egress_mbps, 2),
                   coordinator_commands_per_second=round(commands(d, crossing_seconds), 2),
                   burst_commands_per_second=round(commands(d, burst_crossing_seconds), 2),
                   normal_within_assumed_budget=commands(d, crossing_seconds)<=usable,
                   burst_within_assumed_budget=commands(d, burst_crossing_seconds)<=usable)
              for d in districts],
        conditional_control_only_district_ceiling=maximum(crossing_seconds),
        conditional_burst_control_only_district_ceiling=maximum(burst_crossing_seconds))


if __name__ == '__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--districts',type=int,nargs='+',default=[16,64,256,1024])
    p.add_argument('--gateway-size',type=int,default=4)
    p.add_argument('--free-slots',type=int,default=2)
    p.add_argument('--command-budget',type=float,default=5000)
    p.add_argument('--utilization',type=float,default=.5)
    p.add_argument('--crossing-seconds',type=float,default=60)
    p.add_argument('--burst-crossing-seconds',type=float,default=5)
    p.add_argument('--output',type=Path)
    a=p.parse_args()
    if any(d<1 for d in a.districts) or a.gateway_size<1 or not 0<=a.free_slots<16 or not 0<a.utilization<=1 or min(a.command_budget,a.crossing_seconds,a.burst_crossing_seconds)<=0:
        p.error('Positive counts/budgets/intervals, 0–15 spare slots and utilization in (0,1] are required.')
    report=model(a.districts,a.gateway_size,a.free_slots,a.command_budget,a.utilization,a.crossing_seconds,a.burst_crossing_seconds)
    text=json.dumps(report,indent=2)+'\n'
    if a.output:a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(text)
    print(text,end='')
