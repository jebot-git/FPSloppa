extends CharacterBody3D
const Art = preload("res://deathmatch/art.gd")
var frozen:=false
var ice: MeshInstance3D
var gibbed:=false
var spectator:=false
var xr_pose: Dictionary={}
var avatar_hash := ""
var visual_velocity := Vector3.ZERO
var blast_velocity:=Vector2.ZERO
var visual_pitch := 0.0
var visual_weapon := 2
var alive_state := true
var quake_movement := false
var in_water := false
var jump_held := false
var peer_id := 0
var avatar: Node3D
var label: Label3D
var target := Vector3.ZERO
var target_yaw := 0.0
var local_player := false
var local_body_visible := false
var spawn_serial := -1
var view_offset := 0.0

func setup(id: int, nickname: String, color: Color) -> void:
	peer_id = id
	name = "P_%d" % id
	collision_layer = 2
	collision_mask = 3
	floor_snap_length = .6
	floor_max_angle = deg_to_rad(50)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .30
	capsule.height = 1.65
	shape.shape = capsule
	shape.position.y = .83
	add_child(shape)
	if DisplayServer.get_name() == "headless": return
	avatar = Art.marine(color)
	add_child(avatar)
	label = Label3D.new()
	label.text = nickname
	label.position.y = 2.0
	label.font_size = 28
	label.pixel_size = .007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color.lightened(.4)
	label.no_depth_test = false
	add_child(label)

var speed_multiplier:=1.0
func simulate(input: Vector2, yaw: float, slow: bool, delta: float, jump: bool = false) -> void:
	rotation.y = yaw
	var direction := (basis * Vector3(input.x,0,input.y)).limit_length(1.0)
	var speed := (5.2 if slow else 9.4)*speed_multiplier
	var acceleration := 65.0 if input.length()>.01 else 45.0
	velocity.x-=blast_velocity.x;velocity.z-=blast_velocity.y
	blast_velocity=blast_velocity.move_toward(Vector2.ZERO,(24.0 if is_on_floor() and velocity.y<=0 else 2.0)*delta)
	velocity.x = move_toward(velocity.x,direction.x*speed,acceleration*delta)
	velocity.z = move_toward(velocity.z,direction.z*speed,acceleration*delta)
	velocity.x+=blast_velocity.x;velocity.z+=blast_velocity.y
	velocity.y = -.2 if is_on_floor() and velocity.y<=0 else maxf(velocity.y-20.0*delta,-30.0)
	if quake_movement and jump and (in_water or is_on_floor() and not jump_held): velocity.y = maxf(velocity.y,5.5 if in_water else 7.4)
	if in_water: velocity.y = maxf(velocity.y,-2.0)
	jump_held = jump
	var was_grounded:=is_on_floor()
	var previous_y:=position.y
	var stepping:=was_grounded and velocity.y<=0 and not in_water
	var step := .55 if quake_movement else .43
	var travel := Vector3(velocity.x,0,velocity.z)*delta
	if stepping: step_up(travel,step)
	move_and_slide()
	if stepping and is_on_floor() and absf(position.y-previous_y)<=step+.05:
		view_offset=clampf(view_offset+previous_y-position.y,-.55,.55)

func apply_blast(impulse: Vector3) -> void:
	if not impulse.is_finite() or spectator:return
	var previous:=blast_velocity
	blast_velocity=(blast_velocity+Vector2(impulse.x,impulse.z)).limit_length(20.0)
	velocity.x+=blast_velocity.x-previous.x;velocity.z+=blast_velocity.y-previous.y
	velocity.y=clampf(velocity.y+impulse.y,-30.0,20.0)

func step_up(travel: Vector3,height: float) -> void:
	if travel.length()<.001: return
	var obstacle:=KinematicCollision3D.new()
	if not test_move(global_transform,travel,obstacle): return
	if obstacle.get_normal().dot(Vector3.UP)>=cos(floor_max_angle): return
	var raised:=global_transform
	if test_move(raised,Vector3.UP*height): return
	raised.origin.y+=height
	# Probe beyond the rounded capsule edge even after a wall has slowed velocity.
	var probe:=travel.normalized()*maxf(travel.length(),.15)
	if test_move(raised,probe): return
	raised.origin+=probe
	var landing:=KinematicCollision3D.new()
	if not test_move(raised,Vector3.DOWN*(height+.05),landing): return
	if landing.get_normal().dot(Vector3.UP)<cos(floor_max_angle): return
	if landing.get_collider() is CharacterBody3D: return
	var rise: float=raised.origin.y+landing.get_travel().y-global_position.y
	if rise>.005 and rise<=height+.001:
		global_position.y+=rise
		velocity.y=0

func reset_view() -> void:
	view_offset=0

func show_alive(alive: bool, is_local: bool) -> void:
	alive=alive and not spectator
	alive_state = alive
	local_player = is_local
	collision_layer = 2 if alive else 0
	collision_mask=0 if spectator else 3
	if avatar:
		if not avatar_hash.is_empty():
			avatar.dead = not alive
			avatar.process_mode = Node.PROCESS_MODE_DISABLED if frozen or is_local and not local_body_visible else Node.PROCESS_MODE_INHERIT
			avatar.set_first_person(is_local and local_body_visible)
		avatar.visible = alive and (not is_local or local_body_visible)
	if label: label.visible = alive and not is_local

