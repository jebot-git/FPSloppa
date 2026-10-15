extends Node3D
var world_aabb := AABB(Vector3(-1024, -5, -1024), Vector3(2048, 85, 2048))
## Generated town/port/base and the existing synthetic factory. Shared LOD meshes.
const Landscape = preload("res://tools/streamed_heightfield/landscape.gd")
const Stream = preload("res://tools/streamed_heightfield/stream.gd")
const FAR_DISTANCE := 550.0
var placements := Landscape.sites()
var factory_base_offset := 2.4
var meshes: Array = []
var groups: Array = []
var counts: Array = []
var visible_sites := 0
var triangles := 0
var last_position := Vector3.INF
var last_rotation := Vector3.INF
var force_near := false
var culling_enabled := true
var view_distance := FAR_DISTANCE
var previous_lods: Dictionary = {}

class Builder:
	extends RefCounted
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	const FACES := [[0, 2, 3, 1], [4, 5, 7, 6], [2, 6, 7, 3], [0, 1, 5, 4], [0, 4, 6, 2], [1, 3, 7, 5]]
	func box(center: Vector3, size: Vector3, color: Color) -> void:
		var corners: Array[Vector3] = []
		for i in 8:
			corners.append(center + Vector3(.5 if i & 1 else -.5, .5 if i & 2 else -.5, .5 if i & 4 else -.5) * size)
		for face in FACES:
			var start := vertices.size()
			var normal := (corners[face[1]] - corners[face[0]]).cross(corners[face[2]] - corners[face[0]]).normalized()
			var shade := color * (.68 + absf(normal.dot(Vector3(-.4, .8, .3).normalized())) * .32)
			shade.a = 1
			for index in face: vertices.append(corners[index]); colors.append(shade)
			indices.append_array(PackedInt32Array([start, start + 1, start + 2, start, start + 2, start + 3]))
	func roof(center: Vector3, size: Vector3, color: Color) -> void:
		var x := size.x * .5
		var z := size.z * .5
		var points := [Vector3(-x, 0, -z), Vector3(x, 0, -z), Vector3(-x, 0, z), Vector3(x, 0, z), Vector3(0, size.y, -z), Vector3(0, size.y, z)]
		for face in [[0, 1, 4], [3, 2, 5], [0, 4, 5], [0, 5, 2], [1, 3, 5], [1, 5, 4], [0, 2, 3], [0, 3, 1]]:
			var start := vertices.size()
			var shade := color * (1.0 if face[0] == 0 else .78)
			shade.a = 1
			for index in face: vertices.append(center + points[index]); colors.append(shade)
			indices.append_array(PackedInt32Array([start, start + 1, start + 2]))
	func finish() -> ArrayMesh:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		material.vertex_color_is_srgb = true
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.surface_set_material(0, material)
		return mesh

static func town(level: int) -> ArrayMesh:
	var b := Builder.new()
	for z in 4:
		for x in 4:
			var p := Vector3([-72, -28, 28, 72][x], 0, [-72, -28, 28, 72][z])
			var height := 5.0 + ((x + z) % 3) * 3.0
			var wall := Color(.69, .57, .42).lerp(Color(.57, .66, .61), float((x * 3 + z) % 5) / 5.0)
			var proxy_height := height + 2.0 if level == 2 else height
			b.box(p + Vector3(0, proxy_height * .5, 0), Vector3(17, proxy_height, 21), wall)
			if level < 2: b.roof(p + Vector3(0, height, 0), Vector3(19, 3, 23), Color(.39, .22, .16))
			if level == 0:
				for side in [-1.0, 1.0]:
					for wx in [-5.0, 5.0]:
						for y in range(2, int(height), 3): b.box(p + Vector3(wx, y, side * 10.56), Vector3(2, 1.4, .15), Color(.17, .29, .32))
				b.box(p + Vector3(0, 1.3, 10.6), Vector3(1.8, 2.6, .2), Color(.25, .18, .12))
				b.box(p + Vector3(6, height + 1.8, -5), Vector3(1.5, 4, 1.5), Color(.42, .35, .29))
	b.box(Vector3(0, .2, 22), Vector3(20, .4, 20), Color(.47, .46, .41))
	b.box(Vector3(0, 10, -20), Vector3(9, 20, 9), Color(.65, .61, .50))
	if level < 2: b.roof(Vector3(0, 20, -20), Vector3(11, 5, 11), Color(.34, .31, .26))
	return b.finish()

