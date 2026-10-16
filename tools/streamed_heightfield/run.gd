extends SceneTree
const Landscape = preload("res://tools/streamed_heightfield/landscape.gd")
const Stream = preload("res://tools/streamed_heightfield/stream.gd")
const Structures = preload("res://tools/streamed_heightfield/structures.gd")
const Columns = preload("res://tools/streamed_heightfield/column_renderer.gd")
const MODES := ["raster_lod", "raster_fine", "raster_no_cull", "columns_quarter", "columns_quarter_reference", "columns_half", "columns_full", "columns_full_reference"]
var world := Node3D.new()
var camera := Camera3D.new()
var stream := Stream.new()
var structures := Structures.new()
var columns
var interactive := false
var hud: Label
var mode := "raster_lod"
var mouse_held := false
var rows: Array = []
var output := "res://test-results/streamed-heightfield"
var setup_ms := 0.0
var measuring := false
var failure := ""

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	if DisplayServer.get_name() == "headless": push_error("Benchmark requires a real Vulkan device"); quit(2); return
	interactive = OS.get_cmdline_user_args().has("--interactive")
	root.size = Vector2i(1440, 900)
	root.content_scale_size = root.size
	root.msaa_3d = Viewport.MSAA_DISABLED
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.add_child(world)
	world.add_child(camera)
	camera.current = true
	camera.fov = 70
	camera.near = .1
	camera.far = 640
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.52, .66, .73)
	world.add_child(environment)
	var start := Time.get_ticks_usec()
	world.add_child(stream)
	stream.setup()
	world.add_child(structures)
	structures.setup()
	setup_ms = (Time.get_ticks_usec() - start) / 1000.0
	visit(0)
	DirAccess.make_dir_recursive_absolute(output)
	var viewport := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport, true)
	if interactive:
		hud = Label.new()
		hud.position = Vector2(16, 16)
		hud.add_theme_font_size_override("font_size", 18)
		root.add_child(hud)
		return
	if OS.get_cmdline_user_args().has("--gpu-shader"):
		for site in 4:
			visit(site)
			var variants := ["raster_lod", "raster_analytic"] if site % 2 == 0 else ["raster_analytic", "raster_lod"]
			for variant in variants:
				await select_mode(variant)
				stream.reset_cache()
				await settle()
				await measure(Landscape.TYPES[site] + "_" + variant, viewport, 360, false)
		for variant in ["raster_lod", "raster_analytic", "raster_lod"]:
			await select_mode(variant)
			stream.reset_cache()
			flyby(0)
			await settle()
			await measure("gpu_paced_" + variant + "_" + str(rows.size()), viewport, 1200, true, 120, 20.0)
		write_report("rendering-gpu-shader.json")
		await finish()
		return
	if OS.get_cmdline_user_args().has("--cold"):
		for variant in ["raster_lod", "columns_quarter"]:
			await select_mode(variant)
			stream.reset_cache()
			visit(3)
			await measure("cold_military_" + variant, viewport, 480, false, 0)
		write_report("rendering-cold.json")
		await finish()
		return
	if OS.get_cmdline_user_args().has("--paced"):
		for variant in ["raster_lod", "columns_quarter", "columns_full_reference", "raster_lod"]:
			await select_mode(variant)
			stream.reset_cache()
			flyby(0)
			await settle()
			await measure("paced_flyby_" + variant + "_" + str(rows.size()), viewport, 1200, true, 120, 20.0)
		write_report("rendering-paced.json")
		await finish()
		return
	if OS.get_cmdline_user_args().has("--smoke"):
		for site in 4:
			visit(site)
			await settle()
			for variant in ["raster_lod", "columns_quarter"]:
				await select_mode(variant)
				for i in 30: await process_frame
				await screenshot(Landscape.TYPES[site] + "_" + variant)
		await overview()
		await finish()
		return
	for site in 4:
		visit(site)
		await settle()
		var variants := MODES.duplicate()
		if site % 2 == 1: variants.reverse()
		for variant in variants:
			await select_mode(variant)
			await measure(Landscape.TYPES[site] + "_" + variant, viewport, 360, false)
	if not OS.get_cmdline_user_args().has("--static"):
		# Stress path: reset pages, settle at the same start, then traverse 4.8 km.
		for variant in ["raster_lod", "columns_quarter", "columns_full_reference", "raster_lod"]:
			await select_mode(variant)
			stream.reset_cache()
			flyby(0)
			await settle()
			await measure("streaming_flyby_" + variant + "_" + str(rows.size()), viewport, 1200, true)
		# Teleport is deliberately measured cold, without settling or warming first.
		for variant in ["raster_lod", "columns_quarter"]:
			await select_mode(variant)
			stream.reset_cache()
			visit(3)
			await measure("cold_military_" + variant, viewport, 480, false, 0)
	await select_mode("raster_lod")
	await overview()
	write_report("rendering-static.json" if OS.get_cmdline_user_args().has("--static") else "rendering.json")
	await finish()

