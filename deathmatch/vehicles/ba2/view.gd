extends Node3D
## Baked 18-bone walk, X-only cannon elevation, ladder and cockpit presentation.
const Tuning=preload("res://deathmatch/vehicles/ba2/tuning.gd")
const MODEL="res://deathmatch/vehicles/ba2/model.scn"
var model: Node3D
var player: AnimationPlayer
var skeleton: Skeleton3D
var ladder: Node3D
var prompt: Label3D
var idle: Array=[]
var leg_roots: Array[int]=[]
var pilot_shell: MeshInstance3D
var footsteps=preload("res://deathmatch/vehicles/ba2/footsteps.gd").new()
func setup() -> void:
	if ResourceLoader.exists(MODEL):
		model=load(MODEL).instantiate();add_child(model)
		player=model.find_child("AnimationPlayer",true,false)
		for n in model.find_children("*","Skeleton3D",true,false):skeleton=n;break
		if player and skeleton:
			player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			player.play("WalkLoop");player.seek(0,true);player.advance(0)
			for i in skeleton.get_bone_count():
				idle.append(skeleton.get_bone_pose(i))
				if skeleton.get_bone_name(i).begins_with("Leg.1."):leg_roots.append(i)
		pilot_shell=model.find_child("PilotShell",true,false)
	var metal:=_material(Color("647575"));var yellow:=_material(Color("d7a847"))
	ladder=Node3D.new();ladder.name="BoardingLadder";add_child(ladder)
	# Suspended from the original belly: no added deck, platform or cabin.
	for x in [-.42,.42]:_box(ladder,Vector3(x,2.44,0),Vector3(.075,4.72,.075),metal)
	for i in 16:_box(ladder,Vector3(0,.11+i*.31,0),Vector3(.9,.055,.09),yellow if i%3==0 else metal)
	prompt=Label3D.new();prompt.name="BoardingPrompt";prompt.position=Vector3(0,1.9,.15);prompt.font_size=32;prompt.pixel_size=.009;prompt.billboard=BaseMaterial3D.BILLBOARD_ENABLED;prompt.text="JUMP TO BOARD";add_child(prompt)

func _material(color: Color) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.albedo_color=color;m.roughness=.65;return m
func _box(parent: Node,at: Vector3,size: Vector3,material: Material) -> void:
	var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=size;mesh.mesh=box;mesh.position=at;mesh.material_override=material;parent.add_child(mesh)
func update_robot(row: Dictionary,deployed: bool,local_pilot: bool) -> void:
	ladder.visible=deployed;prompt.visible=deployed
	# The exterior shell remains intact for every observer.
	if pilot_shell:pilot_shell.visible=true
	if not player or not skeleton:return
	# Optimized clips omit constant hip-position tracks. Restore those local
	# poses before sampling so steering compensation cannot accumulate each frame.
	for i in leg_roots:skeleton.set_bone_pose(i,idle[i])
	player.play("WalkLoop");player.seek(fposmod(float(row.distance),Tuning.STRIDE)/Tuning.AUTHORED_SPEED,true);player.advance(0)
	var weight:=clampf(float(row.speed)/Tuning.SPEED,0,1)
	# Blend into the planted idle pose as the robot brakes; never freeze a foot
	# in the raised part of the walk when the cockpit becomes empty.
	for i in skeleton.get_bone_count():
		var pose: Transform3D=idle[i].interpolate_with(skeleton.get_bone_pose(i),weight)
		skeleton.set_bone_pose(i,pose)
	# Turn the torso while retaining the baked leg poses and planted feet.
	var added_yaw: float=Tuning.body_yaw(row)-Tuning.body_sway(row)
	if absf(added_yaw)>.000001:
		var legs: Dictionary={}
		for i in leg_roots:legs[i]=skeleton.get_bone_global_pose(i)
		var body:=skeleton.find_bone("Body");var parent:=skeleton.get_bone_parent(body)
		var frame: Basis=skeleton.global_basis*(skeleton.get_bone_global_pose(parent).basis if parent>=0 else Basis.IDENTITY)
		var axis: Vector3=(frame.inverse()*global_basis.y).normalized()
		skeleton.set_bone_pose_rotation(body,Quaternion(axis,added_yaw)*skeleton.get_bone_pose_rotation(body))
		for i in legs:
			var p:=skeleton.get_bone_parent(i)
			skeleton.set_bone_pose(i,skeleton.get_bone_global_pose(p).affine_inverse()*legs[i] if p>=0 else legs[i])
	for pair in 2:
		var bone:=skeleton.find_bone("Cannon.L" if pair==0 else "Cannon.R")
		# The authored cannon's local X points opposite the chassis X axis.
		# Convert the controller's down-positive elevation into that hinge frame.
		var rotation: Quaternion=skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()*Quaternion(Vector3.RIGHT,-float(row.pitches[pair]))
		skeleton.set_bone_pose_rotation(bone,rotation)
