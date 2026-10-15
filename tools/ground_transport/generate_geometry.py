"""Generate native transport anchors from the Blender-authored runtime manifest."""
import json,argparse
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def generated():
 d=json.loads((ROOT/'deathmatch/models/ground_transport/manifest.json').read_text())
 def vec(v):return '{'+','.join(format(float(x),'.12g') for x in v)+'}'
 lines=['#pragma once','#include "authority_cq.h"','namespace cqauthority {','inline const V transport_size='+vec(d['size'])+';','inline constexpr double transport_entry_radius='+str(d['entry_radius'])+';','struct TransportPod { V entry, seat; };','inline const std::array<TransportPod,8> transport_pods{{']
 lines+=[' {'+vec(r['entry'])+','+vec(r['seat'])+'},' for r in d['seats']]
 lines+=['}};','inline V transport_seat(const Vehicle &v, int seat) {',' return V{v.position.x,v.visual_y,v.position.z}+vehicle_basis(v).apply(transport_pods[size_t(seat)].seat);','}','}']
 return '\n'.join(lines)+'\n'
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args();dest=ROOT/'addons/fps_native/src/authority_transport_geometry.h';value=generated()
 if a.check:
  if dest.read_text()!=value:raise SystemExit('Transport native anchors are stale')
 else:dest.write_text(value)
 print('Transport client/native geometry matches')
