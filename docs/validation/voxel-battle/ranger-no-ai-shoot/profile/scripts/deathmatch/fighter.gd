extends CharacterBody3D
signal movement_sound(kind: String,where: Vector3)
const Art = preload("res://deathmatch/art.gd")
const QuakeMovement = preload("res://deathmatch/movement/quake.gd")
const Jetpack=preload("res://deathmatch/conquest/jetpack.gd")
var jetpack_state: Dictionary=Jetpack.fresh()
var jetpack_enabled:=false
var jetpack_blocked:=false
var jetpack_requested:=false
var jetpack_model: Node3D
var frozen:=false
var ice: MeshInstance3D
var frozen_label: Label3D
var frost_material: ShaderMaterial
var frost_originals: Array=[]
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
var collision_height:=1.65
var stance:="stand"
var visual_grounded:=true
var tracked_leg_animation:=false
const CROUCH_SPEED:=.55
const PRONE_SPEED:=.18
var body_shape: CollisionShape3D
var water_surface:=false
var water_jump_used:=false
var water_deep_time:=0.0
var water_exit_grace:=0.0
var water_boost:=0.0
var was_in_water:=false
var in_water := false
var underwater:=false
var air_left:=12.0
var jump_held := false
var jump_queued := false
var peer_id := 0
var avatar: Node3D
var label: Label3D
var target := Vector3.ZERO
var target_yaw := 0.0
var local_player := false
var local_body_visible := false
var spawn_serial := -1
var view_offset := 0.0
var floor_grace:=0.0
# A swept step can rest on a tread edge before move_and_slide reports a floor.
var stepped_last_frame:=false
var visual_reset_until:=-1
var prediction=preload("res://deathmatch/movement/prediction.gd").new()
var prediction_view_offset:=Vector3.ZERO

func setup(id: int, nickname: String, color: Color) -> void:
	process_priority=-20
	peer_id = id
	name = "P_%d" % id
	collision_layer = 2
	collision_mask = 3
	# World lifts can carry players; other player capsules must not carry them on respawn.
	platform_floor_layers = 1
	floor_snap_length = .6
	floor_max_angle = deg_to_rad(50)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .30
	capsule.height = 1.65
	body_shape=shape
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
func is_supported() -> bool:
	return is_on_floor() or stepped_last_frame

func torso_height() -> float:return maxf(.25,minf(1.25,collision_height-.40))
func damage_yaw() -> float:
	return rotation.y+preload("res://deathmatch/vr/body_basis.gd").head_yaw(xr_pose)
func eye_height() -> float:return minf(1.48,collision_height-.17)
func stance_speed() -> float:return PRONE_SPEED if stance=="prone" else CROUCH_SPEED if stance=="crouch" else 1.0
func accuracy_scale() -> float:
	if not is_supported() or in_water:return 1.0
	return .45 if stance=="prone" else .75 if stance=="crouch" else 1.0
func configure_jetpack(enabled: bool,blocked: bool=false) -> void:
	if jetpack_enabled and not enabled:reset_jetpack()
	jetpack_enabled=enabled;jetpack_blocked=blocked
func reset_jetpack() -> void:
	jetpack_state=Jetpack.fresh();jetpack_requested=false
func locomotion_state() -> Dictionary:
	var state:={"height":collision_height,"grounded":is_supported(),"assist":tracked_leg_animation}
	if jetpack_enabled:state.jetpack=jetpack_state.duplicate(true)
	return state
func receive_locomotion(state: Dictionary) -> void:
	update_height(float(state.get("height",xr_pose.get("height",1.65))),true)
	visual_grounded=state.get("grounded",absf(visual_velocity.y)<.5)==true
	tracked_leg_animation=state.get("assist",false)==true
func update_height(requested: float,force: bool=false) -> void:
	if not is_instance_valid(body_shape) or not is_finite(requested):return
	requested=clampf(requested,.65,1.65)
	# Derive posture from the actual collider, including blocked stand-up requests.
	stance="prone" if collision_height<.80 else "crouch" if collision_height<1.60 else "stand"
	if is_equal_approx(requested,collision_height):return
	if requested>collision_height and not force:
		var query:=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.30;capsule.height=requested-collision_height+.60
		# Test only the added upper volume; the existing feet may touch the floor.
		query.shape=capsule;query.transform=global_transform*Transform3D(Basis.IDENTITY,Vector3.UP*((collision_height+requested)*.5-.30+.005));query.collision_mask=3;query.exclude=[get_rid()];query.margin=.001
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return
	collision_height=requested;body_shape.shape.height=requested;body_shape.position.y=requested*.5+.005
	stance="prone" if collision_height<.80 else "crouch" if collision_height<1.60 else "stand"
