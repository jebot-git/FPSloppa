"""Resolve only explicitly supplied local WADs; preserve indexed art and palettes."""
import struct
import hashlib
from pathlib import Path
from bsp import bounded_read, require


def name16(raw):
    name = raw.split(b'\0', 1)[0].decode('ascii', 'strict')
    require(name and not any(c in name for c in '/\\') and '..' not in name, 'Invalid texture name')
    return name.lower()


class Wads:
    def __init__(self, paths):
        self.entries = {}
        self.sources = []
        self.used = set()
        self.duplicates = set()
        for path in paths:
            path = Path(path)
            data = bounded_read(path, 256_000_000)
            self.sources.append({'name': path.name, 'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data)})
            require(len(data) >= 12 and data[:4] == b'WAD3', f'{path.name}: expected WAD3')
            count, directory = struct.unpack_from('<ii', data, 4)
            require(0 <= count <= 16384 and directory >= 12 and directory + count*32 <= len(data), 'Invalid WAD directory')
            for i in range(count):
                at, size, unpacked, kind, compressed, _, raw_name = struct.unpack_from('<iiiBBH16s', data, directory+i*32)
                require(at >= 12 and size >= 0 and at+size <= len(data), 'WAD entry outside file')
                if kind != 0x43: continue
                require(compressed == 0 and size == unpacked, 'Compressed WAD entries are unsupported')
                name = name16(raw_name)
                if name in self.entries:
                    self.duplicates.add(name); continue
                self.entries[name] = (data[at:at+size], path.name)


def texture(data):
    require(len(data) >= 40, 'Truncated miptex')
    name = name16(data[:16])
    width, height, *offsets = struct.unpack_from('<6I', data, 16)
    require(16 <= width <= 2048 and 16 <= height <= 2048 and width % 16 == height % 16 == 0, f'{name}: invalid GoldSrc texture dimensions')
    if offsets == [0]*4: return name, width, height, None, None
    pixels = []
    end = 40
    for i, offset in enumerate(offsets):
        size = (width >> i)*(height >> i)
        require(offset >= end and offset+size <= len(data), f'{name}: missing/overlapping mip pixels')
        pixels.append(data[offset:offset+size]); end = offset+size
    require(end+770 <= len(data) and struct.unpack_from('<H', data, end)[0] == 256, f'{name}: missing 256-colour palette')
    return name, width, height, pixels, data[end+2:end+770]


def records(lump, unused_slots=()):
    require(len(lump) >= 4, 'Missing texture table')
    count = struct.unpack_from('<i', lump)[0]
    require(0 < count <= 2048 and 4+count*4 <= len(lump), 'Invalid texture table')
    starts = list(struct.unpack_from('<'+str(count)+'i', lump, 4))
    require(all(4+count*4 <= p <= len(lump)-40 or p == -1 and i in unused_slots for i,p in enumerate(starts)), 'Missing/invalid texture slot; supply a complete compiled CS map')
    present=[p for p in starts if p>=0]
    require(len(set(present)) == len(present), 'Duplicate texture record offsets')
    limits = {p: q for p, q in zip(sorted(present), sorted(present)[1:]+[len(lump)])}
    return [texture(lump[p:limits[p]]) if p>=0 else ('__unused_'+str(i),16,16,None,None) for i,p in enumerate(starts)]


def convert(lump, wads, replace_missing=False, rules=None, unused_slots=()):
    rows = records(lump, unused_slots)
    holes={i for i in unused_slots if struct.unpack_from('<i',lump,4+i*4)[0]==-1}
    count = len(rows)
    rules = rules or {}
    from replacements import COLOURS, generate
    require(isinstance(rules, dict) and all(isinstance(k, str) and v in COLOURS for k,v in rules.items()), 'Texture rules must map exact texture names to replacement categories')
    missing = [name for i,(name, _, _, mips, _) in enumerate(rows) if i not in holes and mips is None and name not in wads.entries]
    require(replace_missing or not missing, 'Missing textures ('+str(len(missing))+'): '+', '.join(missing)+'; provide WADs with --wad/--wad-dir or explicitly use --replace-missing')
    table = bytearray(struct.pack('<I', count)+bytes(count*4))
    palettes = bytearray(struct.pack('<II', 1, count))
    reports = []
    total = 0
    for i, (name, width, height, mips, palette) in enumerate(rows):
        source = 'embedded'
        resized = None
        if mips is None and name in wads.entries:
            raw, source = wads.entries[name]
            found, w, h, mips, palette = texture(raw)
            require(found == name and mips is not None, f'{name}: WAD texture differs from BSP name or lacks pixels')
            if (w, h) != (width, height):
                # Preserve the compiled texture dimensions/UV scale, using the
                # supplied art even when a WAD revision changed its resolution.
                resized = [w, h]
                mips = [bytes(pixels[(y*(h>>level)//(height>>level))*(w>>level)+x*(w>>level)//(width>>level)]
                              for y in range(height>>level) for x in range(width>>level))
                        for level, pixels in enumerate(mips)]
            wads.used.add(source)
        total += width*height
        require(total <= 33_554_432, 'Map textures exceed engine 32-megapixel budget')
        if mips is None:
            mips, palette, replacement = generate(name, width, height, rules.get(name))
            source = 'unused-slot' if i in holes else 'generated:'+replacement
        target = 'skip' if i in holes or name in ['aaatrigger', 'null', 'hint', 'origin', 'clip'] else '*'+name[1:] if name.startswith('!') else name
        tile = bytearray(struct.pack('<16s6I', target.encode(), width, height, 0, 0, 0, 0))
        for mip, pixels in enumerate(mips):
            struct.pack_into('<I', tile, 24+mip*4, len(tile)); tile.extend(pixels)
        struct.pack_into('<I', table, 4+i*4, len(table)); table.extend(tile); palettes.extend(palette)
        reports.append({'name': name, 'output_name': target, 'width': width, 'height': height, 'source': source, **({'resampled_from': resized} if resized else {})})
    return bytes(table), bytes(palettes), reports
