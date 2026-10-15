extends Node
## Offline ray-tested atlas/vertex bakes; runtime blends daylight, dusk, dawn and static night fixtures.
const ROOT="res://experimental-assets/jungle/lighting/"
const SkySource=preload("res://tools/voxel_battle/jungle_sky.gd")
const CYCLE_SECONDS:=1200.0
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
var phase_override:=-1.0
var reference_clock:=0.0
var reference_usec:=0
var daylight:=1.0
var sky_environment:Environment
var metadata:Dictionary={}
static var converted:Dictionary={}
func setup(map,graphics:bool=true) -> void:
	metadata=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"bake.json"))
	# Text sources may be absent when an export contains compiled scripts.
	if FileAccess.file_exists("res://tools/voxel_battle/landscape.gd"):
		assert(metadata.get("source_sha256","")==source_fingerprint(),"Jungle lighting bake is stale; run bake_lighting.gd")
	reference_usec=Time.get_ticks_usec()
	if not graphics:return
	RenderingServer.global_shader_parameter_set("jungle_extent",Landscape.EXTENT)
	RenderingServer.global_shader_parameter_set("jungle_light_atlas",load(ROOT+"irradiance.png"))
	RenderingServer.global_shader_parameter_set("jungle_dawn_atlas",load(ROOT+"dawn.png"))
	RenderingServer.global_shader_parameter_set("jungle_baked_enabled",true)
	var parents:Array=[map.get_parent()]
	if map.get_parent().get_parent():parents.append(map.get_parent().get_parent())
	var siblings:Array=[]
	for parent in parents:siblings.append_array(parent.get_children())
	for child in siblings:
		if child is Light3D:child.visible=false;child.light_energy=0.0
		if child is WorldEnvironment:sky_environment=child.environment
	if sky_environment:
		sky_environment.background_mode=Environment.BG_SKY;sky_environment.ambient_light_energy=0
		var sky:=Sky.new();var material:=ShaderMaterial.new();material.shader=preload("res://tools/voxel_battle/jungle_sky.gdshader");material.set_shader_parameter("skybox",load(ROOT+"skybox.png"));sky.sky_material=material;sky_environment.sky=sky
		sky_environment.ambient_light_source=Environment.AMBIENT_SOURCE_DISABLED
		sky_environment.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED
		sky_environment.ssao_enabled=false;sky_environment.sdfgi_enabled=false;sky_environment.glow_enabled=false
	apply()
func cycle_time() -> float:return reference_clock+(Time.get_ticks_usec()-reference_usec)/1000000.0
func synchronize(seconds:float) -> void:reference_clock=seconds;reference_usec=Time.get_ticks_usec()
static func day_weight(seconds:float) -> float:
	var weights:=SkySource.sun_weights(seconds,CYCLE_SECONDS)
	return clampf(weights.x+weights.y+weights.z,0,1)
func light_fraction() -> float:return phase_override if phase_override>=0 else day_weight(cycle_time())
func _process(_delta:float) -> void:
	if DisplayServer.get_name()!="headless":apply()
func sky_time() -> float:return cycle_time() if phase_override<0 else (0.0 if phase_override>.5 else CYCLE_SECONDS*.5)
func apply() -> void:
	daylight=light_fraction()
	RenderingServer.global_shader_parameter_set("jungle_day_mix",daylight)
	var seconds:=sky_time()
	var pair:=SkySource.stage_pair(seconds,CYCLE_SECONDS);var colors:Array=metadata.sky_average
	var a:Array=colors[int(pair.x)];var b:Array=colors[int(pair.y)]
	RenderingServer.global_shader_parameter_set("jungle_sky_stage",pair)
	RenderingServer.global_shader_parameter_set("jungle_sky_color",Vector3(a[0],a[1],a[2]).lerp(Vector3(b[0],b[1],b[2]),pair.z))
	RenderingServer.global_shader_parameter_set("jungle_sun_mix",SkySource.sun_weights(seconds,CYCLE_SECONDS))
