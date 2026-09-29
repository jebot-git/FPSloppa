"""Finish the dimensioned wrist-computer blanks in Blender, then export native inputs.
Run export_wrist.gd first. Execute this file in Blender MCP; it owns only STWrist_*.
"""
import bpy, bmesh, json, math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'tools/tribes/wrist-sources'
OUT = ROOT / 'deathmatch/tribes/wrist'
scene = bpy.data.scenes.get('STWristWorkshop') or bpy.data.scenes.new('STWristWorkshop')
bpy.context.window.scene = scene
for obj in list(scene.objects):
    if obj.name.startswith('STWrist_'):
        bpy.data.objects.remove(obj, do_unlink=True)

report = {}
for index, kind in enumerate(['pda', 'camera']):
    bpy.ops.import_scene.gltf(filepath=str(SOURCE / ('base-' + kind + '.glb')))
    imported = list(bpy.context.selected_objects)
    root = bpy.data.objects.new('STWrist_' + kind, None)
    scene.collection.objects.link(root)
    report[kind] = {}
    for obj in imported:
        if obj.type != 'MESH':
            continue
        # Weld the triangulated authoring mesh before rounding its physical edges.
        mesh = bmesh.new(); mesh.from_mesh(obj.data)
        bmesh.ops.remove_doubles(mesh, verts=list(mesh.verts), dist=0.0000001)
        bmesh.ops.recalc_face_normals(mesh, faces=list(mesh.faces))
        mesh.to_mesh(obj.data); mesh.free()
        bevel = obj.modifiers.new('Machined edges', 'BEVEL')
        bevel.width = .00065; bevel.segments = 2; bevel.limit_method = 'ANGLE'
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=bevel.name)
        # Separate connected casing components from the two cuffs. In Blender
        # +Y runs behind the screen (Godot -Z); only cuff/support parts exceed 4 cm.
        mesh = bmesh.new(); mesh.from_mesh(obj.data); mesh.verts.ensure_lookup_table(); mesh.verts.index_update()
        seen = set(); groups = {'Case': set(), 'Mount': set()}
        for start in mesh.verts:
            if start.index in seen:
                continue
            component = []; pending = [start]; seen.add(start.index)
            while pending:
                vertex = pending.pop(); component.append(vertex)
                for edge in vertex.link_edges:
                    other = edge.other_vert(vertex)
                    if other.index not in seen:
                        seen.add(other.index); pending.append(other)
            low = min(v.co.y for v in component); high = max(v.co.y for v in component)
            part = 'Mount' if high > .040 else 'Case'
            # Lengthen the four supports by 4 cm; the cuffs themselves keep
            # their original position and forearm orientation.
            if part == 'Mount' and low < .022:
                for vertex in component:
                    fraction = max(0, min(1, (.0455 - vertex.co.y) / .025))
                    vertex.co.y -= .04 * fraction
            groups[part].update(v.index for v in component)
        for part, indices in groups.items():
            assert indices, part
            split = mesh.copy(); split.verts.ensure_lookup_table()
            bmesh.ops.delete(split, geom=[v for v in split.verts if v.index not in indices], context='VERTS')
            bmesh.ops.recalc_face_normals(split, faces=list(split.faces))
            data = bpy.data.meshes.new('STWrist_' + kind + '_' + part)
            split.to_mesh(data); split.free()
            # BMesh copies the palette but not the active/render layer indices.
            # Without these glTF fills COLOR_0 with white and moves art to COLOR_1.
            if data.color_attributes:
                data.color_attributes.active_color_index = 0
                data.color_attributes.render_color_index = 0
            for material in obj.data.materials:
                data.materials.append(material)
            node = bpy.data.objects.new('STWrist_' + kind + '_' + part, data)
            scene.collection.objects.link(node); node.parent = root
            report[kind][part] = {'vertices': len(data.vertices), 'faces': len(data.polygons)}
        mesh.free(); bpy.data.objects.remove(obj, do_unlink=True)
    for obj in bpy.context.selected_objects:
        obj.select_set(False)
    root.select_set(True)
    for obj in root.children:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    # Export at the original screen-centred pivot, before spacing the workshop.
    bpy.ops.export_scene.gltf(filepath=str(OUT / (kind + '.glb')), export_format='GLB',
                              use_selection=True, export_apply=True)
    # Preview the runtime left/right wrist pose in the editable workshop only.
    for obj in root.children:
        if obj.name.endswith('_Case'):
            obj.location.y = -.04
            obj.rotation_euler.y = math.radians(-60 if kind == 'pda' else 60)
    root.location.x += index * .38

# Save a self-contained art source without changing the user's other scenes.
bpy.data.libraries.write(str(SOURCE / 'wrist-displays.blend'), {scene}, fake_user=True)
(OUT / 'model-report.json').write_text(json.dumps(report, indent=2) + '\n')
for area in bpy.context.screen.areas:
    if area.type == 'VIEW_3D':
        space = area.spaces.active
        space.region_3d.view_location = Vector((.18, 0, 0))
        space.region_3d.view_distance = .88
        space.region_3d.view_rotation = Vector((.22, -.38, .23)).to_track_quat('Z', 'Y')
        space.shading.type = 'MATERIAL'; space.overlay.show_overlays = False
print('ST_WRIST_MODELS', json.dumps(report))
