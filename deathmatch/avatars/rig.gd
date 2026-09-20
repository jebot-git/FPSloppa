extends Node3D
var unarmed:=false
## Shared humanoid locomotion and aiming, retargeted by the VRM plugin.
const Pose = preload("res://deathmatch/avatars/pose.gd")
const Art = preload("res://deathmatch/art.gd")
const RestBounds = preload("res://deathmatch/avatars/rest_bounds.gd")
var target_xr_pose: Dictionary={}
var xr_pose: Dictionary={}
var pain:=0.0
var pain_direction:=Vector3.ZERO
var skeleton: Skeleton3D
var model: Node3D
var motion: AnimationPlayer
var solver
var mouth
var eyes
var speed := 0.0
var movement := Vector3.ZERO
var stance:="stand"
var collider_height:=1.65
var grounded:=true
var tracked_leg_animation:=false
var gait=preload("res://deathmatch/avatars/locomotion.gd").new()
var aim_pitch := 0.0
var phase := 0.0
var recoil := 0.0
var offhand_recoil := 0.0
var dead := false:
	set(value):
		if dead==value:return
		dead=value
		death_time=0.0
		if dead and is_inside_tree():death_basis=get_parent().global_basis.orthonormalized()
		if solver:solver.reset_death()
		if not dead:
			gait=preload("res://deathmatch/avatars/locomotion.gd").new()
			pain=0.0;recoil=0.0;offhand_recoil=0.0
var death_time := 0.0
var death_basis:=Basis.IDENTITY
var preview_mode := -1
var weapon_id := -1
var gun: Node3D
var offhand_gun: Node3D
var body_height := 1.70
var body_heading:=0.0
var scale_factor := 1.0
var neutral_hip_height:=.92
var neutral_foot_heights:Dictionary={"left":.08,"right":.08}
var first_person := false
var secondary_nodes: Array[Node]=[]
var visual_meshes: Array[MeshInstance3D]=[]

func configure(root: Node3D) -> bool:
	process_priority=-10
	model = root
	model.rotation.y += PI
	skeleton = find_skeleton(root)
	if not skeleton: return false
	for bone in ["Hips","Head","LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm","RightLowerArm","RightHand","LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot"]:
		if skeleton.find_bone(bone)<0: return false
	var local_bounds:AABB=root.get_meta(RestBounds.CACHE_KEY) if root.has_meta(RestBounds.CACHE_KEY) else RestBounds.measure(root)
	var bounds:AABB=root.transform*local_bounds
	if bounds.size.y<.05 or bounds.size.y>1000 or not bounds.size.is_finite(): return false
	scale_factor = body_height/bounds.size.y
	model.scale *= scale_factor
	model.position *= scale_factor
	model.position.y -= bounds.position.y*scale_factor
	var transforms:Dictionary={}
	RestBounds.collect(model,model.transform,transforms)
	var skeleton_transform:Transform3D=transforms[skeleton]
	neutral_hip_height=(skeleton_transform*skeleton.get_bone_global_rest(skeleton.find_bone("Hips")).origin).y
	for side in ["Left","Right"]:
		neutral_foot_heights[side.to_lower()]=(skeleton_transform*skeleton.get_bone_global_rest(skeleton.find_bone(side+"Foot")).origin).y
	# All meshes are cosmetic: no imported physics, lights, cameras or audio.
	strip_nonvisual(root)
	solver = Pose.new()
	solver.rig = self
	skeleton.add_child(solver)
	mouth=preload("res://deathmatch/avatars/mouth.gd").new()
	add_child(mouth)
	mouth.setup(model)
	eyes=preload("res://deathmatch/avatars/eyes.gd").new()
	eyes.rig=self
	skeleton.add_child(eyes)
	eyes.setup(model)
	mouth.external_mixer=true;mouth.mixer=eyes.apply_morphs
	build_animations()
	set_weapon(2)
	return true

func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D and node.find_bone("Hips")>=0: return node
	for child in node.get_children():
		var found := find_skeleton(child)
		if found: return found
	return null

func mesh_bounds(node: Node3D, parent_transform: Transform3D) -> AABB:
	return parent_transform*node.transform*RestBounds.measure(node)

func fit_tracked_hips(pose: Transform3D) -> Transform3D:
	# Tracking calibration uses a .92 m pelvis and .08 m ankle reference.
	# Retarget the neutral stance to this uniformly scaled model's proportions;
	# preserve the tracked displacement, including crouches and lifted feet.
	pose.origin.y+=neutral_hip_height-.92
	return pose