func write_report(filename: String) -> void:
	var report := {"date": "2026-10-12", "engine": Engine.get_version_info().string, "cpu": OS.get_processor_name(), "gpu": RenderingServer.get_video_adapter_name(), "renderer": RenderingServer.get_current_rendering_method(), "resolution": [1440, 900], "extent_m": [2048, 2048], "area_km2": 4.194304, "tile_grid": [64, 64], "tile_m": 32, "tile_samples": [65, 65], "cache_capacity": Stream.CAPACITY, "cache_height_color_bytes": Stream.CAPACITY * 65 * 65 * 8, "coarse_samples": [129, 129], "workers": Stream.MAX_JOBS, "uploads_per_frame": Stream.UPLOADS_PER_FRAME, "load_retain_radius_m": [Stream.LOAD_RADIUS, Stream.RETAIN_RADIUS], "view_distance_m": 640, "structure_cutoff_m": structures.FAR_DISTANCE, "placements": serializable_sites(), "structure_triangles": structure_triangle_counts(), "setup_ms": setup_ms, "generation_ms": summary(stream.generation_times), "upload_ms": summary(stream.upload_times), "peak_resident": stream.peak_resident, "peak_jobs": stream.peak_jobs, "rows": rows, "scope": "Render prototype: deterministic procedural tiles generated on two workers, bounded resident GPU arrays, coarse fallback, shared polygon structures. Static cases settled; moving cases stream on the measured path. Classic columns share page table/tiles and use yaw-only projection; reduced resolution and different sampling are quality tradeoffs. No avatars, collision, networking, combat, shadows or XR."}
	FileAccess.open(output + "/" + filename, FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("STREAMED_HEIGHTFIELD_REPORT ", output + "/" + filename)

func serializable_sites() -> Array:
	var result: Array = []
	for site in structures.placements:
		result.append({"kind": site.name, "position_m": [site.position.x, site.position.y, site.position.z]})
	return result

func structure_triangle_counts() -> Array:
	var result: Array = []
	for kind in 4:
		var counts: Array = []
		for mesh in structures.meshes[kind]: counts.append(mesh.surface_get_array_index_len(0) / 3)
		result.append({"kind": Landscape.TYPES[kind], "lod_triangles": counts})
	return result

func visit(kind: int) -> void:
	var site: Dictionary = structures.placements[kind]
	var offset := Vector3(120, 20, 140)
	if kind == 2: offset = Vector3(-135, 20, 130)
	camera.position = site.position + offset
	camera.rotation = Vector3(0, atan2(offset.x, offset.z), 0)
	stream.last_cell = Vector2i(-999, -999)

func select_mode(variant: String) -> void:
	if is_instance_valid(columns):
		columns.free()
		columns = null
		for i in 3: await process_frame
	mode = variant
	stream.set_analytic(variant == "raster_analytic")
	stream.force_fine = variant == "raster_fine"
	stream.culling_enabled = variant != "raster_no_cull"
	stream.last_position = Vector3.INF
	stream.set_raster(variant.begins_with("raster"))
	structures.force_near = variant == "raster_fine"
	# Each renderer comparison starts with identical structure LOD state.
	structures.reset_lods()
	structures.last_position = Vector3.INF
	if variant.begins_with("columns"):
		columns = Columns.new()
		world.add_child(columns)
		var size := Vector2i(360, 225) if variant.begins_with("columns_quarter") else Vector2i(720, 450) if variant == "columns_half" else Vector2i(1440, 900)
		columns.setup_stream(stream, size, not variant.ends_with("reference"))
		var deadline := Time.get_ticks_msec() + 15000
		while not columns.ready_gpu and columns.failure.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
		if not columns.ready_gpu:
			failure = columns.failure
			push_error("Streamed columns failed: " + failure)
			await finish(3)

func settle() -> void:
	var deadline := Time.get_ticks_msec() + 30000
	stream.tick(camera)
	while not stream.settled() and Time.get_ticks_msec() < deadline: await process_frame
	if not stream.settled(): push_error("Tile settle timeout"); await finish(4)
	for i in 15: await process_frame

static func summary(values: Array) -> Dictionary:
	if values.is_empty(): return {"median": 0.0, "p95": 0.0, "p99": 0.0, "max": 0.0}
	var sorted := values.duplicate()
	sorted.sort()
	return {"median": sorted[sorted.size() / 2], "p95": sorted[mini(int(sorted.size() * .95), sorted.size() - 1)], "p99": sorted[mini(int(sorted.size() * .99), sorted.size() - 1)], "max": sorted[-1]}

func measure(label: String, viewport: RID, sample_count: int, moving: bool, warmup: int = 120, seconds: float = 0.0) -> void:
	for i in warmup: await process_frame
	if not moving and warmup > 0: await screenshot(label)
	var frame: Array = []
	var gpu: Array = []
	var cpu: Array = []
	var compute: Array = []
	var update: Array = []
	var draws: Array = []
	var primitives: Array = []
	var residents: Array = []
	var visible: Array = []
	var pending: Array = []
	var loaded_before := stream.loaded_total
	var evicted_before := stream.evicted_total
	var discarded_before := stream.discarded_jobs
	var jobs_before := stream.jobs_started
	var uploads_before := stream.height_color_uploads
	var previous := Time.get_ticks_usec()
	var started := previous
	var index := 0
	measuring = true
	while (Time.get_ticks_usec() - started) / 1000000.0 < seconds if seconds > 0 else index < sample_count:
		if moving: flyby((Time.get_ticks_usec() - started) / 1000000.0 * 40.0 if seconds > 0 else float(index))
		await process_frame
		var now := Time.get_ticks_usec()
		frame.append((now - previous) / 1000.0)
		previous = now
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport))
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport))
		compute.append(columns.compute_gpu_ms if columns != null else 0.0)
		update.append(stream.update_ms)
		draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		residents.append(stream.resident.size())
		visible.append(stream.visible_tiles)
		pending.append(stream.queue.size() + stream.running.size())
		index += 1
	measuring = false
	var missed := 0
	for value in frame:
		if value > 1000.0 / 60.0: missed += 1
	var row := {"case": label, "samples": frame.size(), "warmup": warmup, "moving": moving, "duration_seconds": (Time.get_ticks_usec() - started) / 1000000.0, "path_m_per_frame": 4.0 if moving and seconds == 0 else 0.0, "path_m_per_second": 160.0 if seconds > 0 else 0.0, "frame_ms": summary(frame), "viewport_gpu_ms": summary(gpu), "render_cpu_ms": summary(cpu), "column_compute_gpu_ms": summary(compute), "stream_update_cpu_ms": summary(update), "draw_calls": summary(draws), "primitives": summary(primitives), "resident_tiles": summary(residents), "visible_fine_tiles": summary(visible), "pending_tiles": summary(pending), "loaded_tiles": stream.loaded_total - loaded_before, "evicted_tiles": stream.evicted_total - evicted_before, "discarded_jobs": stream.discarded_jobs - discarded_before, "lod_counts_end": stream.counts.duplicate(), "structure_lod_counts_end": structures.counts.duplicate(true), "visible_sites_end": structures.visible_sites, "frames_over_16_67_ms_percent": missed * 100.0 / frame.size()}
	rows.append(row)
	row.analytic_shader = stream.analytic_enabled
	row.generation_jobs = stream.jobs_started - jobs_before
	row.height_color_uploads = stream.height_color_uploads - uploads_before
	print("STREAMED_HEIGHTFIELD_RESULT ", JSON.stringify(row))
	# Keep screenshots outside measured intervals, including cold-case captures.
	if moving or warmup == 0: await screenshot(label)

