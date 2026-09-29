extends SceneTree
const Loader=preload("res://deathmatch/maps/loader.gd")
const Builder=preload("res://tools/lighting_experiment/build_static_assets.gd")
const Filtering=preload("res://deathmatch/maps/filtering.gd")
const Compressor=preload("res://tools/lighting_experiment/compress_static.gd")
const KEY="ctf_katabatic"
func _initialize():run.call_deferred()
func run() -> void:
	var helper=Builder.new();var level:=Loader.read("res://maps/"+KEY+".bsp");assert(level!=null)
	Filtering.new().apply(level,2,true)
	assert(level.get_meta("baked_light_invalid_faces")==0 and level.get_meta("baked_light_overflow_faces")==0)
	var expected: Array=helper.geometry(level)
	var raw: String="res://maps/cache/"+KEY+"-lightmap1.scn"
	helper.save(level,raw);assert(DirAccess.copy_absolute(raw,"res://maps/cache/"+KEY+".scn")==OK)
	var alias: String=raw.get_basename()+"-textures-"+preload("res://deathmatch/maps/texture_replacements/dictionary.gd").version()+".scn"
	assert(DirAccess.copy_absolute(raw,alias)==OK)
	var report: Dictionary={"bsp_sha256":FileAccess.get_sha256("res://maps/"+KEY+".bsp"),"packing":level.get_meta("lightmap_packing"),"geometry_hashes":expected.size(),"codecs":[]}
	root.add_child(level)
	# Runtime station rails also obstruct walking paths. Include their exact
	# production shapes in navigation, without duplicating them in scene caches.
	var fixtures=preload("res://deathmatch/tribes/stations.gd").new();level.add_child(fixtures)
	for node in level.find_children("*","Node3D",true,false):
		if node.get_script()==preload("res://deathmatch/maps/entity.gd") and node.attributes.get("classname","") in ["info_tribes_inventory","info_tribes_ammo"]:
			fixtures.fixture({"position":node.global_position-Vector3.UP*.70},deg_to_rad(float(node.attributes.get("angle",0))))
	var mesh=preload("res://deathmatch/bots.gd").new_mesh()
	# Ground navigation only; keep paths inside the physical mission boundary.
	mesh.filter_baking_aabb=AABB(Vector3(-750,-24,-694),Vector3(1500,384,1388))
	mesh.cell_size=.7;mesh.cell_height=.2
	mesh.agent_radius=.5;mesh.agent_height=1.8;mesh.agent_max_climb=.4
	mesh.set_meta("merge_rasterizer_cell_scale",.01)
	var data:=NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh,data,level)
	NavigationServer3D.bake_from_source_geometry_data(mesh,data)
	assert(mesh.get_polygon_count()>0)
	report.navigation_cleanup=preload("res://tools/raindance/navigation_cleanup.gd").clean(mesh)
	assert(report.navigation_cleanup.unresolved_edges==0,"Overlapping ground navigation needs inspection")
	assert(ResourceSaver.save(mesh,"res://maps/navigation/"+KEY+".res",ResourceSaver.FLAG_COMPRESS)==OK)
	report.ground_navigation_polygons=mesh.get_polygon_count()
	FileAccess.open("res://maps/Katabatic/navigation-sha256.txt",FileAccess.WRITE).store_line(report.bsp_sha256)
	level.free()
	for codec in ([] if "--raw-only" in OS.get_cmdline_user_args() else ["bc7","astc4"]):
		level=ResourceLoader.load(raw,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate()
		var stats:=Compressor.new().apply(level,codec);assert(helper.geometry(level)==expected)
		var target:=Loader.compressed_scene_path(raw,codec);helper.save(level,target);level.free()
		assert(DirAccess.copy_absolute(target,Loader.compressed_scene_path(alias,codec))==OK)
		var packed: PackedScene=ResourceLoader.load(target,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE)
		assert(Loader.cache_matches(packed,report.bsp_sha256,codec));stats.path=target;report.codecs.append(stats)
	FileAccess.open("res://test-results/st-katabatic/prepare-assets.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	helper.free();print("KATABATIC_PREPARE_PASS ",JSON.stringify(report));quit()
