"""Read exported Godot scalar settings without executing serialized objects."""
import struct


def exported_scalars(data):
    assert data[:4] == b'ECFG', 'Invalid Godot project settings'
    count, = struct.unpack_from('<I', data, 4)
    offset = 8
    result = {}
    for _ in range(count):
        length, = struct.unpack_from('<I', data, offset); offset += 4
        name = data[offset:offset+length].decode(); offset += length
        length, = struct.unpack_from('<I', data, offset); offset += 4
        value = data[offset:offset+length]; offset += length
        kind, = struct.unpack_from('<I', value)
        if kind == 1:
            result[name] = bool(struct.unpack_from('<I', value, 4)[0])
        elif kind == 4:
            size, = struct.unpack_from('<I', value, 4)
            result[name] = value[8:8+size].decode()
    assert offset == len(data)
    return result


def verify_android_renderer(archive):
    values = exported_scalars(archive.read('assets/project.binary'))
    assert values.get('rendering/renderer/rendering_method') == 'mobile'
    assert values.get('rendering/renderer/rendering_method.mobile', 'mobile') == 'mobile'
    assert values.get('rendering/rendering_device/driver.android', 'vulkan') == 'vulkan'
    assert values.get('rendering/rendering_device/fallback_to_opengl3', True) is False
    import zipfile
    template = require_client_template('android')
    with zipfile.ZipFile(template) as aar:
        expected = aar.read('jni/arm64-v8a/libgodot_android.so')
    assert archive.read('lib/arm64-v8a/libgodot_android.so') == expected, 'APK has an unverified engine runtime'
    return {'opengl_compiled': False, 'method': 'mobile', 'android_driver': 'vulkan', 'opengl_fallback': False}


def require_client_template(platform, root=None):
    """Fail closed: stock templates cannot silently return in a future release."""
    import hashlib
    import json
    from pathlib import Path
    import zipfile
    from build_client_templates import NAMES, VERSION, SOURCE_SHA256, patch_hashes
    root = Path(root) if root is not None else Path(__file__).resolve().parents[1]
    path = root / 'Builds/ClientTemplates' / NAMES[platform]
    receipt = path.with_suffix(path.suffix + '.json')
    if not path.is_file() or not receipt.is_file():
        raise RuntimeError(f'Missing OpenGL-free {platform} template. Run python3 tools/build_client_templates.py {platform}; stock templates are no longer permitted.')
    data = json.loads(receipt.read_text())
    if data.get('engine') != VERSION or data.get('source_sha256') != SOURCE_SHA256:
        raise RuntimeError('Unrecognised client engine provenance: ' + str(receipt))
    if data.get('patches') != patch_hashes():
        raise RuntimeError('Client engine patches are stale; rebuild the template: ' + str(path))
    flags = data.get('flags', {})
    for key, value in dict(platform=platform, target='template_release', opengl3='no', vulkan='yes', openxr='yes').items():
        if flags.get(key) != value: raise RuntimeError(f'Invalid client build flag {key}: {path}')
    if hashlib.sha256(path.read_bytes()).hexdigest() != data.get('sha256'):
        raise RuntimeError('Client template does not match its build receipt: ' + str(path))
    blobs = [path.read_bytes()]
    if platform == 'android':
        with zipfile.ZipFile(path) as z:
            blobs = [z.read('jni/arm64-v8a/libgodot_android.so')]
    # This literal lives only in the compiled GLES3 rasterizer constructor.
    if any(b'OpenGL API %s - Compatibility' in blob for blob in blobs):
        raise RuntimeError('OpenGL rasterizer found in client template: ' + str(path))
    return path


def verify_client_export(binary, template):
    """Godot can stamp PE resources; compare executable code, not resource bytes."""
    import struct
    def code(path):
        data = path.read_bytes()
        if data[:2] != b'MZ': return data
        pe, = struct.unpack_from('<I', data, 0x3c)
        assert data[pe:pe+4] == b'PE\0\0'
        sections, = struct.unpack_from('<H', data, pe+6)
        optional, = struct.unpack_from('<H', data, pe+20)
        start = pe+24+optional
        result = []
        for i in range(sections):
            offset = start+i*40
            size, pointer = struct.unpack_from('<II', data, offset+16)
            flags, = struct.unpack_from('<I', data, offset+36)
            if flags & 0x20: result.append(data[pointer:pointer+size])
        assert result, 'No PE code sections'
        return b''.join(result)
    if code(binary) != code(template):
        raise RuntimeError('Exported client code differs from OpenGL-free template: ' + str(binary))