func flyby(frame: float) -> void:
	var points := [Vector2(-850, -700), Vector2(850, -700), Vector2(850, -180), Vector2(-850, -180), Vector2(-850, 350), Vector2(850, 350), Vector2(850, 820), Vector2(-850, 820)]
	var remaining := frame * 4.0
	for i in points.size() - 1:
		var length: float = points[i].distance_to(points[i + 1])
		if remaining <= length:
			var p: Vector2 = points[i].lerp(points[i + 1], remaining / length)
			var direction: Vector2 = (points[i + 1] - points[i]).normalized()
			camera.position = Vector3(p.x, Landscape.surface(p.x, p.y).x + 18, p.y)
			camera.rotation = Vector3(0, atan2(-direction.x, -direction.y), 0)
			return
		remaining -= length

func screenshot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output + "/" + label + ".png")

func overview() -> void:
	await select_mode("raster_lod")
	camera.far = 3600
	structures.view_distance = 3600
	structures.last_position = Vector3.INF
	camera.position = Vector3(0, 1500, 1350)
	camera.look_at(Vector3(0, 0, 0))
	for i in 45: await process_frame
	await screenshot("world_overview")
	camera.far = 640
	structures.view_distance = structures.FAR_DISTANCE

func finish(code: int = 0) -> void:
	stream.shutdown()
	if is_instance_valid(columns): columns.free(); columns = null
	# Release compute resources on the render thread before their shared textures.
	for i in 5: await process_frame
	world.free()
	await process_frame
	await process_frame
	quit(code)

