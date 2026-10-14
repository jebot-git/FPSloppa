extends Node3D
## Original UT99 vertex animation. Shared mesh/skin/frame texture; instance uniforms only.
const Art=preload("res://deathmatch/art.gd")
const LOD=preload("res://deathmatch/avatars/vertex_lod.gd")
const IK=preload("res://deathmatch/avatars/controller_arms.gd")
const IK_DISTANCE:=12.0
const IK_FADE_SECONDS:=.15
var distance_ik_enabled:=true
var mesh_lod_enabled:=true
var first_person:=false
var ik_near:=true
var ik_weight:=0.0
var mesh_tier:=0
var effective_distance:=0.0
var lod_meshes:Array=[]
var ik_uniforms_active:=false
var avatar_hash:=""
var unarmed:=false
var target_xr_pose:Dictionary={}
var left_handed:=false
var speed:=0.0
var movement:=Vector3.ZERO
var stance:="stand"
var collider_height:=1.65
var grounded:=true
var aim_pitch:=0.0
var body_height:=1.7
var dead:=false:
	set(value):
		if dead!=value:death_time=0.0
		dead=value
var death_time:=0.0
var preview_mode:=-1
var weapon_id:=-1
var gun:Node3D
var offhand_gun:Node3D
var visual:MeshInstance3D
var arm_profile:Dictionary={}
var tracked_arms_enabled:=true
var tracked_arms_active:=false
var arm_update_ms:=0.0
var clips:Array=[]
var clip_name:=""
var animation_frames:=Vector3.ZERO
var solved_arms:Dictionary={}
var backpack:Node3D
var carried_utility:Node3D
var carried_radio:Node3D
var utility_key:=""
var time:=0.0
var firing:=0.0
var selected_sequence:="" # Preview can select any original clip.
func configure(data:Dictionary) -> void:
	clips=data.clips;arm_profile=data.get("arm_profile",{})
	lod_meshes=data.get("lod_meshes",[data.mesh,data.mesh,data.mesh])
	visual=MeshInstance3D.new();visual.mesh=data.mesh;add_child(visual)
	visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func set_first_person(value:bool) -> void:
	first_person=value
	visible=not value # No head hiding, skeleton, body IK or expression channels.
var weapon_rules:="doom"
func set_weapon(id:int,rules_override:String="") -> void:
	var arena=get_parent().get_parent() if get_parent() else null
	var rules:String=rules_override if not rules_override.is_empty() else arena.match_mode.fortress.art_rules(get_parent().peer_id,id) if arena and "armory" in arena else "doom"
	if weapon_id==id and weapon_rules==rules:return
	weapon_id=id;weapon_rules=rules
	if is_instance_valid(gun):gun.free()
	if is_instance_valid(offhand_gun):offhand_gun.free()
	gun=Art.weapon(id,2,rules);add_child(gun)
	offhand_gun=Art.weapon(2) if id==2 and rules=="doom" else null
	if offhand_gun:add_child(offhand_gun)
func fire(_offhand:bool=false) -> void:firing=.3
func hurt(_direction:Vector3,_amount:float) -> void:pass
func choose_clip() -> Dictionary:
	var names:Array=[]
	if not selected_sequence.is_empty():names=[selected_sequence]
	elif dead:names=["Dead1","Death","Dead2"]
	elif preview_mode==3 or (preview_mode<0 and firing>0 and speed<=.1):names=["StillFrRp","Fire","StillFrSm","AimLg"]
	elif preview_mode<0 and not grounded:names=["JumpLg","JumpSm","Jump"]
	elif preview_mode<0 and stance in ["crouch","prone"]:names=["DuckWlkL","DuckWlkS","Crouch"]
	elif preview_mode==2 or speed>3:names=["RunLg","RunSm","Run"]
	elif preview_mode==1 or speed>.1:names=["WalkLg","WalkSm","Walk"]
	elif not grounded:names=["JumpLg","JumpSm","Jump"]
	elif stance in ["crouch","prone"]:names=["DuckWlkL","DuckWlkS","Crouch"]
	else:names=["Breath1","Breath2","Idle","StillLg","StillSm"]
	for name in names:
		for clip in clips:
			if str(clip.name).to_lower()==str(name).to_lower():return clip
	# Unknown clips fall back to a stable original frame rather than playing All.
	for clip in clips:
		if str(clip.name).to_lower()!="all":return clip
	return clips[0]
func _process(delta:float) -> void:
	if target_xr_pose.has("left_handed"):left_handed=target_xr_pose.left_handed
	firing=maxf(0,firing-delta)
	if dead:death_time+=delta
	if visual==null:return
	var clip:=choose_clip()
	if clip_name!=clip.name:clip_name=clip.name;time=0
	time+=delta
	var frame:=minf(time*float(clip.fps),float(clip.count)-1) if dead else fposmod(time*float(clip.fps),float(clip.count))
	var a:=floori(frame);var b:=mini(a+1,int(clip.count)-1) if dead else (a+1)%int(clip.count)
	var frames:=Vector3(int(clip.start)+a,int(clip.start)+b,frame-a)
	animation_frames=frames
	visual.set_instance_shader_parameter("animation_frames",frames)
	update_lod(delta)
	visual.scale=Vector3.ONE
	visual.rotation=Vector3.ZERO
	if stance=="prone" and not dead:
		visual.rotation.x=-PI/2;visual.position=Vector3(0,.3,.4)
	else:visual.position=Vector3.ZERO
	if not dead and stance=="crouch" and not (clip_name.to_lower().begins_with("duck") or clip_name.to_lower()=="crouch"):visual.scale.y=.65
	arm_update_ms=0.0
	tracked_arms_active=false
	solved_arms.clear()
	if ik_weight>0:
		var arm_start:=Time.get_ticks_usec()
		tracked_arms_active=IK.update(visual,arm_profile,target_xr_pose,frames,solved_arms,visual.transform)
		arm_update_ms=(Time.get_ticks_usec()-arm_start)/1000.0
		ik_uniforms_active=true
	elif ik_uniforms_active:
		visual.set_instance_shader_parameter("tracked_arms",false)
		visual.set_instance_shader_parameter("tracked_head",false)
		ik_uniforms_active=false
	if is_instance_valid(backpack):backpack.global_transform=global_transform*back_socket()
	update_equipment()
	for held in [gun,offhand_gun]:
		if not is_instance_valid(held):continue
		held.visible=not unarmed and not dead
		var offhand:bool=held==offhand_gun
		var id:int=2 if offhand else weapon_id
		var grip:=hand_pose(offhand)
		held.transform=Art.held_transform(grip,id,lerpf(.48,Art.VR_SCALE,ik_weight),weapon_rules)