static func source_fingerprint() -> String:
	var files=["landscape.gd","architecture.gd","outer_architecture.gd","hydrology.gd","waterways.gd","environment.gd","bake_lighting.gd","jungle_sky.gd","light_fixtures.gd"]
	var fingerprint:=""
	for file in files:fingerprint+=FileAccess.get_sha256("res://tools/voxel_battle/"+file)
	return fingerprint.sha256_text()
static func surface(original:Material,baked_vertices:bool=false) -> Material:
	if original is ShaderMaterial:return original
	var key:Array=[original,baked_vertices]
	if converted.has(key):return converted[key]
	var result:=ShaderMaterial.new()
	var source:=original as BaseMaterial3D
	if source and source.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED:return original
	if source and source.billboard_mode!=BaseMaterial3D.BILLBOARD_DISABLED:
		result.shader=preload("res://tools/voxel_battle/baked_card.gdshader");result.set_shader_parameter("albedo",source.albedo_texture)
	else:
		result.shader=preload("res://tools/voxel_battle/baked_surface.gdshader")
		result.set_shader_parameter("baked_vertices",baked_vertices)
		if source:
			result.set_shader_parameter("tint",source.albedo_color);result.set_shader_parameter("vertex_tint",source.vertex_color_use_as_albedo)
			result.set_shader_parameter("textured",source.albedo_texture!=null)
			if source.albedo_texture:result.set_shader_parameter("albedo",source.albedo_texture)
	converted[key]=result;return result
static func convert_mesh(mesh:Mesh) -> void:
	for surface_index in mesh.get_surface_count():
		var original:=mesh.surface_get_material(surface_index)
		if original is BaseMaterial3D:mesh.surface_set_material(surface_index,surface(original))
static func convert_node(node:Node) -> void:
	if node is MeshInstance3D:
		if node.material_override is BaseMaterial3D:node.material_override=surface(node.material_override)
		elif node.mesh:convert_mesh(node.mesh)
		if node.mesh:
			for index in node.mesh.get_surface_count():
				var override:Material=node.get_surface_override_material(index)
				if override is BaseMaterial3D:node.set_surface_override_material(index,surface(override))
	if node is MultiMeshInstance3D and node.multimesh:convert_mesh(node.multimesh.mesh)
	for child in node.get_children():convert_node(child)

var fixture_groups:Array=[]
func fixtures(map) -> void:
	var box:=BoxMesh.new();box.size=Vector3(.48,.06,.32)
	var material:=ShaderMaterial.new();material.shader=preload("res://tools/voxel_battle/fixture.gdshader");box.material=material
	for kind in 11:
		var rows:Array=metadata.lamps.filter(func(row):return int(row.kind)==kind)
		var group:=MultiMeshInstance3D.new();group.name="BakedFixtureLenses_%d"%kind;group.position=Landscape.CENTERS[kind]
		group.multimesh=MultiMesh.new();group.multimesh.transform_format=MultiMesh.TRANSFORM_3D;group.multimesh.mesh=box;group.multimesh.instance_count=rows.size()
		for i in rows.size():
			var point:Array=rows[i].position;var scale:=Vector3(2,1,1.5) if rows[i].type=="floodlight" else Vector3.ONE
			group.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(scale),Vector3(point[0],point[1],point[2])-group.position))
		group.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;map.add_child(group);fixture_groups.append(group)
func update_fixtures(structures) -> void:
	# Follow the existing structure residency/frustum/LOD decision exactly.
	for kind in fixture_groups.size():fixture_groups[kind].visible=structures.counts.size()>kind and (structures.counts[kind][0]+structures.counts[kind][1]+structures.counts[kind][2]>0)

func _exit_tree() -> void:
	if DisplayServer.get_name()!="headless":RenderingServer.global_shader_parameter_set("jungle_baked_enabled",false)
