extends CharacterBody3D
const Art = preload("res://deathmatch/art.gd")
var gibbed:=false
var xr_pose: Dictionary={}
var avatar_hash := ""
var visual_velocity := Vector3.ZERO
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
var spawn_serial := -1

func setup(id: int, nickname: String, color: Color) -> void:
	peer_id = id
	name = "P_%d" % id
	collision_layer = 2
	collision_mask = 3
	floor_snap_length = .45
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

func simulate(input: Vector2, yaw: float, slow: bool, delta: float, jump: bool = false) -> void:
	rotation.y = yaw
	var direction := (basis * Vector3(input.x,0,input.y)).limit_length(1.0)
	var speed := 5.2 if slow else 9.4
	var acceleration := 65.0 if input.length()>.01 else 45.0
	velocity.x = move_toward(velocity.x,direction.x*speed,acceleration*delta)
	velocity.z = move_toward(velocity.z,direction.z*speed,acceleration*delta)
	velocity.y = -.2 if is_on_floor() else maxf(velocity.y-20.0*delta,-30.0)
	if quake_movement and jump and (in_water or is_on_floor() and not jump_held): velocity.y = 5.5 if in_water else 7.4
	if in_water: velocity.y = maxf(velocity.y,-2.0)
	jump_held = jump
	var step := .55 if quake_movement else .43
	var travel := Vector3(velocity.x,0,velocity.z)*delta
	if is_on_floor() and travel.length()>.001 and test_move(global_transform,travel):
		var raised := global_transform
		raised.origin.y += step
		if not test_move(global_transform,Vector3.UP*step) and not test_move(raised,travel):
			position.y += step
	move_and_slide()

func show_alive(alive: bool, is_local: bool) -> void:
	alive_state = alive
	local_player = is_local
	collision_layer = 2 if alive else 0
	if avatar:
		if not avatar_hash.is_empty():
			avatar.dead = not alive
			avatar.process_mode = Node.PROCESS_MODE_DISABLED if is_local else Node.PROCESS_MODE_INHERIT
		avatar.visible = alive and not is_local
	if label: label.visible = alive and not is_local

func set_avatar(model: Node3D, hash: String) -> void:
	if is_instance_valid(avatar): avatar.free()
	avatar = model
	avatar_hash = hash
	add_child(avatar)
	show_alive(alive_state,local_player)

func animate_fire() -> void:
	if avatar and not avatar_hash.is_empty(): avatar.fire()

func _process(_delta: float) -> void:
	if not avatar or avatar_hash.is_empty(): return
	avatar.target_xr_pose=xr_pose
	avatar.speed = Vector2(visual_velocity.x,visual_velocity.z).length()
	avatar.movement = basis.inverse()*visual_velocity
	avatar.aim_pitch = visual_pitch
	avatar.set_weapon(visual_weapon)
	avatar.visible = not gibbed and not local_player and (alive_state or avatar.death_time<2.5)
