#!/usr/bin/env python3
"""UT99 vertex meshes + explicit skins -> bounded, script-free .utavatar.
Layout/axes follow UTAvatarConverter's MIT app/vertex_mesh.gd (FPSloppa contributors).
Requires numpy and Pillow. UnrealScript is parsed as metadata, never executed.
"""
import argparse, hashlib, json, math, struct, subprocess, tempfile
from pathlib import Path
import numpy as np
from PIL import Image

MAX_BYTES = 25_000_000

def write_avatar(output, positions, corners, skins, clips, title, author, license_name, reference=0, arm_profile=None, ik_data=None):
    positions = np.asarray(positions, dtype='<f4')
    frames, vertices, _ = positions.shape
    assert 3 <= vertices <= 4096 and 1 <= frames <= 4096 and frames * vertices <= 1_048_576
    assert len(corners) % 3 == 0 and 3 <= len(corners) <= 24_576
    slots = sorted({int(c[3]) for c in corners})
    if set(slots) != set(skins): raise ValueError(f'Assign every used skin slot explicitly: {slots}')
    cell = min(512, max(max(im.size) for im in skins.values()))
    cols = math.ceil(math.sqrt(len(slots))); rows = math.ceil(len(slots) / cols)
    if cols * cell > 2048 or rows * cell > 2048: raise ValueError('Skin atlas exceeds 2048 pixels')
    atlas = Image.new('RGBA', (cols * cell, rows * cell), (0, 0, 0, 255))
    slot_info = {}
    for i, slot in enumerate(slots):
        # Opaque stock player meshes; no skin-controlled alpha blend sorting.
        image = skins[slot].convert('RGB').convert('RGBA').resize((cell - 4, cell - 4), Image.Resampling.LANCZOS)
        x, y = i % cols * cell, i // cols * cell
        padded = np.pad(np.asarray(image), ((2, 2), (2, 2), (0, 0)), mode='edge')
        atlas.paste(Image.fromarray(padded), (x, y)); slot_info[slot] = (x, y)
    geometry = []
    for idx, u, v, slot in corners:
        x, y = slot_info[slot]
        geometry.append([int(idx), (x + 2.5 + u * (cell - 5)) / atlas.width, (y + 2.5 + v * (cell - 5)) / atlas.height])
    import io
    buffer = io.BytesIO(); atlas.save(buffer, format='PNG'); png = buffer.getvalue()
    width = 512; height = math.ceil(frames * vertices / width)
    texture = np.zeros((width * height, 4), dtype='<f4'); texture[:frames * vertices, :3] = positions.reshape((-1, 3))
    raw = texture.tobytes()
    low = positions.min(axis=(0, 1)); high = positions.max(axis=(0, 1))
    metadata = {'title': title, 'author': author, 'license': license_name, 'vertices': vertices, 'frames': frames,
                'width': width, 'height': height, 'position_bytes': len(raw), 'skin_bytes': len(png),
                'skin_width': atlas.width, 'skin_height': atlas.height, 'corners': geometry, 'clips': clips,
                'bounds': [*low.tolist(), *(high - low).tolist()], 'reference': reference, 'height_m': 1.7}
    if arm_profile:
        metadata['arm_profile'] = arm_profile
        metadata['arm_weights'] = arm_weights(positions[reference], arm_profile)
    if ik_data:
        metadata['ik_profile'], metadata['ik_weights'] = ik_data
    manifest = json.dumps(metadata, separators=(',', ':'), allow_nan=False).encode()
    total = 16 + len(manifest) + len(raw) + len(png)
    if total > MAX_BYTES: raise ValueError('Avatar exceeds 25 MB')
    data = struct.pack('<4sIII', b'UTAV', 1, total, len(manifest)) + manifest + raw + png
    output.parent.mkdir(parents=True, exist_ok=True); output.write_bytes(data)
    return {'path': str(output), 'hash': hashlib.sha256(data).hexdigest(), 'size': total, 'title': title, 'author': author, 'license': license_name, 'version': 'UT99 vertex 1', 'frames': frames, 'vertices': vertices, 'triangles': len(corners) // 3}

def arm_weights(points, profile):
    # Nearest capsule attribution follows the earlier converter's approximate
    # landmark method. Only arms are weighted; all other vertices remain native.
    out = []
    def nearest(point, start, end):
        delta = end - start
        t = max(0, min(1, float(np.dot(point-start, delta)/np.dot(delta,delta))))
        return float(np.linalg.norm(point-(start+t*delta))), t
    for point in points:
        best = (999, 0)
        if .77 < point[1] < 1.48:
            # Competing central torso capsule avoids weighting chest/neck.
            body, _ = nearest(point,np.array([0.,.88,0.]),np.array([0.,1.40,0.]))
            body = max(0, body - .15)
            for side, sign in [('left',1),('right',-1)]:
                shoulder, elbow, hand = [np.array(p) for p in profile[side]]
                upper, t = nearest(point,shoulder,elbow)
                fore, u = nearest(point,elbow,hand)
                distance = min(upper, fore)
                # Weight around the elbow with a smooth two-bone transition.
                amount = 1 + max(0, min(1,(1-point[1]+.20)/.16))
                if distance < body + .025 and distance < .14 and distance < best[0]:best=(distance,sign*amount)
        out.append(best[1])
    return out

def read_mesh(path, reference=None, yaw=180):
    if path.stat().st_size > 32_000_000: raise ValueError('Mesh too large')
    data = path.read_bytes(); base = str(path).removesuffix('_d.3d')
    anim_path = Path(base + '_a.3d')
    if anim_path.stat().st_size > 536_870_912: raise ValueError('Animation too large')
    anim = anim_path.read_bytes()
    if len(data) < 48 or len(anim) < 4: raise ValueError('Truncated .3d')
    faces, vertices = struct.unpack_from('<HH', data); frames, stride = struct.unpack_from('<HH', anim)
    if not (3 <= vertices <= 4096 and 1 <= frames <= 4096 and vertices * frames <= 1_048_576 and 1 <= faces <= 8192): raise ValueError('Geometry limits exceeded')
    if stride != vertices * 4 or len(data) != 48 + faces * 16 or len(anim) != 4 + frames * stride: raise ValueError('Malformed .3d layout')
    import re
    scale = np.ones(3); origin = np.zeros(3); rotation = np.zeros(3); clips = []
    script = Path(base + '.uc')
    if script.exists():
        if script.stat().st_size > 1_000_000: raise ValueError('Metadata too large')
        for line in script.read_text(errors='replace').splitlines():
            fields = {k.upper(): float(v) for k, v in re.findall(r'(\w+)=([-+0-9.eE]+)', line)}
            if line.startswith('#exec MESHMAP SCALE'): scale = np.array([fields.get(k, 1) for k in ('X', 'Y', 'Z')])
            if line.startswith('#exec MESH ORIGIN'):
                origin = np.array([fields.get(k, 0) for k in ('X', 'Y', 'Z')])
                rotation = np.array([fields.get(k, 0) for k in ('ROLL', 'PITCH', 'YAW')]) * math.tau / 256
            if line.startswith('#exec MESH SEQUENCE'):
                name = re.search(r'SEQ=(\S+)', line)
                if name:
                    start, count = int(fields.get('STARTFRAME', 0)), int(fields.get('NUMFRAMES', 1))
                    if start < 0 or count < 1 or start + count > frames: raise ValueError('Sequence outside animation')
                    clips.append({'name': name[1][:60], 'start': start, 'count': count, 'fps': max(1, min(60, fields.get('RATE', 15)))})
    if not np.isfinite(scale).all() or (scale <= 0).any() or not np.isfinite(origin).all() or not np.isfinite(rotation).all(): raise ValueError('Invalid scale/origin')
    def matrix(axis, angle):
        c, s = math.cos(angle), math.sin(angle)
        if axis == 0: return np.array([[1,0,0],[0,c,-s],[0,s,c]])
        if axis == 1: return np.array([[c,0,s],[0,1,0],[-s,0,c]])
        return np.array([[c,-s,0],[s,c,0],[0,0,1]])
    unreal = matrix(2, rotation[2]) @ matrix(1, -rotation[1]) @ matrix(0, rotation[0])
    packed = np.frombuffer(anim, dtype='<u4', offset=4).reshape((frames, vertices))
    x = (packed & 2047).astype(np.int32); x[x >= 1024] -= 2048
    y = ((packed >> 11) & 2047).astype(np.int32); y[y >= 1024] -= 2048
    z = ((packed >> 22) & 1023).astype(np.int32); z[z >= 512] -= 1024
    source = ((np.stack((x,y,z), axis=-1) - origin) * scale) @ unreal.T
    points = np.stack((-source[:,:,1], source[:,:,2], source[:,:,0]), axis=-1) @ matrix(1, math.radians(yaw)).T
    if reference is None: reference = 609 if Path(base).name in ('SGirl', 'FCommando') and frames > 609 else 0
    if not 0 <= reference < frames: raise ValueError('Invalid reference frame')
    low, high = points[reference].min(axis=0), points[reference].max(axis=0)
    if high[1] - low[1] < .00001: raise ValueError('Reference frame has no height')
    points = (points - np.array([(low[0]+high[0])/2, low[1], (low[2]+high[2])/2])) * (1.7 / (high[1]-low[1]))
    if not np.isfinite(points).all() or np.abs(points).max() > 10: raise ValueError('Animated vertices outside 10 metre limit')
    corners = []
    for i in range(faces):
        at = 48 + i * 16
        for j in (0, 2, 1):
            idx = struct.unpack_from('<H', data, at + j*2)[0]
            if idx >= vertices: raise ValueError('Triangle index out of bounds')
            corners.append((idx, data[at+8+j*2]/255, data[at+9+j*2]/255, data[at+14]))
    return points, corners, clips or [{'name': 'All', 'start': 0, 'count': frames, 'fps': 15}], reference

def extract(args, work):
    checkout = args.converter.resolve()
    if not (checkout/'app/project.godot').exists(): raise ValueError('Provide previous UTAvatarConverter checkout with --converter')
    def job(action, **fields):
        path = work / (action + '.json'); result = work / (action + '-result.json')
        payload = dict(action=action, work=str(work), result=str(result), **fields); path.write_text(json.dumps(payload))
        subprocess.run([args.godot, '--headless', '--path', str(checkout/'app'), '--', '--job', str(path)], check=True, timeout=180, stdout=subprocess.DEVNULL)
        value = json.loads(result.read_text())
        if 'error' in value: raise ValueError(value['error'])
        return value
    catalog = job('catalog', input=str(args.package.resolve()))
    choices = [m for m in catalog['models'] if m['name'].lower() == args.model.lower()]
    if len(choices) != 1: raise ValueError('Select one mesh by --model: ' + ', '.join(m['name'] for m in catalog['models']))
    result = job('extract', model=choices[0], source=str(args.package.resolve()), skin=str(args.skin_package.resolve()) if args.skin_package else '')
    return Path(result['mesh']), result['textures']

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--mesh', type=Path); p.add_argument('--package', type=Path); p.add_argument('--model'); p.add_argument('--skin-package', type=Path)
    p.add_argument('--converter', type=Path); p.add_argument('--godot', default='godot')
    p.add_argument('--slot', action='append', default=[], help='slot=/absolute/texture.png (or filename from extraction)')
    p.add_argument('--arm-profile', type=Path, help='JSON left/right shoulder, elbow, hand positions in normalized metres'); p.add_argument('--reference', type=int); p.add_argument('--yaw', type=float, default=180)
    p.add_argument('--output', required=True, type=Path); p.add_argument('--title'); p.add_argument('--author', default='Unknown'); p.add_argument('--license', default='User supplied; verify source rights')
    args = p.parse_args()
    with tempfile.TemporaryDirectory(prefix='ut99-avatar-') as temporary:
        textures = []; mesh = args.mesh
        if args.package:
            if not args.converter or not args.model: p.error('--package requires --converter and --model')
            mesh, textures = extract(args, Path(temporary))
        if not mesh: p.error('Provide --mesh or --package')
        skins = {}
        for value in args.slot:
            slot, name = value.split('=', 1); path = Path(name)
            if not path.exists():
                found = [Path(f) for f in textures if Path(f).name.lower() == name.lower()]
                if len(found) != 1: raise ValueError('Ambiguous or missing skin: ' + name)
                path = found[0]
            with Image.open(path) as image:
                if image.width * image.height > 4_194_304: raise ValueError('Source texture too large')
                skins[int(slot)] = image.copy()
        positions, corners, clips, reference = read_mesh(mesh, args.reference, args.yaw)
        print(json.dumps(write_avatar(args.output, positions, corners, skins, clips, args.title or mesh.name.removesuffix('_d.3d'), args.author, args.license, reference, json.loads(args.arm_profile.read_text()) if args.arm_profile else None), indent=2))
if __name__ == '__main__': main()