func simulate(input: Vector2, yaw: float, slow: bool, delta: float, jump: bool = false, swim: Vector3=Vector3.ZERO) -> void:
	rotation.y = yaw
	water_boost=maxf(0,water_boost-delta)
	water_exit_grace=maxf(0,water_exit_grace-delta)
	if was_in_water and not in_water:water_exit_grace=.18
	was_in_water=in_water
	water_deep_time=water_deep_time+delta if underwater else 0.0
	if water_deep_time>.25 or is_supported() and not in_water:water_jump_used=false
	var direction := (basis * Vector3(input.x,0,input.y)).limit_length(1.0)
	var speed := (5.2 if slow else 9.4)*speed_multiplier*stance_speed()
	var stroke: Vector3=(basis*swim.limit_length(1.0)) if in_water and swim.is_finite() else Vector3.ZERO
	if in_water:
		speed*=.65
		direction=(direction+stroke).limit_length(1.0)
	var raw_jump:=jump
	if Jetpack.tick(self,direction,delta,raw_jump):
		jump_held=raw_jump
		var before:=position;var impact_speed:=velocity.y
		move_and_slide();Jetpack.moved(self,before)
		if is_on_floor() and impact_speed < -3.2:movement_sound.emit("land",global_position+Vector3.UP*.2)
		return
	if stance=="prone":jump=false;jump_queued=false
	if jump and not jump_held:jump_queued=true
	elif not jump:jump_queued=false
	var grounded:=is_supported() and velocity.y<=0
	var surface_jump:=stance!="prone" and quake_movement and not water_jump_used and (in_water and water_surface or water_exit_grace>0) and (jump or stroke.y>.15) and velocity.y>-.5
	var jumping:=quake_movement and jump_queued and grounded and not in_water or surface_jump
	if surface_jump:water_jump_used=true;water_exit_grace=0;water_boost=.25
	velocity.x-=blast_velocity.x;velocity.z-=blast_velocity.y
	blast_velocity=blast_velocity.move_toward(Vector2.ZERO,(24.0 if grounded else 2.0)*delta)
	if quake_movement and not in_water:
		var horizontal:=QuakeMovement.horizontal(Vector2(velocity.x,velocity.z),Vector2(direction.x,direction.z),speed,grounded,jumping,delta)
		velocity.x=horizontal.x;velocity.z=horizontal.y
		# Stance changes also brake carried ground momentum; blast impulses are
		# added separately below so rockets still push crouching/prone players.
		if grounded and stance!="stand":
			var capped:=Vector2(velocity.x,velocity.z).limit_length(speed)
			velocity.x=capped.x;velocity.z=capped.y
	else:
		var acceleration := 65.0 if input.length()>.01 else 45.0
		velocity.x = move_toward(velocity.x,direction.x*speed,acceleration*delta)
		velocity.z = move_toward(velocity.z,direction.z*speed,acceleration*delta)
	velocity.x+=blast_velocity.x;velocity.z+=blast_velocity.y
	velocity.y = -.2 if grounded else maxf(velocity.y-20.0*delta,-30.0)
	# Consume each press once; another takeoff requires release and a fresh press.
	# Surface takeoff begins with the waist still submerged. Cover that depth
	# plus raised pool lips; ordinary ground jumps keep their existing strength.
	if jumping:velocity.y=9.4 if surface_jump else 7.4;jump_queued=false
	elif quake_movement and jump and in_water:velocity.y=maxf(velocity.y,5.5)
	if in_water:
		# Level strokes must not hold the swimmer at zero vertical velocity.
		if absf(stroke.y)>.05 and not jump and water_boost<=0:velocity.y=move_toward(velocity.y,stroke.y*speed,24.0*delta)
		velocity.y=maxf(velocity.y,-speed if stroke.y<-.05 else -2.0);jump_queued=false
	jump_held = raw_jump
	floor_grace=.1 if is_supported() else maxf(0,floor_grace-delta)
	var was_grounded:=is_on_floor() or floor_grace>0
	var previous_y:=position.y
	var stepping:=was_grounded and velocity.y<=0 and not in_water
	var step := .20 if stance=="prone" else .55 if quake_movement else .43
	var travel := Vector3(velocity.x,0,velocity.z)*delta
	stepped_last_frame=stepping and step_up(travel,step)
	var impact_speed:=velocity.y
	# The successful sweep already consumed this frame's horizontal motion.
	if not stepped_last_frame:move_and_slide()
	if jumping and velocity.y>0:movement_sound.emit("jump",global_position+Vector3.UP*.65)
	elif not was_grounded and is_on_floor() and impact_speed < -3.2 and not in_water:movement_sound.emit("land",global_position+Vector3.UP*.2)
	if stepping and not is_supported() and velocity.y<=0:apply_floor_snap()
	if stepping and is_supported() and absf(position.y-previous_y)<=step+.05:
		view_offset=clampf(view_offset+previous_y-position.y,-.55,.55)

