"""Keep the native bike geometry identical to the Blender-authored client manifest."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[2]
m=json.loads((root/'deathmatch/models/desert_bike/manifest.json').read_text())
v=lambda a:'{'+','.join(str(float(x)) for x in a)+'}'
(root/'addons/fps_native/src/authority_bike_geometry.h').write_text('#pragma once\n#include "authority_cq.h"\nnamespace cqauthority {\ninline const V bike_size='+v(m['size'])+';\ninline const V bike_seat_anchor='+v(m['seat'])+';\ninline V bike_seat(const Vehicle &v) { return V{v.position.x,v.visual_y,v.position.z}+vehicle_basis(v).apply(bike_seat_anchor); }\n}\n')
