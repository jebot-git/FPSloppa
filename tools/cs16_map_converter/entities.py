"""Translate CS team/objective entities into FPSloppa's DE layout contract."""
import math
from bsp import engine, floor_point, require, vector


def number(value):
    result = float(value)
    require(math.isfinite(result), 'Non-finite entity number')
    return result


def yaw(e):
    return vector(e['angles'])[1] if 'angles' in e else number(e.get('angle', '0'))


def origin(p):
    return ' '.join(f'{v:.6f}' for v in p)


def site_box(bsp, index):
    e = bsp.entities[index]
    require(e['classname'] == 'func_bomb_target' and e.get('model', '').startswith('*'),
            'Point bomb targets need explicit min/max bounds in --sites')
    model = bsp.models[int(e['model'][1:])]
    offset = vector(e.get('origin', '0 0 0'))
    return ([model[a]+offset[a] for a in range(3)], [model[a+3]+offset[a] for a in range(3)])


def site_groups(bsp, sites):
    # CS maps can assemble one irregular plant region from several touching
    # trigger entities. Preserve each box: their union AABB would allow plants
    # in the gaps. Never group separated sites just because they fire one target.
    require(1 <= len(sites) <= 64, 'Expected 1–64 bomb target volumes')
    groups = [[i] for i, _ in sites]
    if len(groups) <= 2 or any(e['classname'] != 'func_bomb_target' for _, e in sites):
        return groups
    boxes = {i: site_box(bsp, i) for i, _ in sites}
    def touches(a, b):
        lo, hi = boxes[a]; other_lo, other_hi = boxes[b]
        return all(lo[k] <= other_hi[k]+2 and other_lo[k] <= hi[k]+2 for k in range(3))
    changed = True
    while changed:
        changed = False
        for i in range(len(groups)):
            for j in range(i+1, len(groups)):
                if any(touches(a, b) for a in groups[i] for b in groups[j]):
                    groups[i].extend(groups.pop(j)); changed = True; break
            if changed: break
    return [sorted(group) for group in groups]


def native_box(lo, hi):
    a, b = engine(lo), engine(hi)
    return {'min': [min(a[i], b[i]) for i in range(3)], 'max': [max(a[i], b[i]) for i in range(3)]}


