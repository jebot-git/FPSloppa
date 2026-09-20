extends Node3D
## Identical barriers on the district authority and the predicting client.
const Rules=preload("res://deathmatch/conquest/rules.gd")
const Capacity=preload("res://deathmatch/conquest/capacity.gd")
var signature:=""
func update(zone: int,counts: Array) -> void:
	if zone not in range(16) or counts.size()!=16:return
	var full: Array=Rules.neighbors(zone).filter(func(next):return int(counts[next])>=Capacity.LIMIT)
	var key:=str(zone)+str(full)
	if key==signature:return
	signature=key
	for child in get_children():remove_child(child);child.queue_free()
	for target in full:
		var direction: Vector3=(Rules.center(target)-Rules.center(zone)).normalized()
		var midpoint: Vector3=(Rules.center(target)+Rules.center(zone))*.5
		var body:=StaticBody3D.new();body.name="FullDistrict%d"%target;body.collision_layer=1;body.collision_mask=0;add_child(body)
		body.position=midpoint-direction*.12+Vector3.UP*127
		var shape:=CollisionShape3D.new();var box:=BoxShape3D.new()
		box.size=Vector3(.1,256,250) if absf(direction.x)>.5 else Vector3(250,256,.1)
		shape.shape=box;body.add_child(shape)
		if DisplayServer.get_name()=="headless":continue
		var screen:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(24,16);screen.mesh=quad
		var material:=ShaderMaterial.new();material.shader=load("res://deathmatch/conquest/gate.gdshader");material.set_shader_parameter("tint",Color(1,.15,.08));screen.material_override=material
		screen.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;screen.position=midpoint-direction*.2+Vector3.UP*7.95;screen.rotation.y=atan2(direction.x,direction.z);add_child(screen)
		var label:=Label3D.new();label.text="DISTRICT %02d FULL · 16 / 16\nTRANSIT DISABLED"%(target+1);label.font_size=48;label.pixel_size=.022;label.modulate=Color(1,.3,.15)
		label.position=midpoint-direction*.3+Vector3.UP*5;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;add_child(label)