func _process(delta: float) -> bool:
	if not is_instance_valid(stream) or not stream.is_inside_tree(): return false
	if interactive:
		var move := Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		var speed := 150.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 40.0
		camera.position += camera.basis * move * delta * speed
	stream.tick(camera)
	structures.update(camera)
	if columns != null: columns.draw(camera)
	if interactive and hud:
		hud.text = "STREAMED 2,048 × 2,048 m / " + mode + "\nWASD / Q,E · Shift speed · RMB yaw · 1–4 visit town/factory/port/base\nF1 raster LOD · F2 fine · F3 no culling · F4 quarter columns · F5 half · F6 full columns · F7 GPU terrain\n%.1f FPS · cache %d/%d · visible %d · queue %d · loaded/evicted %d/%d\nTerrain LOD %s · polygon sites %d · coarse fallback while loading" % [Engine.get_frames_per_second(), stream.resident.size(), Stream.CAPACITY, stream.visible_tiles, stream.queue.size() + stream.running.size(), stream.loaded_total, stream.evicted_total, str(stream.counts), structures.visible_sites]
	return false

func _input(event: InputEvent) -> void:
	if not interactive: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT: mouse_held = event.pressed
	if event is InputEventMouseMotion and mouse_held: camera.rotation.y -= event.relative.x * .004
	if event is InputEventKey and event.pressed:
		var visits := {KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3}
		var modes := {KEY_F1: "raster_lod", KEY_F2: "raster_fine", KEY_F3: "raster_no_cull", KEY_F4: "columns_quarter", KEY_F5: "columns_half", KEY_F6: "columns_full_reference", KEY_F7: "raster_analytic"}
		if visits.has(event.keycode): visit(visits[event.keycode])
		elif modes.has(event.keycode): select_mode(modes[event.keycode])
		elif event.keycode == KEY_ESCAPE: finish()
