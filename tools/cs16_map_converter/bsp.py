"""Bounded GoldSrc BSP30/WAD3 reader and BSP29/BSPX writer (stdlib only)."""
import math
import re
import struct
from pathlib import Path

LIMIT = 25_000_000
SIZES = {1: 20, 3: 12, 5: 24, 6: 40, 7: 20, 9: 8, 10: 28, 11: 2, 12: 4, 13: 4, 14: 64}


class ConversionError(ValueError):
    pass


def require(ok, message):
    if not ok:
        raise ConversionError(message)


def bounded_read(path, limit=128_000_000):
    with Path(path).open('rb') as stream:
        data = stream.read(limit + 1)
    require(len(data) <= limit, f'{Path(path).name}: file exceeds {limit} bytes')
    return data


def vector(value):
    try:
        result = [float(v) for v in value.split()]
    except (ValueError, AttributeError) as exc:
        raise ConversionError('Invalid three-component coordinate') from exc
    require(len(result) == 3 and all(math.isfinite(v) and abs(v) <= 1_000_000 for v in result), 'Invalid coordinate')
    return result


def engine(p):
    return [-p[1] / 32, p[2] / 32, -p[0] / 32]


def parse_entities(data):
    # GoldSrc quoted strings do not interpret Windows WAD paths as escapes.
    text = data.rstrip(b'\0').decode('latin1')
    pattern = re.compile(r'\s+|//[^\n]*|"([^"\n\r]*)"|([{}])')
    tokens = []
    at = 0
    while at < len(text):
        match = pattern.match(text, at)
        require(match is not None, f'Malformed entity text at byte {at}')
        at = match.end()
        if match.group(1) is not None:
            tokens.append(('text', match.group(1)))
        elif match.group(2):
            tokens.append((match.group(2), ''))
    result = []
    i = 0
    while i < len(tokens):
        require(tokens[i][0] == '{', 'Expected entity opening brace')
        i += 1
        row = {}
        while i < len(tokens) and tokens[i][0] != '}':
            require(i + 1 < len(tokens) and tokens[i][0] == tokens[i+1][0] == 'text', 'Expected entity key/value')
            # Some compilers repeat identical editor keys (including classname).
            # Conflicting duplicates remain ambiguous and are rejected.
            require(tokens[i][1] not in row or row[tokens[i][1]] == tokens[i+1][1], 'Conflicting duplicate entity key: ' + tokens[i][1])
            row[tokens[i][1]] = tokens[i+1][1]
            i += 2
        require(i < len(tokens), 'Unterminated entity')
        i += 1
        require('classname' in row, 'Entity has no classname')
        result.append(row)
    require(result and result[0]['classname'] == 'worldspawn', 'First entity must be worldspawn')
    require(len(result) <= 8192, 'Too many entities')
    return result


def entity_bytes(rows):
    for row in rows:
        for key, value in row.items():
            require(not any(c in str(key) + str(value) for c in '\"\r\n\0'), 'Invalid output entity string')
    return ('\n'.join('{\n' + '\n'.join(f'"{k}" "{v}"' for k, v in row.items()) + '\n}' for row in rows) + '\n\0').encode('latin1')


