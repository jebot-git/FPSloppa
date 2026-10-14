"""Independent, deliberately restricted reference for horizontal sphere casts.

Certifies only scenes where the swept footprint is entirely above terrain,
no expanded box bounds intersect, and every remaining primitive is upright
cylinder geometry. Rejects unsupported cases instead of silently skipping them.
"""
import csv
import math
from pathlib import Path
import struct
from run import SHAPE, traces


def verify(world, trace_path, csv_path, index):
    query = traces(Path(trace_path))[index]
    trace_data = Path(trace_path).read_bytes()
    source = SHAPE.unpack_from(trace_data, 12+index*296)
    radius = source[9]
    if query['kind'] != 2 or query['delta'][1] != 0 or query['delta'][2] != 0 or query['delta'][0] >= 0:
        raise ValueError('Reference supports horizontal negative-X sphere casts only')
    data = Path(world).read_bytes()
    width, depth, spacing, ox, oy, oz, _, count = struct.unpack_from('<IId3dII', data, 8)
    x, y, z = query['start']
    dx = query['delta'][0]
    x0 = max(0, math.floor((x+dx-radius-ox)/spacing))
    x1 = min(width-1, math.ceil((x+radius-ox)/spacing))
    z0 = max(0, math.floor((z-radius-oz)/spacing))
    z1 = min(depth-1, math.ceil((z+radius-oz)/spacing))
    maximum = max(struct.unpack_from('<f', data, 56+4*(j*width+i))[0]+oy
                  for j in range(z0, z1+1) for i in range(x0, x1+1))
    if maximum >= y-radius:
        raise ValueError('Terrain cannot be excluded by height bounds')
    hits, grazes = [], []
    for i in range(count):
        shape = SHAPE.unpack_from(data, 56+width*depth*4+172*i)
        kind, identity, mask = shape[:3]
        if not mask & 1:
            continue
        p = [query['start'][j]-shape[3+j] for j in range(3)]
        if kind == 0:
            near, far = 0., 1.
            for axis in range(3):
                basis = shape[11+axis*3:14+axis*3]
                v = sum(p[j]*basis[j] for j in range(3))
                speed = dx*basis[0]
                extent = shape[6+axis]+radius+.0001
                if abs(speed) < 1e-14:
                    if abs(v) > extent:
                        near, far = 1., 0.
                        break
                else:
                    low, high = sorted(((-extent-v)/speed, (extent-v)/speed))
                    near, far = max(near, low), min(far, high)
            if near <= far:
                raise ValueError('Expanded box candidate requires another reference')
            continue
        if kind != 1 or abs(shape[15]-1) > 1e-7:
            raise ValueError('Unsupported remaining primitive')
        vertical = max(0., abs(p[1])-shape[10]/2)
        if vertical > radius:
            continue
        expanded = shape[9]+math.sqrt(radius*radius-vertical*vertical)
        discriminant = expanded*expanded-p[2]*p[2]
        if abs(discriminant) < .0001 and 0 < p[0] < -dx:
            grazes.append({'id': identity, 'clearance_m': abs(p[2])-expanded})
        if discriminant >= 0:
            fraction = max(0., (p[0]-math.sqrt(discriminant))/(-dx))
            exit_fraction = (p[0]+math.sqrt(discriminant))/(-dx)
            if 0 <= fraction <= 1 and exit_fraction >= 0:
                hits.append((fraction, identity))
    expected = min(hits)
    actual = list(csv.DictReader(Path(csv_path).open()))[index]
    error = abs(expected[0]-float(actual['fraction']))*abs(dx)
    return {'index': index, 'analytic_id': expected[1], 'analytic_fraction': expected[0],
            'native_id': int(actual['id']), 'native_fraction': float(actual['fraction']),
            'distance_error_m': error, 'terrain_maximum_m': maximum, 'sphere_bottom_m': y-radius,
            'box_candidates': 0, 'near_grazes': grazes,
            'pass': expected[1] == int(actual['id']) and error < .001}
