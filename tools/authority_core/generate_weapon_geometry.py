"""Generate native immutable CQ anchors from the same manifest used by clients."""
import argparse,json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
SLOTS=['burst_pistol','assault_rifle','pistol','smg','carbine','massacre','ammo_box','repair_kit','designator','scout_pistol','beam_pistol','guided_launcher','smg_t2','smg_t3','burst_rifle','energy_minigun','railgun']
def generated():
 m=json.loads((ROOT/'deathmatch/weapons/cq/manifest.json').read_text())
 lines=['#pragma once','#include "authority_math.h"','#include <array>','namespace cqauthority {','struct WeaponGeometry { V muzzle, magazine, rack, support; double zero_pitch; V sight; double zero_distance; V magazine_extract; };','inline const WeaponGeometry &cq_geometry(int slot) {',' static const std::array<WeaponGeometry,17> values{{']
 for key in SLOTS:
  fmt=lambda a:'{'+','.join(format(float(n),'.12g') for n in a)+'}'
  zero=math.atan2((m[key]['red_dot_position'][1]-m[key]['muzzle'][1])*.65,m[key].get('sight_zero_metres',50)) if m[key].get('sight_zero_metres') else 0
  lines.append('  {'+','.join(fmt(m[key][k]) for k in ['muzzle','magazine_anchor','rack_anchor','support_anchor'])+','+format(zero,'.12g')+','+fmt(m[key].get('red_dot_position',[0,.12,0]))+','+str(float(m[key].get('sight_zero_metres',50.)))+','+fmt(m[key].get('magazine_extract',[-1,0,0] if key in ['massacre','guided_launcher'] else [0,-1,0]))+'},')
 tip=[v*m['injector']['held_scale'] for v in m['injector']['muzzle']]
 return '\n'.join(lines+[' }};',' return values[slot >= 0 && slot < 17 ? slot : 2];','}', 'inline V cq_injector_tip() { return '+fmt(tip)+'; }','}'])+'\n'
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args();dest=ROOT/'addons/fps_native/src/authority_weapon_geometry.h'
 if a.check:
  if dest.read_text()!=generated():raise SystemExit('Native weapon geometry is stale')
  print('CQ client/native weapon anchors match')
 else:dest.write_text(generated())