static func port(level: int) -> ArrayMesh:
	var b := Builder.new()
	b.box(Vector3(0, -2.38, 130), Vector3(220, .04, 150), Color(.14, .32, .40))
	b.box(Vector3(0, -.25, 55), Vector3(220, 1.4, 18), Color(.43, .44, .40))
	for x in [-65.0, 65.0]:
		b.box(Vector3(x, -.5, 110), Vector3(15, 2, 95), Color(.46, .43, .37))
		if level == 0:
			for z in [80.0, 110.0, 140.0]: b.box(Vector3(x, -2, z), Vector3(7, 5, 7), Color(.29, .31, .28))
	for x in [-62.0, 62.0]:
		b.box(Vector3(x, 6, -62), Vector3(56, 12, 30), Color(.61, .62, .57))
		if level < 2: b.roof(Vector3(x, 12, -62), Vector3(58, 4, 32), Color(.32, .37, .38))
	for z in 3:
		for x in 7:
			var p := Vector3((x - 3) * 25, 1.5, (z - 1) * 19)
			var color: Color = [Color(.59, .24, .17), Color(.22, .39, .48), Color(.56, .53, .29)][(x + z) % 3]
			b.box(p, Vector3(14, 3, 6), color)
			if level == 0:
				for rib in [-5.0, -2.0, 2.0, 5.0]: b.box(p + Vector3(rib, 0, 3.04), Vector3(.12, 3, .12), color.darkened(.18))
	for x in [-40.0, 40.0]:
		var yellow := Color(.73, .62, .22)
		b.box(Vector3(x, 15, 48), Vector3(4, 30, 4), yellow)
		b.box(Vector3(x + 8, 29, 74), Vector3(4, 3, 65), yellow)
		b.box(Vector3(x + 8, 23, 104), Vector3(1, 12, 1), Color(.23, .24, .22))
		if level == 0:
			for dx in [-7.0, 7.0]: b.box(Vector3(x + dx, 10, 48), Vector3(1, 20, 1), yellow)
	b.box(Vector3(30, -.5, 134), Vector3(28, 4, 72), Color(.24, .28, .28))
	b.box(Vector3(30, 2.1, 134), Vector3(24, 1.2, 64), Color(.45, .43, .36))
	b.box(Vector3(30, 5, 153), Vector3(22, 6, 14), Color(.74, .75, .67))
	if level < 2: b.box(Vector3(30, 10, 156), Vector3(12, 5, 9), Color(.83, .84, .75))
	return b.finish()

