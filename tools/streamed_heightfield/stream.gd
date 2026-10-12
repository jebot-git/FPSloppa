extends Node3D
## Bounded GPU array cache; two CPU jobs, two uploads/frame, coarse fallback throughout.
const Landscape = preload("res://tools/streamed_heightfield/landscape.gd")
const CAPACITY := 384
const LOAD_RADIUS := 256.0
const RETAIN_RADIUS := 320.0
const MAX_JOBS := 2
const UPLOADS_PER_FRAME := 2
const SEGMENTS := [32, 16, 8, 4]
var height_tiles := Texture2DArray.new()
var color_tiles := Texture2DArray.new()
var pages := ImageTexture.new()
var coarse_heights := ImageTexture.new()
var coarse_colors := ImageTexture.new()
var page_image: Image
var resident: Dictionary = {}
var free_slots: Array[int] = []
var desired: Dictionary = {}
var queue: Array[Vector2i] = []
var running: Dictionary = {}
var completed: Array = []
var mutex := Mutex.new()
var groups: Array[MultiMeshInstance3D] = []
var meshes: Array[ArrayMesh] = []
var coarse_node := MeshInstance3D.new()
var counts := [0, 0, 0, 0]
var visible_tiles := 0
var terrain_triangles := 0
var loaded_total := 0
var evicted_total := 0
var discarded_jobs := 0
var peak_resident := 0
var peak_jobs := 0
var selection_candidates := 0
var generation_times: Array = []
var upload_times: Array = []
var update_ms := 0.0
var last_cell := Vector2i(-999, -999)
var last_position := Vector3.INF
var last_rotation := Vector3.INF
var raster_enabled := true
var force_fine := false
var culling_enabled := true
var stopping := false
var analytic_enabled := false
var atlas_materials: Array = []
var analytic_material: ShaderMaterial
var analytic_coarse_material: ShaderMaterial
var jobs_started := 0
var height_color_uploads := 0

func setup() -> void:
	var height_images: Array[Image] = []
	var color_images: Array[Image] = []
	var empty_height := Image.create(Landscape.SAMPLES, Landscape.SAMPLES, false, Image.FORMAT_RF)
	var empty_color := Image.create(Landscape.SAMPLES, Landscape.SAMPLES, false, Image.FORMAT_RGBA8)
	for slot in CAPACITY:
		height_images.append(empty_height)
		color_images.append(empty_color)
		free_slots.append(slot)
	assert(height_tiles.create_from_images(height_images) == OK)
	assert(color_tiles.create_from_images(color_images) == OK)
	page_image = Image.create(Landscape.GRID, Landscape.GRID, false, Image.FORMAT_RF)
	pages.set_image(page_image)
	var coarse := Landscape.coarse_images()
	coarse_heights.set_image(coarse[0])
	coarse_colors.set_image(coarse[1])
	for segments in SEGMENTS:
		var mesh := patch_mesh(segments, Landscape.TILE, true)
		mesh.surface_set_material(0, material(false))
		meshes.append(mesh)
		var group := MultiMeshInstance3D.new()
		group.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		group.multimesh = MultiMesh.new()
		group.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		group.multimesh.use_custom_data = true
		group.multimesh.mesh = mesh
		group.multimesh.instance_count = CAPACITY
		group.multimesh.visible_instance_count = 0
		group.multimesh.custom_aabb = world_bounds()
		group.custom_aabb = world_bounds()
		group.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(group)
		groups.append(group)
	coarse_node.mesh = patch_mesh(64, Landscape.EXTENT, false)
	coarse_node.mesh.surface_set_material(0, material(true))
	coarse_node.position = Vector3(-1024, 0, -1024)
	coarse_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(coarse_node)
	for mesh in meshes: atlas_materials.append(mesh.surface_get_material(0))
	atlas_materials.append(coarse_node.mesh.surface_get_material(0))
	analytic_material = ShaderMaterial.new()
	analytic_material.shader = preload("res://tools/streamed_heightfield/procedural.gdshader")
	analytic_material.set_shader_parameter("pages", pages)
	analytic_coarse_material = analytic_material.duplicate()
	analytic_coarse_material.set_shader_parameter("coarse", true)

static func world_bounds() -> AABB:
	return AABB(Vector3(-1024, -8, -1024), Vector3(2048, 52, 2048))

func material(coarse: bool) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = preload("res://tools/streamed_heightfield/terrain.gdshader")
	for key in ["height_tiles", "color_tiles", "pages", "coarse_heights", "coarse_colors"]:
		result.set_shader_parameter(key, get(key))
	result.set_shader_parameter("coarse", coarse)
	return result

