extends Node3D
## Shared humanoid locomotion and aiming, retargeted by the VRM plugin.
const Pose = preload("res://deathmatch/avatars/pose.gd")
const Art = preload("res://deathmatch/art.gd")
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
var aim_pitch := 0.0
var phase := 0.0
var recoil := 0.0
var dead := false
var death_time := 0.0
var preview_mode := -1
var weapon_id := -1
var gun: Node3D
var body_height := 1.70
var scale_factor := 1.0
var first_person := false
var visual_meshes: Array[MeshInstance3D]=[]

func configure(root: Node3D) -> bool:
	model = root
	model.rotation.y += PI
	skeleton = find_skeleton(root)
	if not skeleton: return false
	for bone in ["Hips","Head","LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm","RightLowerArm","RightHand","LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot"]:
		if skeleton.find_bone(bone)<0: return false
	var bounds := mesh_bounds(root,Transform3D.IDENTITY)
	if bounds.size.y<.05 or bounds.size.y>1000 or not bounds.size.is_finite(): return false
	scale_factor = body_height/bounds.size.y
	model.scale *= scale_factor
	model.position.y -= bounds.position.y*scale_factor
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
	var transform_here := parent_transform*node.transform
	var result := AABB()
	if node is MeshInstance3D and node.mesh: result = transform_here*node.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var b := mesh_bounds(child,transform_here)
			if b.size.length()>0: result = b if result.size.length()==0 else result.merge(b)
	return result

func strip_nonvisual(node: Node) -> void:
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
				if not material.has_meta("arena_outline"): material.set_meta("arena_outline",material.next_pass)
				material.next_pass=null
		node.visibility_range_end = 65

func set_first_person(value: bool) -> void:
	if first_person==value: return
	first_person=value
	for mesh in visual_meshes:
		mesh.visible=bool(mesh.get_meta("arena_first_person" if value else "arena_third_person"))
	if gun: gun.visible=not value and not dead

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

func set_weapon(value: int) -> void:
	if value==weapon_id: return
	weapon_id = value
	if is_instance_valid(gun): gun.free()
	gun = Art.weapon(value)
	gun.scale = Vector3.ONE*.48
	add_child(gun)

func hurt(direction: Vector3, strength: float) -> void:
	pain=minf(1.0,strength/40.0)
	pain_direction=global_basis.inverse()*direction

func fire() -> void:
	recoil = 1.0

func _process(delta: float) -> void:
	if not is_instance_valid(skeleton): return
	if target_xr_pose.is_empty(): xr_pose.clear()
	elif xr_pose.is_empty() or first_person: xr_pose=target_xr_pose.duplicate()
	else:
		for key in ["head","left","right","weapon"]: xr_pose[key]=xr_pose[key].interpolate_with(target_xr_pose[key],minf(1.0,delta*22))
		xr_pose.left_handed=target_xr_pose.left_handed
		xr_pose.face=target_xr_pose.get("face",{})
		var next_body: Dictionary=target_xr_pose.get("body",{})
		var previous: Dictionary=xr_pose.get("body",{})
		var body: Dictionary={}
		for key in next_body:
			body[key]=previous[key].interpolate_with(next_body[key],minf(1,delta*18)) if previous.has(key) and next_body[key] is Transform3D else next_body[key]
		xr_pose.body=body
	if preview_mode>=0:
		speed = [0.0,4.0,9.4,0.0][preview_mode]
		movement = Vector3.FORWARD*speed
		if preview_mode==3 and fmod(phase,1.0)<delta: fire()
	var clip := "idle" if speed<.2 else "walk" if speed<6.0 else "run"
	if motion.current_animation!=clip: motion.play(clip,.18)
	phase += delta*(1.0 if speed<.2 else 1.25 if speed<6.0 else 1.92)
	recoil = move_toward(recoil,0.0,delta*7)
	pain=move_toward(pain,0.0,delta*3.5)
	if dead:
		death_time += delta
		rotation.x = lerpf(rotation.x,-PI*.47,delta*8)
		position.y = lerpf(position.y,.22,delta*8)
	else:
		death_time = 0
		rotation.x = pain*pain_direction.z*.12
		rotation.z = -pain*pain_direction.x*.12
		position.y = 0
	if gun and not xr_pose.is_empty() and not dead:
		gun.global_transform=Art.held_transform(get_parent().global_transform*xr_pose.weapon,weapon_id)
		gun.visible=not first_person
		return
	if gun:
		var grip:=Transform3D(Basis(Vector3.RIGHT,aim_pitch+recoil*.12),Art.desktop_hand(false,aim_pitch,recoil))
		gun.transform=Art.held_transform(grip,weapon_id,.48)
		gun.visible = not dead and not first_person