func fit_tracked_foot(side: String,pose: Transform3D) -> Transform3D:
	pose.origin.y+=float(neutral_foot_heights.get(side,.08))-.08
	return pose

func strip_nonvisual(node: Node) -> void:
	if node is VRMSecondary:secondary_nodes.append(node)
	for child in node.get_children():
		if child is CollisionObject3D or child is Camera3D or child is Light3D or child is AudioStreamPlayer3D:
			child.free()
		else: strip_nonvisual(child)
	if node is MeshInstance3D:
		visual_meshes.append(node)
		node.set_meta("arena_first_person",(node.layers&(1<<19))!=0)
		node.set_meta("arena_third_person",(node.layers&1)!=0)
		node.visible=bool(node.get_meta("arena_third_person"))
		node.layers = 1
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# MToon outlines add a second draw for every material surface.
		for surface in range(node.mesh.get_surface_count()):
			var material: Material=node.get_active_material(surface)
			if material:
				preload("res://deathmatch/avatars/lighting.gd").prepare(material)
				if not material.has_meta("arena_outline"): material.set_meta("arena_outline",material.next_pass)
				material.next_pass=null
		node.visibility_range_end = 65

func set_first_person(value: bool) -> void:
	if first_person==value: return
	first_person=value
	# The capsule moves on physics ticks; tracked rendering owns this transform.
	# Keep that parent motion from shifting the mesh between VR/IK updates.
	top_level=value
	transform=tracking_transform() if value else Transform3D.IDENTITY
	physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF if value else Node.PHYSICS_INTERPOLATION_MODE_INHERIT
	for secondary in secondary_nodes:secondary.set_local_body(value)
	for mesh in visual_meshes:
		mesh.visible=bool(mesh.get_meta("arena_first_person" if value else "arena_third_person"))
	if gun: gun.visible=not value and not dead
	if offhand_gun: offhand_gun.visible=not value and not dead

func build_animations() -> void:
	motion = AnimationPlayer.new()
	motion.name = "ArenaAnimations"
	add_child(motion)
	var library := AnimationLibrary.new()
	var hips := skeleton.find_bone("Hips")
	var rest := skeleton.get_bone_rest(hips).origin
	for clip in ["idle","walk","run"]:
		var anim := Animation.new()
		anim.length = 2.4 if clip=="idle" else .8 if clip=="walk" else .52
		anim.loop_mode = Animation.LOOP_LINEAR
		var track := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(track,NodePath(str(get_path_to(skeleton))+":Hips"))
		for i in range(17):
			var t := float(i)/16
			var bob := sin(t*TAU)*.006 if clip=="idle" else absf(sin(t*TAU))*(.018 if clip=="walk" else .032)
			anim.position_track_insert_key(track,t*anim.length,rest+Vector3.UP*bob/scale_factor)
		library.add_animation(clip,anim)
	motion.add_animation_library("",library)
	motion.play("idle")

var weapon_rules:="doom"
func set_weapon(value: int, rules_override: String="") -> void:
	var arena=get_parent().get_parent() if get_parent() else null
	var rules: String=rules_override if not rules_override.is_empty() else arena.match_mode.fortress.art_rules(get_parent().peer_id,value) if arena and "armory" in arena else "doom"
	if value==weapon_id and rules==weapon_rules:return
	weapon_rules=rules
	weapon_id = value
	if is_instance_valid(gun): gun.free()
	if is_instance_valid(offhand_gun): offhand_gun.free()
	offhand_gun=null
	if value==2 and weapon_rules=="doom":
		offhand_gun=Art.weapon(2);add_child(offhand_gun)
	gun = Art.weapon(value,2,weapon_rules)
	gun.scale = Vector3.ONE*.48
	add_child(gun)

func hurt(direction: Vector3, strength: float) -> void:
	pain=minf(1.0,strength/40.0)
	pain_direction=global_basis.inverse()*direction

func fire(offhand: bool=false) -> void:
	if offhand: offhand_recoil=1.0
	else: recoil = 1.0

func tracking_transform() -> Transform3D:
	var actor=get_parent()
	if first_person and actor.has_method("render_position"):
		var game=actor.get_parent()
		if game.is_vr():return game.xr_rig.global_transform
		return Transform3D(Basis(Vector3.UP,game.local_yaw),actor.render_position())
	return actor.global_transform