static func patch_mesh(segments: int, side: float, skirts: bool) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for z in segments + 1:
		for x in segments + 1:
			vertices.append(Vector3(x * side / segments, 0, z * side / segments))
			uv.append(Vector2(float(x) / segments, float(z) / segments))
			colors.append(Color(1, 1, 1, 0))
	for z in segments:
		for x in segments:
			var i := z * (segments + 1) + x
			indices.append_array(PackedInt32Array([i, i + segments + 1, i + 1, i + 1, i + segments + 1, i + segments + 2]))
	if skirts:
		for edge in 4:
			for i in segments:
				var a := Vector2.ZERO
				var b := Vector2.ZERO
				match edge:
					0: a = Vector2(float(i) / segments, 0); b = Vector2(float(i + 1) / segments, 0)
					1: a = Vector2(float(i) / segments, 1); b = Vector2(float(i + 1) / segments, 1)
					2: a = Vector2(0, float(i) / segments); b = Vector2(0, float(i + 1) / segments)
					3: a = Vector2(1, float(i) / segments); b = Vector2(1, float(i + 1) / segments)
				var start := vertices.size()
				for p in [a, b, a, b]: vertices.append(Vector3(p.x * side, 0, p.y * side)); uv.append(p)
				colors.append_array(PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1)]))
				indices.append_array(PackedInt32Array([start, start + 2, start + 1, start + 1, start + 2, start + 3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.custom_aabb = AABB(Vector3(0, -8, 0), Vector3(side, 52, side))
	return mesh

func set_raster(enabled: bool) -> void:
	raster_enabled = enabled
	coarse_node.visible = enabled
	for i in groups.size(): groups[i].visible = enabled and counts[i] > 0
	last_position = Vector3.INF

func set_analytic(enabled: bool) -> void:
	if enabled == analytic_enabled: return
	reset_cache()
	analytic_enabled = enabled
	for i in 4: meshes[i].surface_set_material(0, analytic_material if enabled else atlas_materials[i])
	coarse_node.mesh.surface_set_material(0, analytic_coarse_material if enabled else atlas_materials[4])

func select_tiles(camera: Camera3D) -> void:
	var p := Vector2(camera.global_position.x, camera.global_position.z)
	var cell := Vector2i(floori((p.x + 1024) / 32), floori((p.y + 1024) / 32))
	if cell == last_cell: return
	last_cell = cell
	desired.clear()
	queue.clear()
	selection_candidates = 0
	# Only inspect a local rectangle, never all 4,096 world tiles.
	var span := ceili((LOAD_RADIUS + 23) / 32)
	for z in range(maxi(0, cell.y - span), mini(64, cell.y + span + 1)):
		for x in range(maxi(0, cell.x - span), mini(64, cell.x + span + 1)):
			selection_candidates += 1
			var key := Vector2i(x, z)
			var center := Vector2(x * 32 - 1008, z * 32 - 1008)
			if center.distance_to(p) <= LOAD_RADIUS + 23:
				desired[key] = true
				if not analytic_enabled and not resident.has(key) and not running.has(key): queue.append(key)
	queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (Vector2(a) * 32 - Vector2.ONE * 1008).distance_squared_to(p) < (Vector2(b) * 32 - Vector2.ONE * 1008).distance_squared_to(p))
	var changed := false
	for key in resident.keys():
		var center := Vector2(key) * 32 - Vector2.ONE * 1008
		if center.distance_to(p) > RETAIN_RADIUS + 23:
			evict(key)
			changed = true
	if changed: pages.update(page_image)

func evict(key: Vector2i) -> void:
	free_slots.append(resident[key])
	resident.erase(key)
	page_image.set_pixel(key.x, key.y, Color(0, 0, 0))
	evicted_total += 1

func generate_job(coord: Vector2i) -> void:
	var data := Landscape.generate_tile(coord)
	mutex.lock()
	completed.append(data)
	mutex.unlock()

func tick(camera: Camera3D) -> void:
	if stopping: return
	var start := Time.get_ticks_usec()
	var previous_cell := last_cell
	select_tiles(camera)
	if analytic_enabled:
		# CPU only selects patches; height and ground color are evaluated by the shader.
		var changed := false
		if previous_cell != last_cell:
			for key in desired:
				if resident.has(key): continue
				if free_slots.is_empty():
					for old in resident:
						if not desired.has(old): evict(old); break
				assert(not free_slots.is_empty())
				var slot: int = free_slots.pop_back()
				resident[key] = slot
				page_image.set_pixel(key.x, key.y, Color(slot + 1, 0, 0))
				loaded_total += 1
				changed = true
		peak_resident = maxi(peak_resident, resident.size())
		if changed: pages.update(page_image); last_position = Vector3.INF
		update_visibility(camera)
		update_ms = (Time.get_ticks_usec() - start) / 1000.0
		return
	var updated := false
	for i in UPLOADS_PER_FRAME:
		mutex.lock()
		var data = null
		if not completed.is_empty() and WorkerThreadPool.is_task_completed(running[completed[0].coord]):
			data = completed.pop_front()
		mutex.unlock()
		if data == null: break
		var key: Vector2i = data.coord
		var task: int = running[key]
		WorkerThreadPool.wait_for_task_completion(task)
		running.erase(key)
		generation_times.append(data.generation_ms)
		if generation_times.size() > 4096: generation_times.pop_front()
		if not desired.has(key): discarded_jobs += 1; continue
		if free_slots.is_empty():
			var farthest := Vector2i(-1, -1)
			var far_distance := -1.0
			for old in resident:
				if desired.has(old): continue
				var distance: float = (Vector2(old) * 32 - Vector2.ONE * 1008).distance_squared_to(Vector2(camera.position.x, camera.position.z))
				if distance > far_distance: far_distance = distance; farthest = old
			if farthest.x >= 0: evict(farthest)
		if free_slots.is_empty(): discarded_jobs += 1; continue
		var upload_start := Time.get_ticks_usec()
		var slot: int = free_slots.pop_back()
		height_tiles.update_layer(Image.create_from_data(65, 65, false, Image.FORMAT_RF, data.heights), slot)
		color_tiles.update_layer(Image.create_from_data(65, 65, false, Image.FORMAT_RGBA8, data.colors), slot)
		resident[key] = slot
		page_image.set_pixel(key.x, key.y, Color(slot + 1, 0, 0))
		loaded_total += 1
		height_color_uploads += 1
		peak_resident = maxi(peak_resident, resident.size())
		upload_times.append((Time.get_ticks_usec() - upload_start) / 1000.0)
		if upload_times.size() > 4096: upload_times.pop_front()
		updated = true
	if updated: pages.update(page_image)
	while running.size() < MAX_JOBS and not queue.is_empty():
		var key: Vector2i = queue.pop_front()
		if not desired.has(key) or resident.has(key) or running.has(key): continue
		running[key] = WorkerThreadPool.add_task(generate_job.bind(key), false, "heightfield tile")
		jobs_started += 1
		peak_jobs = maxi(peak_jobs, running.size())
	if updated: last_position = Vector3.INF
	update_visibility(camera)
	update_ms = (Time.get_ticks_usec() - start) / 1000.0

static func outside_frustum(bounds: AABB, planes: Array[Plane]) -> bool:
	var center := bounds.get_center()
	var half := bounds.size * .5
	for plane in planes:
		if plane.distance_to(center) > plane.normal.abs().dot(half): return true
	return false

func update_visibility(camera: Camera3D) -> void:
	if camera.global_position == last_position and camera.global_rotation == last_rotation: return
	last_position = camera.global_position
	last_rotation = camera.global_rotation
	counts = [0, 0, 0, 0]
	visible_tiles = 0
	terrain_triangles = 0
	var planes := camera.get_frustum()
	for key in resident:
		var origin := Vector3(key.x * 32 - 1024, 0, key.y * 32 - 1024)
		var bounds := AABB(origin + Vector3(0, -8, 0), Vector3(32, 52, 32))
		if culling_enabled and outside_frustum(bounds, planes): continue
		var nearest := Vector3(clampf(camera.position.x, origin.x, origin.x + 32), camera.position.y, clampf(camera.position.z, origin.z, origin.z + 32))
		var distance := nearest.distance_to(camera.position)
		var family := 0 if force_fine or distance < 48 else 1 if distance < 112 else 2 if distance < 208 else 3
		if raster_enabled:
			var group := groups[family].multimesh
			group.set_instance_transform(counts[family], Transform3D(Basis.IDENTITY, origin))
			group.set_instance_custom_data(counts[family], Color(resident[key], 0, 0, 0))
		counts[family] += 1
		visible_tiles += 1
		terrain_triangles += meshes[family].surface_get_array_index_len(0) / 3
	for i in 4:
		groups[i].multimesh.visible_instance_count = counts[i]
		groups[i].visible = raster_enabled and counts[i] > 0

func settled() -> bool:
	return queue.is_empty() and running.is_empty()

func shutdown() -> void:
	stopping = true
	for task in running.values(): WorkerThreadPool.wait_for_task_completion(task)
	running.clear()
	completed.clear()

func reset_cache() -> void:
	# Benchmark/control operation only; never wait for workers in normal tick().
	shutdown()
	for key in resident.keys(): evict(key)
	pages.update(page_image)
	queue.clear()
	desired.clear()
	last_cell = Vector2i(-999, -999)
	last_position = Vector3.INF
	stopping = false

func _exit_tree() -> void:
	shutdown()
