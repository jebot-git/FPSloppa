extends SceneTree
const Loader=preload("res://deathmatch/maps/loader.gd")
const Contents=preload("res://deathmatch/maps/contents.gd")
const OUT="res://test-results/map-limits/"
var records: Array=[]
var failures: Array=[]
var checks:=0
var stage: Node3D
func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run() -> void:
	stage=Node3D.new();root.add_child(stage)
	var fixtures: Array=JSON.parse_string(FileAccess.get_file_as_string(OUT+"fixtures.json"))
	for row in fixtures:
		var path: String=OUT+row.name+".bsp";var error:=Loader.validate(path)
		row.validation=error;row.loaded=false
		if row.maximum_units>10_000_000:
			check(error=="Invalid BSP vertex coordinate.","Coordinate beyond limit rejected");records.append(row);continue
		check(error.is_empty(),row.name+": validator accepts extent")
		var began:=Time.get_ticks_usec();var scene:=Loader.read(path);row.load_ms=(Time.get_ticks_usec()-began)/1000.0
		row.loaded=scene!=null;check(scene!=null,row.name+": importer loads room")
		if not scene:records.append(row);continue
		stage.add_child(scene);await physics_frame;await physics_frame
		var bounds:=AABB();var first:=true
		for node in scene.find_children("*","MeshInstance3D",true,false):
			var box: AABB=node.global_transform*node.get_aabb();bounds=box if first else bounds.merge(box);first=false
		row.imported_horizontal_m=[bounds.size.x,bounds.size.z]
		check(absf(bounds.size.x-row.side_m)<.1 and absf(bounds.size.z-row.side_m)<.1,row.name+": imported extent retained")
		var contents:=Contents.new();row.contents_loaded=contents.open(path)
		row.contents_center=contents.at(Vector3(0,1,0))
		check(row.contents_loaded and row.contents_center==-1,row.name+": empty interior BSP contents")
		var hits: Array=[]
		for offset in [0.0,float(row.maximum_units)/32.0-2.0]:
			var at:=Vector3(offset,2,offset)
			var hit:=stage.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at,at-Vector3.UP*4,1))
			hits.append({"offset_m":offset,"floor_hit":not hit.is_empty(),"hit_y":float(hit.position.y) if not hit.is_empty() else null})
		row.floor_queries=hits
		for hit in hits:check(hit.floor_hit and absf(hit.hit_y)<.001,row.name+": floor collision at "+str(hit.offset_m))
		var edge:=float(row.maximum_units)/32.0
		var encoded:=PackedByteArray();encoded.resize(4);encoded.encode_float(0,edge);encoded.encode_u32(0,encoded.decode_u32(0)+1)
		row.float32_spacing_m=encoded.decode_float(0)-Vector3(edge,0,0).x
		row.actual_1mm_step_m=(Vector3(edge+.001,0,0)-Vector3(edge,0,0)).x
		row.actual_2mm_bias_m=(Vector3(edge+.002,0,0)-Vector3(edge,0,0)).x
		row.actual_1cm_step_m=(Vector3(edge+.01,0,0)-Vector3(edge,0,0)).x
		row.vector_serialized_bytes=var_to_bytes(Vector3.ZERO).size()
		records.append(row);scene.free();await physics_frame
	var legacy:=OUT+"legacy_2psb.bsp"
	var legacy_error:=Loader.validate(legacy);var legacy_scene:=Loader.read(legacy)
	var legacy_result:={"validation":legacy_error,"loaded":legacy_scene!=null}
	if legacy_scene:legacy_scene.free()
	var report:={"fixtures":records,"legacy_2psb":legacy_result,"failures":failures,"checks":checks,"engine":Engine.get_version_info(),"max_file_bytes":Loader.MAX_BYTES,"unit_scale_m":Loader.SCALE}
	FileAccess.open(OUT+"report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("MAP_LIMITS_RESULT ",JSON.stringify(report));stage.free();quit(0 if failures.is_empty() else 1)