class BSP:
    def __init__(self, raw, version=30):
        require(124 <= len(raw) <= 128_000_000, 'Invalid BSP file size')
        require(struct.unpack_from('<i', raw)[0] == version, f'Expected compiled GoldSrc BSP{version}; Source VBSP and RMF/MAP sources are not supported')
        self.lumps = []
        ranges = []
        for i in range(15):
            at, size = struct.unpack_from('<ii', raw, 4 + i * 8)
            require(at >= 0 and size >= 0 and at + size <= len(raw) and (size == 0 or at >= 124), f'Lump {i} outside BSP')
            if size:
                require(all(at + size <= lo or at >= hi for lo, hi in ranges), 'Overlapping BSP lumps')
                ranges.append((at, at + size))
            require(i not in SIZES or size % SIZES[i] == 0, f'Invalid record size in lump {i}')
            self.lumps.append(raw[at:at+size])
        require(len(self.lumps[0]) <= 2_000_000, 'Entity lump too large')
        require(0 < len(self.lumps[14]) <= 4096 * 64, 'Missing or excessive models')
        self.entities = parse_entities(self.lumps[0])
        self.vertices = list(struct.iter_unpack('<3f', self.lumps[3]))
        require(all(math.isfinite(v) and abs(v) <= 1_000_000 for p in self.vertices for v in p), 'Invalid vertex')
        self.edges = list(struct.iter_unpack('<2H', self.lumps[12]))
        require(all(v < len(self.vertices) for edge in self.edges for v in edge), 'Edge references missing vertex')
        self.surfedges = [r[0] for r in struct.iter_unpack('<i', self.lumps[13])]
        require(all(abs(e) < len(self.edges) for e in self.surfedges), 'Invalid surface edge')
        self.texinfo = list(struct.iter_unpack('<8fii', self.lumps[6]))
        require(all(math.isfinite(v) for row in self.texinfo for v in row[:8]), 'Non-finite texture coordinate')
        self.faces = list(struct.iter_unpack('<HHiHH4Bi', self.lumps[7]))
        self.planes = list(struct.iter_unpack('<4fi', self.lumps[1]))
        require(all(math.isfinite(v) for row in self.planes for v in row[:4]), 'Non-finite plane')
        self.models = list(struct.iter_unpack('<9f7i', self.lumps[14]))
        for model in self.models:
            require(all(math.isfinite(v) for v in model[:9]) and all(model[a] <= model[a+3] for a in range(3)), 'Invalid model bounds')
            require(-len(self.lumps[10])//28 <= model[9] < len(self.lumps[5])//24, 'Invalid model headnode')
            require(model[14] >= 0 and model[15] >= 0 and model[14] + model[15] <= len(self.faces), 'Invalid model faces')
        for face in self.faces:
            require(face[0] < len(self.planes) and face[2] >= 0 and 3 <= face[3] <= 4096 and face[2] + face[3] <= len(self.surfedges) and face[4] < len(self.texinfo), 'Invalid face references')
        # Validate graph references and reject cycles before engine recursion.
        for lump, fmt, children, leaf_count in [(5, '<i2h6h2H', (1, 2), len(self.lumps[10]) // 28), (9, '<i2h', (1, 2), None)]:
            nodes = list(struct.iter_unpack(fmt, self.lumps[lump]))
            for row in nodes:
                require(0 <= row[0] < len(self.planes), 'Node references missing plane')
                for c in children:
                    require(row[c] < len(nodes) and (row[c] >= 0 or leaf_count is None or -row[c]-1 < leaf_count), 'Invalid BSP tree child')
            done = set()
            active = set()
            for start in range(len(nodes)):
                stack = [(start, False)]
                while stack:
                    n, leaving = stack.pop()
                    if leaving:
                        active.remove(n); done.add(n); continue
                    if n in done: continue
                    require(n not in active, 'Cyclic BSP tree')
                    active.add(n); stack.append((n, True))
                    stack.extend((nodes[n][c], False) for c in children if nodes[n][c] >= 0)
        for index, e in enumerate(self.entities):
            for key in ['origin', 'angles']:
                if key in e: vector(e[key])
            if e.get('model', '').startswith('*'):
                require(e['model'][1:].isdigit() and 0 < int(e['model'][1:]) < len(self.models), f'Entity {index} references missing brush model')

    def solid(self, point):
        if not hasattr(self, '_solid_trees'):
            self._solid_nodes = list(struct.iter_unpack('<i2h6h2H', self.lumps[5]))
            self._leaf_contents = [row[0] for row in struct.iter_unpack('<ii6h2H4B', self.lumps[10])]
            self._solid_trees = [(self.models[0], [0, 0, 0])]
            for e in self.entities:
                if e['classname'] in ['func_wall', 'func_breakable', 'func_door_rotating'] and e.get('model', '').startswith('*'):
                    self._solid_trees.append((self.models[int(e['model'][1:])], vector(e.get('origin', '0 0 0'))))
        for model, offset in self._solid_trees:
            p = [point[a]-offset[a] for a in range(3)]
            node = model[9]
            require(node < len(self._solid_nodes), 'Invalid model headnode')
            while node >= 0:
                row = self._solid_nodes[node]; plane = self.planes[row[0]]
                side = sum(p[a]*plane[a] for a in range(3))-plane[3]
                node = row[1 if side >= 0 else 2]
            leaf = -node-1
            require(leaf < len(self._leaf_contents), 'Invalid model leaf')
            if self._leaf_contents[leaf] == -2: return True
        return False

    def standing_clear(self, point):
        # Candidate prefilter against compiled solid leaves. Runtime validation
        # still tests the actual capsule and imported surface collision.
        samples = [(0, 0, 2), (0, 0, 53)]
        samples += [(math.cos(i*math.pi/4)*9.6, math.sin(i*math.pi/4)*9.6, z)
                    for z in (12, 28, 44) for i in range(8)]
        return not any(self.solid([point[a]+sample[a] for a in range(3)]) for sample in samples)

    def polygon(self, face):
        return [self.vertices[self.edges[abs(e)][0 if e >= 0 else 1]] for e in self.surfedges[face[2]:face[2]+face[3]]]

    def floor_triangles(self):
        models = [(self.models[0], [0, 0, 0])]
        for e in self.entities:
            if e['classname'] in ['func_wall', 'func_breakable'] and e.get('model', '').startswith('*'):
                models.append((self.models[int(e['model'][1:])], vector(e.get('origin', '0 0 0'))))
        result = []
        for model, origin in models:
            for face in self.faces[model[14]:model[14]+model[15]]:
                normal = self.planes[face[0]][:3]
                if normal[2] * (-1 if face[1] else 1) < .65: continue
                poly = [tuple(v[a]+origin[a] for a in range(3)) for v in self.polygon(face)]
                result.extend((poly[0], poly[i], poly[i+1]) for i in range(1, len(poly)-1))
        return result


def floor_point(p, triangles, max_drop=128):
    highest = None
    for a, b, c in triangles:
        den = (b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
        if abs(den) < 1e-8: continue
        u = ((b[1]-c[1])*(p[0]-c[0])+(c[0]-b[0])*(p[1]-c[1]))/den
        v = ((c[1]-a[1])*(p[0]-c[0])+(a[0]-c[0])*(p[1]-c[1]))/den
        if min(u, v, 1-u-v) < -1e-5: continue
        z = a[2]*u+b[2]*v+c[2]*(1-u-v)
        if p[2]-max_drop <= z <= p[2]+.01 and (highest is None or z > highest): highest = z
    return [p[0], p[1], highest] if highest is not None else None


def pack(lumps, extensions):
    result = bytearray(124)
    struct.pack_into('<i', result, 0, 29)
    for i, data in enumerate(lumps):
        result.extend(bytes(-len(result) % 4))
        struct.pack_into('<ii', result, 4 + i*8, len(result), len(data))
        result.extend(data)
    result.extend(bytes(-len(result) % 4))
    header = len(result)
    result.extend(b'BSPX'+struct.pack('<I', len(extensions))+bytes(32*len(extensions)))
    for i, (name, data) in enumerate(extensions.items()):
        result.extend(bytes(-len(result) % 4))
        struct.pack_into('<24sII', result, header+8+32*i, name.encode('ascii'), len(result), len(data))
        result.extend(data)
    require(len(result) <= LIMIT, f'Converted BSP is {len(result):,} bytes; engine limit is {LIMIT:,}')
    return bytes(result)
