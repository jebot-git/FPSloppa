extends SceneTree
const Landscape = preload("res://tools/streamed_heightfield/landscape.gd")
const Stream = preload("res://tools/streamed_heightfield/stream.gd")
const Structures = preload("res://tools/streamed_heightfield/structures.gd")
var checks := 0
var errors: Array = []

func _initialize() -> void: run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: errors.append(label); push_error(label)

func run() -> void:
	Engine.max_fps = 120
	var sites := Landscape.sites()
	var types := [0, 0, 0, 0]
	for site in sites:
		types[site.kind] += 1
		var value := Landscape.surface(site.position.x, site.position.z)
		check(absf(value.x - site.position.y) < .0001, "flat site pad " + str(site.position))
	check(types == [4, 4, 4, 4], "four of every structure type")
	# Shared tile edges are bit-identical, including height, color and coastal pads.
	for coord in [Vector2i(0, 0), Vector2i(15, 8), Vector2i(39, 10), Vector2i(47, 47), Vector2i(62, 62)]:
		var a := Landscape.generate_tile(coord)
		var right := Landscape.generate_tile(coord + Vector2i(1, 0))
		var below := Landscape.generate_tile(coord + Vector2i(0, 1))
		for i in 65:
			check(a.heights.slice((i * 65 + 64) * 4, (i * 65 + 65) * 4) == right.heights.slice(i * 65 * 4, (i * 65 + 1) * 4), "horizontal height edge")
			check(a.colors.slice((i * 65 + 64) * 4, (i * 65 + 65) * 4) == right.colors.slice(i * 65 * 4, (i * 65 + 1) * 4), "horizontal color edge")
			check(a.heights.slice((64 * 65 + i) * 4, (64 * 65 + i + 1) * 4) == below.heights.slice(i * 4, (i + 1) * 4), "vertical height edge")
			check(a.colors.slice((64 * 65 + i) * 4, (64 * 65 + i + 1) * 4) == below.colors.slice(i * 4, (i + 1) * 4), "vertical color edge")
	var port: Vector3 = sites[2].position
	check(Landscape.surface(port.x, port.z + 130).x < 0, "port basin below water")
	check(Landscape.surface(port.x, port.z + 40).x > 0, "quay on land")
	# Source ranges must fit conservative shader-displacement culling bounds.
	for z in range(-1024, 1025, 32):
		for x in range(-1024, 1025, 32):
			var height := Landscape.surface(x, z).x
			check(height >= -3.001 and height <= 40, "height inside conservative bounds")
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.far = 640
	var stream := Stream.new()
	world.add_child(stream)
	stream.setup()
	var structures := Structures.new()
	world.add_child(structures)
	structures.setup()
	for kind in 4:
		var previous := 1000000
		for mesh in structures.meshes[kind]:
			var triangles: int = mesh.surface_get_array_index_len(0) / 3
			check(triangles < previous, "structure LOD reduces triangles " + Landscape.TYPES[kind])
			previous = triangles
	var evictions := 0
	for site in [sites[0], sites[3], sites[15], sites[10], sites[0]]:
		camera.position = site.position + Vector3(80, 18, 120)
		camera.rotation = Vector3(0, atan2(80.0, 120.0), 0)
		stream.tick(camera)
		var deadline := Time.get_ticks_msec() + 30000
		while not stream.settled() and Time.get_ticks_msec() < deadline:
			await process_frame
			stream.tick(camera)
		check(stream.settled(), "workers settle at teleport")
		check(stream.resident.size() <= Stream.CAPACITY, "cache bounded")
		check(stream.running.size() <= Stream.MAX_JOBS, "workers bounded")
		check(stream.free_slots.size() + stream.resident.size() == Stream.CAPACITY, "slot accounting")
		check(stream.resident.size() == stream.desired.size(), "all requested tiles resident after settle")
		check(stream.selection_candidates <= 19 * 19, "local selection bounded")
		var slots: Dictionary = {}
		for key in stream.resident:
			var slot: int = stream.resident[key]
			check(not slots.has(slot), "resident slot unique")
			slots[slot] = true
			check(roundi(stream.page_image.get_pixel(key.x, key.y).r) == slot + 1, "page table references current slot")
		for z in 64:
			for x in 64:
				if not stream.resident.has(Vector2i(x, z)): check(stream.page_image.get_pixel(x, z).r == 0, "evicted page uses fallback")
		check(stream.visible_tiles < stream.resident.size(), "frustum excludes resident terrain")
		for i in 4: check(stream.groups[i].visible == (stream.counts[i] > 0), "empty terrain group hidden")
		var reduced := stream.terrain_triangles
		stream.force_fine = true
		stream.last_position = Vector3.INF
		stream.update_visibility(camera)
		check(stream.terrain_triangles > reduced, "terrain LOD reduces triangles")
		stream.force_fine = false
		stream.culling_enabled = false
		stream.last_position = Vector3.INF
		stream.update_visibility(camera)
		check(stream.visible_tiles == stream.resident.size(), "no-cull control includes all residents")
		stream.culling_enabled = true
		stream.last_position = Vector3.INF
		structures.update(camera)
		check(structures.visible_sites > 0, "nearby site visible")
		for kind in 4:
			for level in 3: check(structures.groups[kind][level].visible == (structures.counts[kind][level] > 0), "empty structure group hidden")
		evictions = stream.evicted_total
	check(evictions > 0, "camera movement causes eviction")
	check(stream.peak_jobs <= 2 and stream.peak_jobs > 0, "background generation exercised")
	check(stream.loaded_total > Stream.CAPACITY, "loaded lifetime count exceeds cache capacity")
	stream.reset_cache()
	camera.position = sites[0].position
	stream.tick(camera)
	# Move while jobs are active: obsolete results must not enter the new page table.
	camera.position = sites[15].position
	stream.tick(camera)
	var deadline := Time.get_ticks_msec() + 30000
	while not stream.settled() and Time.get_ticks_msec() < deadline:
		await process_frame
		stream.tick(camera)
	check(stream.settled() and stream.discarded_jobs > 0, "obsolete asynchronous results discarded")
	for key in stream.resident: check(stream.desired.has(key), "only current tiles resident after rapid teleport")
	camera.position = Vector3(1500, 40, 1500)
	stream.tick(camera)
	check(stream.resident.is_empty() and stream.desired.is_empty(), "outside world evicts fine data and keeps coarse fallback")
	var jobs_before := stream.jobs_started
	var uploads_before := stream.height_color_uploads
	stream.set_analytic(true)
	for site in sites:
		camera.position = site.position + Vector3(60, 20, 80)
		stream.tick(camera)
		check(stream.settled() and stream.resident.size() > 0, "GPU shader patches immediately resident")
		check(stream.resident.size() <= Stream.CAPACITY, "GPU shader patch placement bounded")
	check(stream.jobs_started == jobs_before and stream.height_color_uploads == uploads_before, "GPU shader requires no terrain jobs or height/color uploads")
	stream.set_analytic(false)
	check(stream.resident.is_empty(), "leaving GPU mode resets virtual pages before loading atlas")
	var report := {"checks": checks, "errors": errors, "tile_loads": stream.loaded_total, "tile_evictions": stream.evicted_total, "peak_resident": stream.peak_resident, "peak_jobs": stream.peak_jobs}
	stream.shutdown()
	world.free()
	await process_frame
	DirAccess.make_dir_recursive_absolute("res://test-results/streamed-heightfield")
	FileAccess.open("res://test-results/streamed-heightfield/validation.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("STREAMED_HEIGHTFIELD_VALIDATION ", JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