func simulate_frozen(delta: float) -> void:
	# Statues still obey gravity, but cannot retain a jump, swim or blast impulse.
	blast_velocity=Vector2.ZERO;jump_held=false;jump_queued=false
	stepped_last_frame=false;floor_grace=0
	velocity=Vector3(0,maxf(minf(velocity.y,0.0)-20.0*delta,-30.0),0)
	move_and_slide()

func apply_blast(impulse: Vector3) -> void:
	if not impulse.is_finite() or spectator:return
	var previous:=blast_velocity
	blast_velocity=(blast_velocity+Vector2(impulse.x,impulse.z)).limit_length(20.0)
	velocity.x+=blast_velocity.x-previous.x;velocity.z+=blast_velocity.y-previous.y
	velocity.y=clampf(velocity.y+impulse.y,-30.0,20.0)

func step_up(travel: Vector3,height: float) -> bool:
	if travel.length()<.001:return false
	# Match move_and_slide's recovery contacts. Without these, very small
	# inward motions look clear here but are stopped by its wall recovery.
	var obstacle:=KinematicCollision3D.new()
	if not test_move(global_transform,travel,obstacle,safe_margin,true,4):return false
	var blocked:=false
	for i in obstacle.get_collision_count():
		if obstacle.get_normal(i).dot(travel)<-.0000001:blocked=true;break
	if not blocked:return false
	var raised:=global_transform
	var ceiling:=KinematicCollision3D.new()
	# A low ceiling may still leave enough room for this particular riser.
	if test_move(raised,Vector3.UP*height,ceiling):height=maxf(0,ceiling.get_travel().y)
	if height<.001:return false
	raised.origin.y+=height
	if test_move(raised,travel):return false
	raised.origin+=travel
	var landing:=KinematicCollision3D.new()
	if not test_move(raised,Vector3.DOWN*(height+.05),landing):return false
	if landing.get_collider() is CharacterBody3D:return false
	var tread_height:=landing.get_position().y
	if landing.get_normal().dot(Vector3.UP)<cos(floor_max_angle):
		# Rounded capsule/riser contacts have a diagonal normal even on a flat
		# tread. Validate the real surface just inside the edge, not that normal.
		var into_step:=-landing.get_normal().slide(Vector3.UP).normalized()
		var edge:=landing.get_position()+into_step*.02
		var support:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(edge+Vector3.UP*.05,edge-Vector3.UP*.1,1))
		if support.is_empty() or support.normal.dot(Vector3.UP)<cos(floor_max_angle):return false
		tread_height=support.position.y
	# Capsule bottom is 0.005 m above the body origin. Check the actual tread
	# height too, so partial contact cannot ratchet up an over-height obstacle.
	if tread_height-global_position.y-.005>height+.001:return false
	var target_position:=raised.origin+landing.get_travel()
	var rise:=target_position.y-global_position.y
	if rise<=.00001 or rise>height+.001:return false
	global_position=target_position
	velocity.y=0
	return true

func reset_view() -> void:
	prediction.clear();prediction_view_offset=Vector3.ZERO
	water_jump_used=false;water_deep_time=0;water_exit_grace=0;water_boost=0;was_in_water=false
	view_offset=0;floor_grace=0;stepped_last_frame=false
	reset_physics_interpolation()
	visual_reset_until=Engine.get_physics_frames()+1

func render_position() -> Vector3:
	var rendered:=get_global_transform_interpolated().origin
	return global_position if Engine.get_physics_frames()<=visual_reset_until else rendered+prediction_view_offset

func correct_prediction(requested: Vector3) -> Vector3:
	if requested.is_zero_approx():return Vector3.ZERO
	var before:=position
	var view_before:=render_position()
	# A newer predicted position can already be against an obstacle. Sweep the
	# correction instead of embedding the capsule and recovering next frame.
	var remaining:=requested
	for attempt in 3:
		var hit:=move_and_collide(remaining)
		if not hit:break
		remaining=hit.get_remainder().slide(hit.get_normal())
		if remaining.length_squared()<.000001:break
	var applied:=position-before
	if not applied.is_zero_approx():
		# Network updates arrive between physics frames. The render transform
		# has not yet interpolated the correction, so preserve that exact view.
		reset_physics_interpolation()
		prediction_view_offset=view_before-global_position
	return applied