func sample_attachment(key:String) -> Vector3:
	var data:Dictionary=arm_profile.get("attachments",{}).get(key,{})
	if data.is_empty():return Vector3.ZERO
	var samples:PackedVector3Array=data.samples
	return samples[clampi(int(animation_frames.x),0,samples.size()-1)].lerp(samples[clampi(int(animation_frames.y),0,samples.size()-1)],animation_frames.z)
func hand_pose(offhand:bool=false) -> Transform3D:
	var left:bool=left_handed!=offhand
	var side:="left" if left else "right"
	var key:="offhand_weapon" if offhand else "weapon"
	var native:=sample_attachment(side)
	var basis:=visual.basis.inverse()*Basis(Vector3.RIGHT,aim_pitch)
	if solved_arms.has(side):
		var anchor:Dictionary=arm_profile.get("attachments",{}).get(side,{})
		var solved:Vector3=solved_arms[side].fore*anchor.reference if not anchor.is_empty() else solved_arms[side].hand
		native=native.lerp(solved,ik_weight)
		if target_xr_pose.has(key):basis=visual.basis.inverse()*target_xr_pose[key].basis
	return visual.transform*Transform3D(basis,native)
func equipment_socket(mainhand:bool=false) -> Transform3D:
	var left:bool=left_handed==mainhand
	if not arm_profile.has("sockets"):return Transform3D(Basis.IDENTITY,Vector3(-.23 if left else .23,1.4,0))
	var shoulder:=IK.socket(arm_profile,animation_frames,0 if left else 3)
	return visual.transform*Transform3D(torso_basis(),shoulder+torso_basis()*Vector3(0,.035,0))
func torso_basis() -> Basis:
	if not arm_profile.has("sockets"):return Basis.IDENTITY
	var left:=IK.socket(arm_profile,animation_frames,0);var right:=IK.socket(arm_profile,animation_frames,3)
	var x:Vector3=(right-left).normalized()
	var up:Vector3=IK.socket(arm_profile,animation_frames,6)-(left+right)*.5
	var y:Vector3=(up-x*up.dot(x)).normalized()
	if x.length_squared()<.5 or y.length_squared()<.5:return Basis.IDENTITY
	return Basis(x,y,x.cross(y)).orthonormalized()
func back_socket() -> Transform3D:
	return visual.transform*Transform3D(torso_basis(),sample_attachment("back")+torso_basis()*Vector3(0,0,.10))
func update_lod(delta:float) -> void:
	var camera:=get_viewport().get_camera_3d()
	effective_distance=LOD.effective_distance(global_position,camera)
	var detailed:=first_person or preview_mode>=0 or camera==null
	if detailed or not distance_ik_enabled:ik_near=true
	elif ik_near and effective_distance>IK_DISTANCE*1.15:ik_near=false
	elif not ik_near and effective_distance<IK_DISTANCE*.85:ik_near=true
	var eligible:=tracked_arms_enabled and not dead and arm_profile.has("sockets") and target_xr_pose.has("head")
	var desired:=1.0 if ik_near and eligible else 0.0
	# Only distance transitions fade. Death/lost tracking retires stale IK at once.
	var weight:=move_toward(ik_weight,desired,maxf(0,delta)/IK_FADE_SECONDS) if eligible else 0.0
	if weight!=ik_weight:
		ik_weight=weight;visual.set_instance_shader_parameter("ik_weight",ik_weight)
	var tier:=0 if detailed or not mesh_lod_enabled else LOD.choose_tier(mesh_tier,effective_distance)
	if tier!=mesh_tier:
		mesh_tier=tier;visual.mesh=lod_meshes[tier]

func set_equipment(key:String) -> void:
	if utility_key==key:return
	utility_key=key
	if is_instance_valid(carried_utility):carried_utility.free()
	carried_utility=preload("res://deathmatch/avatars/equipment.gd").utility(key) if not key.is_empty() else null
	if carried_utility:add_child(carried_utility)
	if not is_instance_valid(carried_radio):
		carried_radio=preload("res://deathmatch/avatars/equipment.gd").radio();add_child(carried_radio)
func update_equipment() -> void:
	if is_instance_valid(carried_radio):
		carried_radio.visible=not dead and not unarmed
		carried_radio.transform=equipment_socket(true)
	if is_instance_valid(carried_utility):
		carried_utility.visible=not dead and not unarmed
		var size:Vector3=carried_utility.scale
		carried_utility.transform=equipment_socket(false)
		carried_utility.scale=size
