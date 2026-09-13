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
    return {'method': 'mobile', 'android_driver': 'vulkan', 'opengl_fallback': False}
