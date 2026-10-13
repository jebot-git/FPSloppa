extends SceneTree
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
const Stream=preload("res://tools/streamed_heightfield/stream.gd")
const Scenery=preload("res://tools/voxel_battle/environment.gd")
var errors: Array=[]
var checks:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:errors.append(label);push_error(label)
func _initialize() -> void:run.call_deferred()
func settle(stream,camera) -> void:
	var deadline:=Time.get_ticks_msec()+60000
	while Time.get_ticks_msec()<deadline:
		stream.tick(camera)
		if stream.settled():return
		await process_frame
	check(false,"terrain/environment jobs settle")
func run() -> void:
	var world:=Node3D.new();root.add_child(world)
	var stream:=Stream.new();stream.source=Landscape.new();stream.coarse_segments=128;stream.min_height=Landscape.MIN_HEIGHT;stream.max_height=Landscape.MAX_HEIGHT;world.add_child(stream);stream.setup()
	var scenery:=Scenery.new();world.add_child(scenery);scenery.setup(stream)
	var camera:=Camera3D.new();world.add_child(camera);camera.current=true;camera.far=2200;camera.position=Vector3(-1000,Landscape.surface(-1000,-300).x+7,-300);camera.look_at(camera.position+Vector3(.8,-.08,-1))
	for kind in 3:
		check(scenery.meshes[kind][0].surface_get_array_index_len(0)>scenery.meshes[kind][2].surface_get_array_index_len(0),"LOD simplifies species "+str(kind))
	await settle(stream,camera);scenery.update(camera)
	check(scenery.visible_features>0,"environment visible near woodland")
	check(scenery.draw_calls<=9,"at most nine environment draws")
	var visible_culled:=scenery.visible_features
	scenery.culling_enabled=false;scenery.dirty=true;scenery.update(camera)
	check(scenery.visible_features>visible_culled,"frustum culling removes offscreen features")
	check(scenery.counts[0][0]>0 and scenery.counts[0][1]>0 and scenery.counts[0][2]>0,"three tree LODs active")
	var lod_triangles:=scenery.triangles
	scenery.set_mode("mesh");scenery.force_near=true;scenery.dirty=true;scenery.update(camera)
	check(scenery.triangles>lod_triangles,"distance LOD reduces triangles")
	var peaks:=scenery.peak_features
	var tile:=Vector2i(floori((camera.position.x+Landscape.EXTENT/2)/Landscape.TILE),floori((camera.position.z+Landscape.EXTENT/2)/Landscape.TILE))
	check(scenery.tiles.has(tile),"near tile loads")
	var before: Array=Landscape.features(tile)
	camera.position=Vector3(1200,Landscape.surface(1200,1100).x+7,1100);camera.look_at(camera.position+Vector3(-1,-.1,-1))
	await settle(stream,camera);scenery.update(camera)
	check(not scenery.tiles.has(tile),"environment evicts with terrain")
	check(stream.evicted_total>0,"stream eviction exercised")
	camera.position=Vector3(-1000,Landscape.surface(-1000,-300).x+7,-300);camera.look_at(camera.position+Vector3(.8,-.08,-1))
	await settle(stream,camera);scenery.update(camera)
	check(scenery.tiles.has(tile) and Landscape.features(tile)==before,"evicted feature placement regenerates identically")
	scenery.force_near=false;scenery.culling_enabled=true
	var matched:=-1
	for mode in ["mesh","billboard","svo","hybrid"]:
		scenery.set_mode(mode);scenery.update(camera)
		if matched<0:matched=scenery.visible_features
		check(scenery.visible_features==matched,"renderer workloads have identical visible instances")
	scenery.set_mode("svo")
	for i in 4:scenery.update(camera)
	check(scenery.peak_svo_uploads_per_frame<=Stream.UPLOADS_PER_FRAME,"SVO texture streaming obeys two-upload frame budget")
	check(scenery.svo_resident_bytes>0,"visible SVO resources load on demand")
	scenery.set_mode("hybrid");scenery.update(camera)
	check(scenery.svo_resident.is_empty(),"unused SVO GPU resources evict")
	for kind in 2:check(scenery.variants.billboard[kind][0].surface_get_material(0).billboard_keep_scale,"billboards preserve seeded tree scale")
	var total:=0
	for coord in stream.resident:
		check(scenery.tiles.has(coord),"environment follows terrain residency")
		if scenery.tiles.has(coord):total+=scenery.tiles[coord].rows.size()
	check(scenery.tiles.size()==stream.resident.size(),"no orphan environmental tiles")
	check(total==scenery.resident_features,"resident feature bookkeeping")
	check(stream.peak_resident<=Stream.CAPACITY and stream.peak_jobs<=Stream.MAX_JOBS,"shared bounded tile cache and worker jobs")
	check(scenery.peak_features<=Scenery.CAPACITY,"bounded feature memory")
	for group_family in scenery.groups:
		for group in group_family:check(group.multimesh.visible_instance_count<=Scenery.CAPACITY,"bounded instance buffer")
	var report:={"checks":checks,"errors":errors,"peak_tiles":stream.peak_resident,"peak_jobs":stream.peak_jobs,"peak_features":maxi(peaks,scenery.peak_features),"resident_features":scenery.resident_features,"draw_calls":scenery.draw_calls,"lod_counts":scenery.counts,"loaded":stream.loaded_total,"evicted":stream.evicted_total}
	DirAccess.make_dir_recursive_absolute("res://test-results/jungle-terrain")
	FileAccess.open("res://test-results/jungle-terrain/environment.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ENVIRONMENT_VALIDATION ",JSON.stringify(report));world.free();await process_frame;quit(0 if errors.is_empty() else 1)
