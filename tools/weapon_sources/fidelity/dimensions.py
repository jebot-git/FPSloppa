"""Read the runtime's held-weapon dimensions without duplicating its constants."""
import re,json
from pathlib import Path
ROOT=Path(__file__).resolve().parent

def anchors():
 rows=json.loads((ROOT/'bases/anchors.json').read_text())
 text=(ROOT.parents[2]/'deathmatch/weapons/fidelity/dimensions.gd').read_text()
 for key,xyz in re.findall(r'"([a-z0-9_]+)"\s*:\s*Vector3\(([^)]+)\)',text):
  rows[key]['muzzle']=[float(v.strip()) for v in xyz.split(',')]
 return rows