func _process(delta: float) -> void:
	if not is_instance_valid(skeleton): return
	if dead:
		death_time=minf(death_time+delta,preload("res://deathmatch/avatars/death_pose.gd").VISIBLE_TIME)
		# Death owns the skeleton: live trackers, breathing and weapon IK stop here.
		motion.pause()
		xr_pose.clear()
		if not first_person:transform=Transform3D(get_parent().global_basis.inverse()*death_basis,Vector3.ZERO)
		if gun:gun.hide()
		if offhand_gun:offhand_gun.hide()
		return
	if first_person:
		global_transform=tracking_transform()
	else:
		position.x=0;position.z=0;rotation.y=0
	if target_xr_pose.is_empty(): xr_pose.clear()
	elif xr_pose.is_empty() or first_person: xr_pose=target_xr_pose.duplicate()
	else:
		for key in ["head","left","right","weapon"]: xr_pose[key]=xr_pose[key].interpolate_with(target_xr_pose[key],minf(1.0,delta*22))
		if target_xr_pose.has("offhand_weapon"):
			xr_pose.offhand_weapon=xr_pose.get("offhand_weapon",target_xr_pose.offhand_weapon).interpolate_with(target_xr_pose.offhand_weapon,minf(1.0,delta*22))
		else: xr_pose.erase("offhand_weapon")
		xr_pose.left_handed=target_xr_pose.left_handed
		xr_pose.face=target_xr_pose.get("face",{})
		var next_body: Dictionary=target_xr_pose.get("body",{})
		var previous: Dictionary=xr_pose.get("body",{})
		var body: Dictionary={}
		for key in next_body:
			body[key]=previous[key].interpolate_with(next_body[key],minf(1,delta*18)) if previous.has(key) and next_body[key] is Transform3D else next_body[key]
		xr_pose.body=body
	# Rotate only the rendered body; controller/head poses retain their tracking frame.
	body_heading=preload("res://deathmatch/vr/body_basis.gd").head_yaw(xr_pose,body_heading)
	var physical_yaw:=body_heading
	global_basis=tracking_transform().basis*Basis(Vector3.UP,physical_yaw)
	if preview_mode>=0:
		speed = [0.0,4.0,9.4,0.0][preview_mode]
		movement = Vector3.FORWARD*speed
		if preview_mode==3 and fmod(phase,1.0)<delta: fire()
	var clip := "idle" if speed<.2 else "walk" if speed<6.0 else "run"
	if motion.current_animation!=clip or not motion.is_playing(): motion.play(clip,.18)
	gait.update(delta,Basis(Vector3.UP,-physical_yaw)*movement,stance,grounded,target_xr_pose.get("body",{}),tracked_leg_animation)
	# Preview firing has its own clock, including when standing still.
	phase+=delta
	recoil = move_toward(recoil,0.0,delta*7)
	offhand_recoil=move_toward(offhand_recoil,0.0,delta*7)
	pain=move_toward(pain,0.0,delta*3.5)
	death_time = 0
	rotation.x = 0.0 if first_person else pain*pain_direction.z*.12
	rotation.z = 0.0 if first_person else -pain*pain_direction.x*.12
	if not first_person:position.y = 0
	if gun and not xr_pose.is_empty() and not dead:
		gun.global_transform=Art.held_transform(get_parent().global_transform*xr_pose.weapon,weapon_id,Art.VR_SCALE,weapon_rules)
		gun.visible=not unarmed and not first_person
		if offhand_gun:
			offhand_gun.visible=not unarmed and not first_person and xr_pose.has("offhand_weapon")
			if xr_pose.has("offhand_weapon"): offhand_gun.global_transform=Art.held_transform(get_parent().global_transform*xr_pose.offhand_weapon,2)
		return
	if gun:
		var grip:=Transform3D(Basis(Vector3.RIGHT,aim_pitch+recoil*.12),Art.desktop_hand(false,aim_pitch,recoil))
		grip.origin.y-=1.65-collider_height
		gun.transform=Art.held_transform(grip,weapon_id,.48,weapon_rules)
		gun.visible = not unarmed and not dead and not first_person

	if offhand_gun:
		var grip:=Transform3D(Basis(Vector3.RIGHT,aim_pitch+offhand_recoil*.12),Art.desktop_hand(true,aim_pitch,offhand_recoil,true))
		grip.origin.y-=1.65-collider_height
		offhand_gun.transform=Art.held_transform(grip,2,.48)
		offhand_gun.visible=not unarmed and not dead and not first_person