static func military(level: int) -> ArrayMesh:
	var b := Builder.new()
	var wall := Color(.43, .47, .33)
	for x in [-66.0, -26.0, 26.0, 66.0]:
		b.box(Vector3(x, 3, -60), Vector3(25, 6, 38), wall)
		if level < 2: b.roof(Vector3(x, 6, -60), Vector3(27, 2.5, 40), Color(.28, .34, .27))
		if level == 0:
			for dx in [-7.0, 0.0, 7.0]: b.box(Vector3(x + dx, 3.1, -40.95), Vector3(2, 1.3, .2), Color(.19, .27, .24))
	for x in [-52.0, 52.0]:
		b.box(Vector3(x, 8, 10), Vector3(60, 16, 44), Color(.39, .43, .35))
		if level < 2: b.roof(Vector3(x, 16, 10), Vector3(62, 6, 46), Color(.29, .33, .28))
		if level == 0: b.box(Vector3(x, 6, 32.05), Vector3(42, 12, .2), Color(.19, .23, .21))
	b.box(Vector3(0, .08, 70), Vector3(180, .16, 25), Color(.23, .25, .24))
	if level < 2:
		for x in range(-80, 81, 20): b.box(Vector3(x, .18, 70), Vector3(8, .04, 1), Color(.72, .73, .62))
	for x in [-96.0, 96.0]:
		for z in [-96.0, 96.0]:
			b.box(Vector3(x, 7, z), Vector3(3, 14, 3), wall)
			b.box(Vector3(x, 14, z), Vector3(8, 4, 8), Color(.37, .41, .31))
	b.box(Vector3(0, 16, -10), Vector3(3, 32, 3), Color(.41, .44, .37))
	b.box(Vector3(0, 33, -10), Vector3(14, 2, 10), Color(.66, .69, .59))
	if level == 0:
		for side in [-1.0, 1.0]:
			b.box(Vector3(side * 104, 1.5, 0), Vector3(.3, 3, 208), Color(.48, .51, .43))
			b.box(Vector3(0, 1.5, side * 104), Vector3(208, 3, .3), Color(.48, .51, .43))
	return b.finish()

func setup() -> void:
	if meshes.is_empty():
		meshes = [[], [], [], []]
		for level in 3:
			meshes[0].append(town(level))
			meshes[1].append(load("res://tools/voxelspace/assets/factory_" + ["culled", "medium", "proxy"][level] + ".res"))
			meshes[2].append(port(level))
			meshes[3].append(military(level))
	groups = []
	for kind in meshes.size():
		groups.append([])
		for level in 3:
			var group := MultiMeshInstance3D.new()
			group.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			group.multimesh = MultiMesh.new()
			group.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			group.multimesh.mesh = meshes[kind][level]
			group.multimesh.instance_count = placements.size()
			group.multimesh.visible_instance_count = 0
			group.multimesh.custom_aabb = world_aabb
			group.custom_aabb = group.multimesh.custom_aabb
			group.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(group)
			groups[kind].append(group)

func update(camera: Camera3D) -> void:
	if last_position == camera.global_position and last_rotation == camera.global_rotation: return
	last_position = camera.global_position
	last_rotation = camera.global_rotation
	counts = []
	for kind in meshes.size(): counts.append([0, 0, 0])
	visible_sites = 0
	triangles = 0
	var planes := camera.get_frustum()
	for i in placements.size():
		var site: Dictionary = placements[i]
		var kind: int = site.kind
		var origin: Vector3 = site.position
		if kind == 1: origin.y -= factory_base_offset
		var bounds: AABB = meshes[kind][0].get_aabb()
		bounds.position += origin
		var nearest := Vector3(clampf(camera.global_position.x, bounds.position.x, bounds.end.x), clampf(camera.global_position.y, bounds.position.y, bounds.end.y), clampf(camera.global_position.z, bounds.position.z, bounds.end.z))
		var distance := camera.global_position.distance_to(nearest)
		if distance > view_distance or (culling_enabled and not camera.get_viewport().use_xr and Stream.outside_frustum(bounds, planes)): continue
		var level: int = previous_lods.get(i, 2)
		if force_near or distance < 65: level = 0
		elif distance > 180: level = 2
		elif level == 0 and distance > 85: level = 1
		elif level == 2 and distance < 150: level = 1
		previous_lods[i] = level
		var index: int = counts[kind][level]
		groups[kind][level].multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, origin))
		counts[kind][level] += 1
		visible_sites += 1
		triangles += meshes[kind][level].surface_get_array_index_len(0) / 3
	for kind in meshes.size():
		for level in 3:
			groups[kind][level].multimesh.visible_instance_count = counts[kind][level]
			groups[kind][level].visible = counts[kind][level] > 0