func show_alive(alive: bool, is_local: bool) -> void:
	alive=alive and not spectator
	if alive_state and not alive:reset_jetpack()
	alive_state = alive
	local_player = is_local
	collision_layer = 2 if alive else 0
	collision_mask=0 if spectator else 3
	if avatar:
		avatar.dead = not alive
		if not avatar_hash.is_empty():
			avatar.process_mode = Node.PROCESS_MODE_DISABLED if frozen or is_local and not local_body_visible else Node.PROCESS_MODE_INHERIT
			avatar.set_first_person(is_local and local_body_visible)
		avatar.visible = alive and (not is_local or local_body_visible)
	if label: label.visible = alive and not is_local

func set_avatar(model: Node3D, hash: String) -> void:
	_restore_frost()
	if is_instance_valid(avatar): avatar.free()
	avatar = model
	avatar_hash = hash
	add_child(avatar)
	if frozen:_apply_frost()
	show_alive(alive_state,local_player)

func animate_fire(offhand: bool=false) -> void:
	if avatar and not avatar_hash.is_empty(): avatar.fire(offhand)

func set_local_body(value: bool) -> void:
	value=value and local_player and alive_state and not gibbed and not avatar_hash.is_empty()
	if local_body_visible==value: return
	local_body_visible=value
	show_alive(alive_state,local_player)

func _process(_delta: float) -> void:
	prediction_view_offset*=exp(-12.0*_delta)
	view_offset*=exp(-18.0*_delta)
	_update_jetpack_visual()
	if not avatar:return
	var unarmed: bool=get_parent().lobby.active()
	if avatar:
		if avatar_hash.is_empty():
			for weapon in avatar.find_children("WeaponModel","Node3D",true,false):weapon.visible=not unarmed and alive_state
		else:
			avatar.unarmed=unarmed
			if unarmed:
				if is_instance_valid(avatar.gun):avatar.gun.hide()
				if is_instance_valid(avatar.offhand_gun):avatar.offhand_gun.hide()
	if frozen or not avatar: return
	avatar.visible = not spectator and not gibbed and (not local_player or local_body_visible and alive_state) and (alive_state or avatar.death_time<load("res://deathmatch/avatars/death_pose.gd").VISIBLE_TIME)
	var displayed_velocity: Vector3=velocity if local_player else visual_velocity
	if avatar_hash.is_empty():
		if alive_state:avatar.rotation.y=load("res://deathmatch/vr/body_basis.gd").head_yaw(xr_pose,avatar.rotation.y)
		avatar.animate(_delta,avatar.global_basis.inverse()*displayed_velocity,stance,collision_height,is_supported() if local_player or get_parent().multiplayer.is_server() else visual_grounded,xr_pose.get("body",{}),tracked_leg_animation)
		return
	avatar.target_xr_pose=xr_pose
	avatar.speed = Vector2(displayed_velocity.x,displayed_velocity.z).length()
	avatar.movement = basis.inverse()*displayed_velocity
	avatar.stance=stance
	avatar.collider_height=collision_height
	avatar.grounded=is_supported() if local_player or get_parent().multiplayer.is_server() else visual_grounded
	avatar.tracked_leg_animation=tracked_leg_animation
	avatar.aim_pitch = visual_pitch
	avatar.set_weapon(visual_weapon)

func _restore_frost() -> void:
	for entry in frost_originals:
		var mesh=entry.node.get_ref()
		if is_instance_valid(mesh):
			mesh.material_overlay=entry.overlay;mesh.material_override=entry.material
	frost_originals.clear()
func _apply_frost() -> void:
	if not is_instance_valid(avatar):return
	if not frost_material:
		frost_material=ShaderMaterial.new();frost_material.shader=load("res://deathmatch/effects/frozen.gdshader")
	var meshes: Array=avatar.find_children("*","MeshInstance3D",true,false)
	if avatar is MeshInstance3D:meshes.append(avatar)
	for mesh in meshes:
		frost_originals.append({"node":weakref(mesh),"material":mesh.material_override,"overlay":mesh.material_overlay})
		mesh.material_overlay=null;mesh.material_override=frost_material