func set_avatar(model: Node3D, hash: String) -> void:
	if is_instance_valid(avatar): avatar.free()
	avatar = model
	avatar_hash = hash
	add_child(avatar)
	show_alive(alive_state,local_player)

func animate_fire(offhand: bool=false) -> void:
	if avatar and not avatar_hash.is_empty(): avatar.fire(offhand)

func set_local_body(value: bool) -> void:
	value=value and local_player and alive_state and not gibbed and not avatar_hash.is_empty()
	if local_body_visible==value: return
	local_body_visible=value
	show_alive(alive_state,local_player)

func _process(_delta: float) -> void:
	view_offset*=exp(-18.0*_delta)
	var unarmed: bool=get_parent().lobby.active()
	if avatar:
		if avatar_hash.is_empty():
			for weapon in avatar.find_children("WeaponModel","Node3D",true,false):weapon.visible=not unarmed
		else:
			avatar.unarmed=unarmed
			if unarmed:
				if is_instance_valid(avatar.gun):avatar.gun.hide()
				if is_instance_valid(avatar.offhand_gun):avatar.offhand_gun.hide()
	if frozen or not avatar or avatar_hash.is_empty(): return
	avatar.target_xr_pose=xr_pose
	avatar.speed = Vector2(visual_velocity.x,visual_velocity.z).length()
	avatar.movement = basis.inverse()*visual_velocity
	avatar.aim_pitch = visual_pitch
	avatar.set_weapon(visual_weapon)
	avatar.visible = not spectator and not gibbed and (not local_player or local_body_visible and alive_state) and (alive_state or avatar.death_time<2.5)

func set_frozen(value: bool, progress: float=0.0) -> void:
	if frozen!=value:
		frozen=value
		show_alive(alive_state,local_player)
	if value and not is_instance_valid(ice):
		ice=MeshInstance3D.new();var shape:=CapsuleMesh.new();shape.radius=.4;shape.height=1.85;ice.mesh=shape;ice.position.y=.9
		var mat:=Art.material(Color(.35,.8,1,.35),.2,.3);mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;ice.material_override=mat
		ice.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(ice)
	if is_instance_valid(ice):ice.visible=value and not local_player
	if is_instance_valid(ice):ice.scale=Vector3.ONE*(1.0-.04*progress/3.0)

var class_badge: Label3D
func set_class_badge(title: String,color: Color) -> void:
	if title.is_empty():
		if is_instance_valid(class_badge):class_badge.hide()
		return
	if not is_instance_valid(class_badge):
		class_badge=Label3D.new();class_badge.name="ClassBadge";add_child(class_badge)
		class_badge.position.y=2.32;class_badge.font_size=44;class_badge.pixel_size=.006
		class_badge.billboard=BaseMaterial3D.BILLBOARD_ENABLED;class_badge.outline_size=12
		class_badge.outline_modulate=Color("11151be6");class_badge.no_depth_test=false
	class_badge.text="[ "+title+" ]";class_badge.modulate=color
	class_badge.visible=alive_state and not spectator and not local_player

var cloak_material: ShaderMaterial
var cloak_meshes: Array=[]
var cloak_active:=false
var cloak_visibility:=1.0
var cloak_avatar: Node3D
func set_cloak_visual(active: bool,friendly: bool,tint: Color,delta: float) -> void:
	if not active:
		for entry in cloak_meshes:
			if is_instance_valid(entry.node):entry.node.material_override=entry.material;entry.node.cast_shadow=entry.shadow
		cloak_meshes.clear();cloak_active=false;cloak_visibility=1.0;cloak_avatar=null
		return
	if not cloak_active or cloak_avatar!=avatar:
		cloak_meshes.clear();cloak_avatar=avatar;cloak_active=true
		cloak_material=ShaderMaterial.new();cloak_material.shader=preload("res://deathmatch/avatars/cloak.gdshader")
		for mesh in avatar.find_children("*","MeshInstance3D",true,false):
			cloak_meshes.append({"node":mesh,"material":mesh.material_override,"shadow":mesh.cast_shadow})
			mesh.material_override=cloak_material;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Weapon meshes may be rebuilt after an avatar swap; cloak those too.
	for mesh in avatar.find_children("*","MeshInstance3D",true,false):
		if not cloak_meshes.any(func(entry):return entry.node==mesh):
			cloak_meshes.append({"node":mesh,"material":mesh.material_override,"shadow":mesh.cast_shadow})
			mesh.material_override=cloak_material;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cloak_visibility=move_toward(cloak_visibility,.22 if friendly else 0.0,delta*2.5)
	cloak_material.set_shader_parameter("visibility",cloak_visibility);cloak_material.set_shader_parameter("tint",tint)
	if label:label.visible=friendly and alive_state and not local_player
	if is_instance_valid(class_badge):class_badge.visible=friendly and alive_state and not local_player
