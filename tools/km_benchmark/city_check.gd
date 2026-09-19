extends SceneTree
const BASE="res://maps/Benchmark1km/"
func _initialize():run.call_deferred()
func run() -> void:
	var scene: Node3D=load(BASE+"zones-lightmap1.scn").instantiate();root.add_child(scene)
	var art:=scene.get_node("CityPresentation");var gates:=0;var bad_vertices:=0;var night_materials:=0
	assert(art.find_children("*","CollisionObject3D",true,false).is_empty())
	assert(art.find_children("*","Light3D",true,false).is_empty())
	var alpha:=RegEx.new();assert(alpha.compile("\\bALPHA\\s*=")==OK)
	for gate in art.find_children("OpaqueGate_*","MeshInstance3D",true,false):
		assert(gate.get_meta("walkthrough",false));assert(gate.mesh.size==Vector2(24,16))
		var shader: Shader=gate.material_override.shader
		assert(shader.code.contains("depth_draw_opaque") and alpha.search(shader.code)==null)
		gates+=1
	assert(gates==48)
	for node in scene.find_children("*","MeshInstance3D",true,false):
		for surface in node.mesh.get_surface_count():
			var m: Material=node.get_active_material(surface)
			if m is ShaderMaterial and m.shader.resource_path=="res://deathmatch/maps/baked_light.gdshader":
				assert(m.get_shader_parameter("night_lighting")==true);night_materials+=1
			if m and str(m.get_meta("bsp_texture_name",""))=="_bad_texture_":bad_vertices+=node.mesh.surface_get_array_len(surface)
	assert(bad_vertices==0 and night_materials>0 and scene.get_meta("night_lighting",false))
	var world:=WorldEnvironment.new();world.environment=Environment.new();root.add_child(world)
	preload("res://deathmatch/conquest/presentation.gd").apply(root)
	assert(world.environment.sky.sky_material.panorama.resource_path.ends_with("night.png"))
	assert(world.environment.fog_sky_affect<.2)
	var report:={"opaque_walkthrough_gate_faces":gates,"gate_openings":24,"decoration_collision_bodies":0,"decoration_realtime_lights":0,"unreviewed_texture_vertices":bad_vertices,"night_sky":true,"night_surface_batches":night_materials,"bsp_sha256":FileAccess.get_sha256(BASE+"prototype_km1.bsp")}
	DirAccess.make_dir_recursive_absolute("res://test-results/city")
	FileAccess.open("res://test-results/city/checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("CITY_CHECK_PASS ",JSON.stringify(report));scene.free();world.free();quit()
