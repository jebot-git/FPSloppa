"""Repack relit samples by original face/style order without changing map data."""
import math
import re
import struct
from tools.makkon.theme import lumps, repack


def face_samples(parts, at):
    _, _, first, count, texinfo = struct.unpack_from('<HHiHH', parts[7], at)
    tex = struct.unpack_from('<8f', parts[6], texinfo*40)
    coords = []
    for index in range(first, first+count):
        edge = struct.unpack_from('<i', parts[13], index*4)[0]
        vertex = struct.unpack_from('<HH', parts[12], abs(edge)*4)[0 if edge >= 0 else 1]
        point = struct.unpack_from('<3f', parts[3], vertex*12)
        coords.append([sum(point[k]*tex[d*4+k] for k in range(3))+tex[d*4+3] for d in range(2)])
    width, height = [math.ceil(max(v[d] for v in coords)/16)-math.floor(min(v[d] for v in coords)/16)+1 for d in range(2)]
    return width*height


def preserve(original, candidate):
    before, bx = lumps(original)
    after, ax = lumps(candidate)
    def entities(data):
        return [dict(re.findall(rb'"([^"\n]*)"\s*"([^"\n]*)"', entity))
                for entity in re.findall(rb'\{([^{}]*)\}', data)]
    assert entities(before[0]) == entities(after[0]), 'Gameplay entities changed'
    for i in range(15):
        if i not in (0, 7, 8):
            assert before[i] == after[i], f'Non-lighting lump changed: {i}'
    assert len(before[7]) == len(after[7])
    original_rgb = dict(bx)[b'RGBLIGHTING'.ljust(24, b'\0')]
    candidate_rgb = dict(ax)[b'RGBLIGHTING'.ljust(24, b'\0')]
    faces = bytearray(before[7])
    gray, rgb = bytearray(), bytearray()
    kept_styles = 0
    for at in range(0, len(faces), 20):
        assert before[7][at:at+12] == after[7][at:at+12], 'Face geometry changed'
        original_offset = struct.unpack_from('<i', faces, at+16)[0]
        if original_offset < 0:
            continue
        count = face_samples(before, at)
        original_styles = list(faces[at+12:at+16])
        candidate_styles = list(after[7][at+12:at+16])
        candidate_offset = struct.unpack_from('<i', after[7], at+16)[0]
        padding = (-len(gray)) % 4
        gray.extend(bytes(padding));rgb.extend(bytes(padding*3))
        struct.pack_into('<i', faces, at+16, len(gray))
        for slot, style in enumerate(original_styles):
            if style == 255:
                break
            if candidate_offset >= 0 and style in candidate_styles:
                start = candidate_offset + candidate_styles.index(style)*count
                samples, colors = after[8], candidate_rgb
            else:
                # The compiler may prune a dim styled contribution. Keep its
                # authored data rather than removing/reassigning the style.
                start = original_offset + slot*count
                samples, colors = before[8], original_rgb
                kept_styles += 1
            assert 0 <= start <= start+count <= len(samples)
            assert (start+count)*3 <= len(colors)
            gray.extend(samples[start:start+count])
            rgb.extend(colors[start*3:(start+count)*3])
    parts = before.copy();parts[7] = bytes(faces);parts[8] = bytes(gray)
    extras = [(key, bytes(rgb) if key.rstrip(b'\0') == b'RGBLIGHTING' else value) for key, value in bx]
    return repack(parts, extras), {'preserved_pruned_style_blocks': kept_styles,
                                  'sample_bytes': len(gray), 'rgb_bytes': len(rgb)}