func set_frozen(value: bool, progress: float=0.0) -> void:
	if frozen!=value:
		frozen=value
		if value:_apply_frost()
		else:_restore_frost()
		show_alive(alive_state,local_player)
	if DisplayServer.get_name()=="headless":return
	if value and not is_instance_valid(ice):
		ice=MeshInstance3D.new();var shape:=TorusMesh.new();shape.inner_radius=.38;shape.outer_radius=.43;ice.mesh=shape;ice.position.y=.04
		ice.material_override=Art.material(Color("83dbff"),.1,1)
		ice.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(ice)
		frozen_label=Label3D.new();frozen_label.position.y=2.3;frozen_label.font_size=36;frozen_label.pixel_size=.005
		frozen_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;frozen_label.modulate=Color("b9efff");frozen_label.no_depth_test=false;add_child(frozen_label)
	if is_instance_valid(ice):ice.visible=value and not local_player and not spectator
	if is_instance_valid(frozen_label):
		frozen_label.visible=value and not local_player and not spectator
		frozen_label.text="FROZEN" if progress<=0 else "THAWING %d%%"%int(clampf(progress/3.0,0,1)*100)

var class_badge: Label3D
func set_nametag(nickname: String,team: int,color: Color) -> void:
	if not label:return
	# Shape supplements colour without another floating panel or through-wall marker.
	label.text=("◆ " if team==0 else "● " if team==1 else "")+nickname
	label.modulate=color.lightened(.2 if team in [0,1] else .4)
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
		cloak_material=ShaderMaterial.new();cloak_material.shader=load("res://deathmatch/avatars/cloak.gdshader")
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

var fire_particles: CPUParticles3D
func set_burning_visual(active: bool) -> void:
	if not active:
		if is_instance_valid(fire_particles):fire_particles.queue_free();fire_particles=null
		return
	if not is_instance_valid(fire_particles):
		fire_particles=CPUParticles3D.new();fire_particles.name="BurningFlames"
		fire_particles.amount=20;fire_particles.lifetime=.55;fire_particles.preprocess=.2
		fire_particles.direction=Vector3.UP;fire_particles.spread=15
		fire_particles.initial_velocity_min=.5;fire_particles.initial_velocity_max=1.2
		fire_particles.gravity=Vector3(0,.5,0);fire_particles.scale_amount_min=.07;fire_particles.scale_amount_max=.16
		fire_particles.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX
		fire_particles.emission_box_extents=Vector3(.3,.25,.22)
		var ramp:=Gradient.new();ramp.colors=PackedColorArray([Color(1,.7,.12,.7),Color(1,.18,.02,.55),Color(.2,.03,.01,0)]);ramp.offsets=PackedFloat32Array([0,.45,1]);fire_particles.color_ramp=ramp
		var mesh:=QuadMesh.new();mesh.size=Vector2(.9,1.8);fire_particles.mesh=mesh
		var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		material.vertex_color_use_as_albedo=true;material.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES;material.cull_mode=BaseMaterial3D.CULL_DISABLED
		material.albedo_texture=load("res://deathmatch/effects/flame.svg")
		fire_particles.material_override=material;fire_particles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(fire_particles)
	fire_particles.position.y=minf(.6,collision_height*.35)

func _update_jetpack_visual() -> void:
	if DisplayServer.get_name()=="headless":return
	if not jetpack_enabled:
		if is_instance_valid(jetpack_model):jetpack_model.hide()
		return
	if not is_instance_valid(jetpack_model):
		jetpack_model=preload("res://deathmatch/conquest/jetpack_model.gd").new();add_child(jetpack_model)
	jetpack_model.visible=alive_state and not spectator and not gibbed and (not local_player or local_body_visible)
	if not jetpack_model.visible:return
	# Stable placeholder proportions; do not change the damage/collision body.
	var pose:=Transform3D(Basis(Vector3.RIGHT,-deg_to_rad(77) if stance=="prone" else 0.0),Vector3(0,maxf(.30,.78-(1.65-collision_height)),0))
	if avatar_hash.is_empty() and is_instance_valid(avatar):pose=avatar.transform*avatar.get_node("Upper").transform
	else:pose=Transform3D(Basis(Vector3.UP,preload("res://deathmatch/vr/body_basis.gd").head_yaw(xr_pose)),Vector3.ZERO)*pose
	jetpack_model.transform=pose*Transform3D(Basis.IDENTITY,Vector3(0,.24,.25))
	jetpack_model.set_exhaust(jetpack_state.mode!=0 and jetpack_state.age<(1.5 if jetpack_state.mode==2 else Jetpack.BURN_TIME))