def convert(bsp, title, config=None):
    warnings = []
    changes = []
    triangles = bsp.floor_triangles()
    starts = [[], []]
    yaws = [[], []]
    result = [{'classname': 'worldspawn', 'message': title, '_fpsloppa_bake': '1', '_fpsloppa_atlas': '4096'}]
    sites = [(i, e) for i, e in enumerate(bsp.entities) if e['classname'] in ['func_bomb_target', 'info_bomb_target']]
    if config is None:
        groups = site_groups(bsp, sites)
        require(len(groups) == 2, f'Found {len(sites)} bomb targets in {len(groups)} separate groups; supply --sites JSON selecting A and B explicitly')
        config = {label: {'entities': groups[i]} for i, label in enumerate(['A', 'B'])}
        warnings.append('A/B labels follow bomb-target entity order; inspect positions or supply --sites to match the painted labels.')
        if len(sites) > 2:
            warnings.append('Touching bomb-target brushes were grouped into two sites; separate plant volumes are retained. Verify the grouping.')
    require(isinstance(config, dict) and set(config) == {'A', 'B'}, '--sites requires A and B objects')
    points = []
    bounds = []
    volumes = []
    selected = []
    for label in ['A', 'B']:
        row = config[label]
        require(isinstance(row, dict), 'Each site needs an object')
        require(not ('entity' in row and 'entities' in row), 'Use entity or entities, not both')
        indices = row.get('entities', [row.get('entity')])
        require(isinstance(indices, list) and 1 <= len(indices) <= 64 and all(type(i) is int for i in indices), 'Each site needs entity or a list of entity indices')
        require(('min' in row) == ('max' in row), 'Site bounds require both min and max')
        require(not ('min' in row and len(indices) != 1), 'Bounds override requires a single site entity')
        boxes = []
        for index in indices:
            require(0 <= index < len(bsp.entities) and index not in selected, 'Invalid or repeated bomb-target index')
            e = bsp.entities[index]
            require(e['classname'] in ['func_bomb_target', 'info_bomb_target'], 'Site index is not a CS bomb target')
            selected.append(index)
            if 'min' in row:
                lo, hi = vector(origin(row['min'])), vector(origin(row['max']))
            else:
                lo, hi = site_box(bsp, index)
            require(all(lo[a] < hi[a] for a in range(3)), 'Empty bomb-site bounds')
            boxes.append((lo, hi))
            changes.append({'entity': index, 'from': e['classname'], 'to': 'DE site '+label})
        point = None
        if 'point' in row:
            p = vector(origin(row['point']))
            point = floor_point([p[0], p[1], p[2]+8], triangles, 16)
        else:
            # Largest brush first; never choose the centre of an empty union.
            for lo, hi in sorted(boxes, key=lambda box: math.prod(box[1][a]-box[0][a] for a in range(3)), reverse=True):
                for u, v in [(0.5, 0.5), (.3, .3), (.7, .7), (.3, .7), (.7, .3), (.5, .2), (.5, .8), (.2, .5), (.8, .5)]:
                    candidate = [lo[0]+u*(hi[0]-lo[0]), lo[1]+v*(hi[1]-lo[1]), min(hi[2], lo[2]+64)]
                    p = floor_point(candidate, triangles, hi[2]-lo[2]+64)
                    if p is not None and p[2] >= lo[2]-8 and bsp.standing_clear(p):
                        point = p; break
                if point is not None: break
        require(point is not None, f'Site {label} has no walkable floor near its centre; set point in --sites')
        require(any(all(lo[a]-8 <= point[a] <= hi[a]+.01 for a in range(3)) for lo, hi in boxes), f'Site {label} point lies outside its bounds')
        native = []
        for lo, hi in boxes:
            # A trigger usually rests slightly above the floor; keep the small
            # same allowance on every component, including narrow site wings.
            lo[2] -= 2
            if all(lo[a] <= point[a] <= hi[a] for a in (0,1)) and point[2] >= lo[2]-6:
                lo[2] = min(lo[2], point[2]-2)
            native.append(native_box(lo, hi))
        ep = engine(point); ep[1] += .05
        points.append(ep); volumes.append(native)
        bounds.append({'min': [min(box['min'][a] for box in native) for a in range(3)], 'max': [max(box['max'][a] for box in native) for a in range(3)]})

    keep = {'func_wall', 'func_door', 'func_button', 'trigger_hurt', 'trigger_multiple', 'trigger_once', 'trigger_relay', 'trigger_counter'}
    harmless = {'worldspawn', 'func_bomb_target', 'info_bomb_target', 'func_buyzone', 'info_map_parameters', 'info_intermission', 'light', 'light_spot', 'light_environment', 'env_light'}
    for i, e in enumerate(bsp.entities[1:], 1):
        kind = e['classname']
        if kind in ['info_player_deathmatch', 'info_player_start']:
            role = 0 if kind == 'info_player_deathmatch' else 1
            p = floor_point(vector(e.get('origin', '')), triangles)
            require(p is not None, f'Spawn entity {i} has no walkable floor within 128 units')
            ep = engine(p); ep[1] += .05
            if ep in starts[role]: continue
            starts[role].append(ep); yaws[role].append(math.radians(yaw(e)))
            spawn = p.copy(); spawn[2] += 24.0  # Native runtime subtracts .70 m: leaves .05 m clearance.
            result.append({'classname': 'info_player_team'+str(role+1), 'origin': origin(spawn), 'angle': str(yaw(e))})
            changes.append({'entity': i, 'from': kind, 'to': 'T spawn' if role == 0 else 'CT spawn'})
            continue
        if kind in harmless: continue
        if kind not in keep:
            if e.get('model', '').startswith('*') and not kind.startswith('trigger_') and kind not in ['func_ladder', 'func_illusionary', 'func_water']:
                result.append({'classname': 'func_wall', 'model': e['model'], 'origin': e.get('origin', '0 0 0')})
                warnings.append(f'Entity {i} {kind}: preserved as static solid cover; its original behaviour is unsupported.')
            else:
                warnings.append(f'Entity {i} {kind}: omitted (unsupported logic, ladder, non-solid decoration or external model/sound).')
            continue
        row = {k: v for k, v in e.items() if k in {'classname', 'model', 'origin', 'target', 'targetname', 'killtarget', 'wait', 'delay', 'speed', 'lip', 'dmg', 'health', 'count'}}
        flags = int(number(e.get('spawnflags', '0')))
        row['spawnflags'] = '0'  # GoldSrc flags must never become Quake NOT_DEATHMATCH/key flags.
        if kind in ['func_door', 'func_button']:
            row['angle'] = str(yaw(e))
            if kind == 'func_door':
                row['_de_reset'] = '1'
                row['spawnflags'] = str((flags & 1) | (flags & 32) | 4)
                row['speed'] = e.get('speed', '100'); row['wait'] = e.get('wait', '3')
                if flags & 256:
                    warnings.append(f'Entity {i} func_door: use-only activation adapted to proximity/touch; targeted doors retain their trigger.')
            else:
                warnings.append(f'Entity {i} func_button: adapted to native touch/shoot button activation.')
        for key in ['wait', 'delay', 'speed', 'lip', 'dmg', 'health', 'count']:
            if key in row: number(row[key])
        if int(number(e.get('rendermode', '0'))) != 0:
            warnings.append(f'Entity {i} {kind}: blend/render amount is not reproduced; cutout textures retain index-255 transparency.')
        if e.get('master'):
            warnings.append(f'Entity {i} {kind}: master lock is unsupported.')
        result.append(row)
    require(all(1 <= len(rows) <= 64 for rows in starts), 'Both T and CT need 1–64 distinct valid spawns')
    layout = {'version': 1, 'sites': points, 'bounds': bounds, 'volumes': volumes, 'starts': starts, 'yaw': [r[0] for r in yaws], 'start_yaws': yaws}
    return result, layout, changes, warnings
