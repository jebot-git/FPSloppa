extends Node3D
## Experimental fighter-compatible baked avatar. No collision or bot logic here.
const Art=preload("res://deathmatch/art.gd")
var target_xr_pose: Dictionary={}
var speed:=0.0
var movement:=Vector3.ZERO
var stance:="stand"
var collider_height:=1.7
var grounded:=true
var tracked_leg_animation:=false
var aim_pitch:=0.0
var unarmed:=false
var gun: Node3D
var offhand_gun: Node3D
var weapon_id:=-1
var dead:=false
var death_time:=0.0
var last_dead:=false
var reaction:=0.0
var reaction_clip:="attack"
var clip_name:=""
var clock:=0.0
var clips: Array=[]
var material: ShaderMaterial
var skin_mesh: MeshInstance3D
func setup(source: Array,metadata: Dictionary) -> void:
	clips=metadata.clips;material=source[1].duplicate()
	skin_mesh=MeshInstance3D.new();skin_mesh.mesh=source[0];skin_mesh.material_override=material;skin_mesh.rotation.y=PI;skin_mesh.custom_aabb=AABB(Vector3(-1,0,-1),Vector3(2,2,2));add_child(skin_mesh)
func set_first_person(_value: bool) -> void:pass
func fire(_offhand: bool=false) -> void:reaction=.35;reaction_clip="attack"
func hurt(_direction: Vector3,_strength: float) -> void:reaction=.3;reaction_clip="pain"
func set_weapon(value: int) -> void:
	if weapon_id==value:return
	weapon_id=value
	if is_instance_valid(gun):gun.free()
	gun=Art.weapon(value,2,"cs");gun.scale=Vector3.ONE*.48;add_child(gun)
func _process(delta: float) -> void:
	if dead!=last_dead:death_time=0;last_dead=dead;clip_name=""
	if dead:death_time+=delta
	reaction=maxf(0,reaction-delta)
	var next: String="death" if dead else reaction_clip if reaction>0 else "run" if speed>3.0 else "walk" if speed>.2 else "idle"
	if next!=clip_name:
		clip_name=next;clock=0
		var row: Dictionary=clips.filter(func(c):return c.name==next)[0]
		material.set_shader_parameter("clip_start",int(row.start));material.set_shader_parameter("clip_count",int(row.count));material.set_shader_parameter("clip_fps",float(row.fps));material.set_shader_parameter("clip_loop",bool(row.loop))
	clock+=delta;material.set_shader_parameter("animation_clock",clock)
	skin_mesh.scale.y=collider_height/1.7
	if is_instance_valid(gun):
		var grip:=Transform3D(Basis(Vector3.RIGHT,aim_pitch),Art.desktop_hand(false,aim_pitch,0))
		grip.origin.y-=1.65-collider_height;gun.transform=Art.held_transform(grip,weapon_id,.48,"cs");gun.visible=not unarmed and not dead
