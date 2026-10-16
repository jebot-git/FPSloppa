extends SceneTree
const Map=preload("res://tools/voxel_battle/map.gd")
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
const Grass=preload("res://tools/voxel_battle/grass.gd")
var checks:=0
var errors: Array=[]
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:errors.append(label);push_error(label)
func _initialize() -> void:run.call_deferred()
func settle(map,camera) -> void:
	var deadline:=Time.get_ticks_msec()+120000
	while Time.get_ticks_msec()<deadline:
		map.update_view(camera)
		if map.terrain.settled():map.grass.dirty=true;map.grass.update(camera);return
		await process_frame
	check(false,"stream settles")
func run() -> void:
	var output:="res://test-results/jungle-hybrid-undergrowth"
	var args:=OS.get_cmdline_user_args()
	if args.has("--output"):output=args[args.find("--output")+1]
	var map:=Map.new();root.add_child(map);map.build(true,false)
	var camera:=Camera3D.new();map.add_child(camera);camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;camera.fov=94;camera.far=2200;camera.current=true
	camera.position=Vector3(-1000,Landscape.surface(-1000,-300).x+1.7,-300);camera.look_at(camera.position+Vector3(.8,-.08,-1))
	await settle(map,camera)
	var grass=map.grass
	check(map.environment.render_mode=="hybrid","hybrid tree default preserved")
	check(grass.visible_tufts>0,"near-field grass renders at human eye height")
	check(grass.draw_calls<=12 and grass.visible_tufts<=Grass.CAPACITY,"draw/total instance caps")
	check(grass.counts[0]+grass.counts[3]>0 and grass.counts[1]+grass.counts[4]>0 and grass.counts[2]+grass.counts[5]+grass.counts[8]+grass.counts[11]>0,"near/middle meshes and far cards visible")
	var stable_buffers:Array=grass.buffers.duplicate(true)
	var stable_refreshes:int=grass.refreshes
	camera.rotate_y(PI*.5);grass.update(camera)
	check(grass.refreshes==stable_refreshes,"head rotation does not trigger a grass rebuild")
	grass.dirty=true;grass.update(camera)
	check(grass.buffers==stable_buffers,"forced rebuild preserves vegetation selection after head rotation")
	camera.rotate_y(-PI*.5)
	stable_buffers=grass.buffers.duplicate(true);stable_refreshes=grass.refreshes
	grass.selection_enabled=false;grass.dirty=true;camera.position.x+=2;grass.update(camera)
	check(grass.refreshes==stable_refreshes and grass.update_ms==0,"diagnostic selection freeze skips work despite dirty tiles and movement")
	check(grass.buffers==stable_buffers and grass.visible_tufts>0,"diagnostic freeze retains rendered grass buffers")
	grass.selection_enabled=true;camera.position.x-=2;grass.update(camera)
	check(grass.refreshes==stable_refreshes+1,"resuming selection processes dirty vegetation")
	var held_hash:String=grass.drawing_hash();var held_count:int=grass.submitted_tufts
	stable_refreshes=grass.refreshes;grass.submit_enabled=false;grass.dirty=true;camera.position.x+=2;grass.update(camera)
	check(grass.refreshes==stable_refreshes+1,"selection compute continues when GPU submission is held")
	check(grass.drawing_hash()==held_hash and grass.submitted_tufts==held_count and held_count>0,"selection compute retains exact populated GPU buffers and bounds")
	grass.selection_enabled=false;grass.dirty=true;camera.position.x+=2;grass.update(camera)
	check(grass.refreshes==stable_refreshes+1 and grass.drawing_hash()==held_hash,"selection off retains the same populated drawing as selection on")
	grass.selection_enabled=true;grass.submit_enabled=true;camera.position.x-=4;grass.update(camera)
	check(grass.submitted_tufts==grass.visible_tufts,"normal submission resumes with actual drawn count")
	var baseline: int=grass.visible_tufts
	var total:=0;var species_counts:=[0,0,0,0]
	for coord in grass.tiles:
		var rows: PackedVector4Array=grass.tiles[coord].rows;total+=rows.size()
		for row in rows:species_counts[Grass.species(row)]+=1
		check(rows.size()<=1024,"worker candidate cap per tile")
		check(grass.tiles[coord].kinds.size()==rows.size(),"cached species covers every streamed row")
	check(species_counts[0]>total*.80 and species_counts[1]>0 and species_counts[2]+species_counts[3]>0,"tall grass dominates, with occasional mixed undergrowth patches")
	check(total==grass.resident_tufts and grass.tiles.size()==map.terrain.resident.size(),"grass follows terrain residency")
	var coordinate:=Landscape.bin_key(Vector2(camera.position.x,camera.position.z))
	var data:Dictionary=map.terrain.source.generate_tile(coordinate)
	check(data.grass==Landscape.grass_features(coordinate,data.heights.to_float32_array()),"grass regenerates deterministically")
	for row: Vector4 in data.grass:
		check(Landscape.planting_allowed(Vector2(row.x,row.z)),"grass clears roads sites water")
		check(absf(row.y+.03-Landscape.surface(row.x,row.z).x)<.2,"grass sits on worker height samples")
	for index in 12:
		var lod:=index%3;var group:MultiMeshInstance3D=grass.groups[index]
		check(group.multimesh.instance_count==Grass.GROUP_CAPS[index],"GPU allocation matches bounded group budget")
		var material=group.multimesh.mesh.surface_get_material(0)
		check(group.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"undergrowth has no shadow pass")
		check(count_nodes(group)==0,"undergrowth creates no collision objects/shapes")
		if lod==2:
			check((material is ShaderMaterial and material.shader.resource_path.ends_with("baked_card.gdshader")) or (material is BaseMaterial3D and material.billboard_mode==BaseMaterial3D.BILLBOARD_FIXED_Y and material.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR),"far LOD uses fixed-Y cutout cards")
			check((material.get_shader_parameter("albedo") if material is ShaderMaterial else material.albedo_texture).get_image().has_mipmaps(),"billboard atlas has mipmaps")
			check(group.multimesh.mesh.surface_get_array_index_len(0)==6,"far cards have two triangles")
		else:
			check((material is ShaderMaterial and material.shader.resource_path.ends_with("baked_surface.gdshader")) or (material is BaseMaterial3D and material.vertex_color_is_srgb and material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED),"near/middle foliage uses opaque vertex-lit geometry")
			var bounds: AABB=group.multimesh.mesh.get_aabb()
			check(bounds.size.y>1.0 and bounds.size.z>1.0,"waist-high canopy and bushes are volumes, not flat stars")
		for i in grass.counts[index]:
			var b:PackedFloat32Array=grass.buffers[index]
			var position:=Vector3(b[i*12+3],b[i*12+7],b[i*12+11])
			check(position.distance_to(camera.position)<grass.view_distance,"submitted foliage stays within requested distance")
	check(grass.max_submitted_distance>Grass.VIEW_DISTANCE*.8,"far cards reach the requested extended range")
	check(count_nodes(grass)==0,"complete undergrowth subtree is collision-free")
	for distance in [24,64,96,144]:
		grass.set_distance(distance);grass.update(camera)
		check(grass.visible_tufts<=Grass.CAPACITY and grass.draw_calls<=12,"extended-distance workload remains bounded")
	grass.set_distance(Grass.VIEW_DISTANCE);grass.update(camera)
	var saved_tiles: Dictionary=grass.tiles
	var saved_native=grass.native_world
	var rows:=PackedVector4Array()
	for i in Grass.CAPACITY+200:rows.append(Vector4(0,85,-2,.3))
	var synthetic_kinds:=PackedByteArray();synthetic_kinds.resize(rows.size());synthetic_kinds.fill(Grass.species(rows[0]))
	grass.native_world=preload("res://deathmatch/native/world.gd").create()
	grass.tiles={Vector2i(44,44):{"rows":rows,"kinds":synthetic_kinds,"bounds":AABB(Vector3(-16,84,-16),Vector3(32,3,32))}}
	if grass.native_world:grass.native_world.grass_load(Vector2i(44,44),rows,synthetic_kinds,grass.tiles[Vector2i(44,44)].bounds)
	camera.position=Vector3(0,86.7,0);camera.look_at(camera.position+Vector3(0,-.2,-1));grass.dirty=true;grass.update(camera)
	check(grass.visible_tufts==Grass.GROUP_CAPS[Grass.species(rows[0])*3],"dense single-species workload saturates its reserved near cap")
	var buffer: PackedFloat32Array=grass.buffers[Grass.species(rows[0])*3]
	var transform:=Transform3D(Basis.IDENTITY,Vector3(buffer[3],buffer[7],buffer[11]))
	check(transform.origin.distance_to(Vector3(0,85,-2))<.001,"contiguous buffer transform layout")
	var refreshed: int=grass.refreshes
	camera.position.x+=.1;grass.update(camera)
	check(grass.refreshes==refreshed and grass.update_ms==0,"movement refresh rate limited to 30 Hz")
	camera.position.y+=40;grass.dirty=true;grass.update(camera)
	check(grass.visible_tufts==0 and grass.draw_calls==0,"flight/overview grass suppressed")
	grass.tiles=saved_tiles;grass.native_world=saved_native
	grass.set_enabled(false);grass.update(camera)
	check(grass.visible_tufts==0 and grass.draw_calls==0,"off mode submits zero instances")
	for group in grass.groups:check(not group.visible and group.multimesh.visible_instance_count==0,"off mode hides buffers")
	grass.set_enabled(true)
	camera.position=Vector3(1200,Landscape.surface(1200,1100).x+1.7,1100);camera.look_at(camera.position+Vector3(-1,-.1,-1))
	await settle(map,camera)
	check(not grass.tiles.has(coordinate),"grass evicts with terrain")
	camera.position=Vector3(-1000,Landscape.surface(-1000,-300).x+1.7,-300);camera.look_at(camera.position+Vector3(.8,-.08,-1))
	await settle(map,camera)
	check(grass.tiles[coordinate].rows==data.grass,"reload preserves exact grass placement")
	check(grass.visible_tufts==baseline,"return view preserves culled workload")
	var report:={"checks":checks,"errors":errors,"resident_species":species_counts,"capacity":Grass.CAPACITY,"distance_m":Grass.VIEW_DISTANCE,"max_draws_per_eye":12,"visible_tufts":grass.visible_tufts,"lod_counts":grass.counts,"triangles":grass.triangles,"resident_tufts":grass.resident_tufts,"peak_resident_tufts":grass.peak_resident_tufts,"peak_tiles":map.terrain.peak_resident,"peak_jobs":map.terrain.peak_jobs,"loaded":map.terrain.loaded_total,"evicted":map.terrain.evicted_total}
	DirAccess.make_dir_recursive_absolute(output)
	FileAccess.open(output+"/validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("GRASS_VALIDATION ",JSON.stringify(report));map.terrain.shutdown();map.free();await process_frame;quit(0 if errors.is_empty() else 1)

func count_nodes(node:Node) -> int:
	var count:=1 if node is CollisionObject3D or node is CollisionShape3D or node is CollisionPolygon3D else 0
	for child in node.get_children():count+=count_nodes(child)
	return count
