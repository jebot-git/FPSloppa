extends Node3D
## One instanced draw, analytic falling particles, no particle bodies/networking.
## A small, cached overhead survey keeps precipitation above terrain and roofs.
const PROFILES={"ctf_katabatic":"snow","ctf_raindance":"rain",
 "ctf_t2_acidrain":"rain",
 "ctf_t2_confusco":"dust",
 "ctf_t2_desertofdeath":"dust",
 "ctf_t2_gorgon":"dust",
 "ctf_t2_iceridge":"snow",
 "ctf_t2_magmatic":"ash",
 "ctf_t2_ramparts":"snow",
 "ctf_t2_rollercoaster":"dust",
 "ctf_t2_sandstorm":"dust",
 "ctf_t2_shockridge":"snow",
 "ctf_t2_snowblind":"snow",
 "ctf_t2_subzero":"snow",
}
const CEILINGS={"ctf_katabatic":359.9,"ctf_raindance":319.9,
 "ctf_t2_acidrain":449.9,
 "ctf_t2_confusco":805.9625,
 "ctf_t2_desertofdeath":449.9,
 "ctf_t2_gorgon":449.9,
 "ctf_t2_iceridge":449.9,
 "ctf_t2_magmatic":449.9,
 "ctf_t2_ramparts":449.9,
 "ctf_t2_rollercoaster":449.9,
 "ctf_t2_sandstorm":449.9,
 "ctf_t2_shockridge":609.9,
 "ctf_t2_snowblind":508.7125,
 "ctf_t2_subzero":449.9,
}
const GRID:=8
const CELL:=4.0
const COUNT:=512
var kind:=""
var field: MultiMeshInstance3D
var material: ShaderMaterial
var roof_image: Image
var roof_texture: ImageTexture
var roof_cache: Dictionary={}
var grid_cell:=Vector2i(2147483647,2147483647)
var tick:=0.0
var sample_count:=0
var survey_ceiling:=1000.0
func configure(map: String) -> void:
	map=preload("res://deathmatch/maps/skies/catalog.gd").canonical(map)
	kind=str(PROFILES.get(map,""))
	if kind.is_empty():set_physics_process(false);return
	# BSP sky brushes can have collision. Start inside the authored sky seal.
	survey_ceiling=float(CEILINGS[map])
	material=ShaderMaterial.new();material.shader=preload("res://deathmatch/maps/weather.gdshader")
	material.set_shader_parameter("rain",kind=="rain")
	material.set_shader_parameter("airborne",kind in ["dust","ash"])
	material.set_shader_parameter("ash",kind=="ash")
	roof_image=Image.create(GRID,GRID,false,Image.FORMAT_RF);roof_image.fill(Color(1000,0,0))
	roof_texture=ImageTexture.create_from_image(roof_image);material.set_shader_parameter("roof_map",roof_texture)
	var mesh:=QuadMesh.new();mesh.size=Vector2.ONE;mesh.material=material
	var instances:=MultiMesh.new();instances.transform_format=MultiMesh.TRANSFORM_3D;instances.use_custom_data=true
	instances.mesh=mesh;instances.instance_count=COUNT;instances.custom_aabb=AABB(Vector3(-17,-13,-17),Vector3(34,26,34))
	var random:=RandomNumberGenerator.new();random.seed=74219
	for i in COUNT:
		instances.set_instance_transform(i,Transform3D.IDENTITY)
		instances.set_instance_custom_data(i,Color(random.randf(),random.randf(),random.randf(),random.randf()))
	field=MultiMeshInstance3D.new();field.multimesh=instances;field.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	field.gi_mode=GeometryInstance3D.GI_MODE_DISABLED;field.layers=1;add_child(field)
func update_roofs(focus: Vector3) -> void:
	var cell:=Vector2i(floori(focus.x/CELL)-GRID/2,floori(focus.z/CELL)-GRID/2)
	if cell==grid_cell:return
	grid_cell=cell
	var next: Dictionary={};var space:=get_world_3d().direct_space_state
	for z in GRID:
		for x in GRID:
			var key:=cell+Vector2i(x,z)
			var height: float=roof_cache.get(key,-1000.0)
			if not roof_cache.has(key):
				var p:=Vector3((key.x+.5)*CELL,survey_ceiling,(key.y+.5)*CELL)
				var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p,Vector3(p.x,-100,p.z),1))
				height=float(hit.position.y)+.15 if not hit.is_empty() else -1000.0;sample_count+=1
			next[key]=height;roof_image.set_pixel(x,z,Color(height,0,0))
	roof_cache=next;roof_texture.update(roof_image)
	material.set_shader_parameter("grid_origin",Vector2(cell)*CELL)
func _physics_process(delta: float) -> void:
	if not field:return
	var camera:=get_viewport().get_camera_3d()
	if not camera:field.hide();return
	field.show();global_position=camera.global_position
	material.set_shader_parameter("focus",global_position)
	tick-=delta
	if tick<=0:tick=.1;update_roofs(global_position)
